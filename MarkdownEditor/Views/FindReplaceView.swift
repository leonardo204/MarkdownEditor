import SwiftUI
import AppKit
import WebKit

// MARK: - 찾기/바꾸기 매니저

class FindReplaceManager: ObservableObject {
    // 검색 대상: 에디터 소스 텍스트 / 프리뷰 렌더 결과
    enum SearchTarget {
        case editor
        case preview
    }

    @Published var isVisible = false
    @Published var showReplace = false
    @Published var searchText = "" {
        didSet { findAll() }
    }
    @Published var replaceText = ""
    @Published var currentMatchIndex = 0
    @Published var totalMatches = 0
    @Published var caseSensitive = false {
        didSet { findAll() }
    }
    // 검색 대상 (에디터 / 프리뷰). 변경 시 이전 대상 하이라이트 제거 후 재검색
    @Published var searchTarget: SearchTarget = .editor {
        didSet {
            guard oldValue != searchTarget else { return }
            if searchTarget == .preview { showReplace = false }
            clearAllHighlights()
            findAll()
            // 바꾸기 행 표시 여부가 바뀌므로 패널 크기 재조정
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.updatePanelSize()
            }
        }
    }

    weak var textView: NSTextView?
    weak var previewWebView: WKWebView?
    weak var searchField: NSSearchField?
    private var matchRanges: [NSRange] = []
    private var panel: FindReplacePanel?

    // 최근 검색 최대 개수
    private let maxRecents = 10

    // 사용자가 마지막으로 상호작용한 패널 (검색 대상 자동 선택용)
    private var lastActivePane: SearchTarget = .editor

    // 프리뷰가 현재 화면에 표시 중인지 (weak 참조가 살아있으면 표시 중)
    var isPreviewAvailable: Bool { previewWebView != nil }

    private let highlightColor = NSColor.systemYellow.withAlphaComponent(0.4)
    private let currentHighlightColor = NSColor.systemOrange.withAlphaComponent(0.6)

    // MARK: - 활성 패널 추적 (검색 대상 자동 선택)

    func markEditorActive() { lastActivePane = .editor }
    func markPreviewActive() { lastActivePane = .preview }

    // MARK: - 패널 표시/닫기

    func show(withReplace: Bool = false) {
        // 검색 대상 자동 선택: 프리뷰가 표시 중이고 마지막 상호작용이 프리뷰였다면 프리뷰
        searchTarget = (isPreviewAvailable && lastActivePane == .preview) ? .preview : .editor

        // 프리뷰 검색 시 바꾸기는 지원하지 않음
        showReplace = withReplace && searchTarget == .editor
        isVisible = true

        // 에디터 검색 시 선택된 텍스트가 있으면 검색어로 설정
        if searchTarget == .editor, let textView = textView {
            let selectedRange = textView.selectedRange()
            if selectedRange.length > 0 {
                searchText = (textView.string as NSString).substring(with: selectedRange)
            }
        }

        findAll()
        showPanel()
    }

    func close() {
        // 닫기 전, 검색어를 최근 검색에 기록
        recordRecentSearch()

        // 닫기 시 현재 매치 위치로 에디터 커서 이동 (에디터 검색인 경우)
        if searchTarget == .editor, !matchRanges.isEmpty, currentMatchIndex < matchRanges.count {
            textView?.setSelectedRange(matchRanges[currentMatchIndex])
            textView?.window?.makeKeyAndOrderFront(nil)
        }

        isVisible = false
        clearAllHighlights()
        matchRanges = []
        totalMatches = 0
        currentMatchIndex = 0
        panel?.orderOut(nil)
    }

    // MARK: - 검색 필드 포커스 / 최근 검색

    /// 검색 필드에 포커스를 주고 기존 값을 전체 선택 (재오픈 시 바로 대체 입력 가능)
    func focusSearchField() {
        guard let field = searchField else { return }
        field.window?.makeFirstResponder(field)
        field.selectText(nil)
    }

    /// 현재 검색어를 최근 검색 목록에 기록 (중복 제거 + 최신순 + 개수 제한)
    func recordRecentSearch() {
        guard let field = searchField else { return }
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        var recents = field.recentSearches
        recents.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        recents.insert(term, at: 0)
        if recents.count > maxRecents { recents = Array(recents.prefix(maxRecents)) }
        field.recentSearches = recents
    }

    // MARK: - 검색 (대상별 분기)

    func findAll() {
        switch searchTarget {
        case .editor: findAllInEditor()
        case .preview: findAllInPreview()
        }
    }

    private func findAllInEditor() {
        guard let textView = textView, !searchText.isEmpty else {
            clearEditorHighlights()
            matchRanges = []
            totalMatches = 0
            currentMatchIndex = 0
            return
        }

        clearEditorHighlights()

        let text = textView.string as NSString
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: text.length)
        let options: NSString.CompareOptions = caseSensitive ? [] : [.caseInsensitive]

        while searchRange.location < text.length {
            let foundRange = text.range(of: searchText, options: options, range: searchRange)
            if foundRange.location == NSNotFound { break }
            ranges.append(foundRange)
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = text.length - searchRange.location
        }

        matchRanges = ranges
        totalMatches = ranges.count

        if !ranges.isEmpty {
            // 커서 위치에서 가장 가까운 매치 찾기
            let cursorLocation = textView.selectedRange().location
            currentMatchIndex = 0
            for (i, range) in ranges.enumerated() {
                if range.location >= cursorLocation {
                    currentMatchIndex = i
                    break
                }
            }
            highlightMatches()
            scrollToCurrentMatch()
        } else {
            currentMatchIndex = 0
        }
    }

    // MARK: - 다음/이전 (순환)

    func findNext() {
        switch searchTarget {
        case .editor:
            guard !matchRanges.isEmpty else { return }
            currentMatchIndex = (currentMatchIndex + 1) % matchRanges.count
            highlightMatches()
            scrollToCurrentMatch()
        case .preview:
            previewNavigate(next: true)
        }
    }

    func findPrevious() {
        switch searchTarget {
        case .editor:
            guard !matchRanges.isEmpty else { return }
            currentMatchIndex = (currentMatchIndex - 1 + matchRanges.count) % matchRanges.count
            highlightMatches()
            scrollToCurrentMatch()
        case .preview:
            previewNavigate(next: false)
        }
    }

    // MARK: - 프리뷰 검색 (JavaScript 기반)

    private func findAllInPreview() {
        guard let webView = previewWebView, !searchText.isEmpty else {
            clearPreviewHighlights()
            totalMatches = 0
            currentMatchIndex = 0
            return
        }
        let escaped = Self.jsEscape(searchText)
        let js = "JSON.stringify(window.meFind ? window.meFind.find('\(escaped)', \(caseSensitive)) : {count:0,current:0})"
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            self?.applyPreviewResult(result)
        }
    }

    private func previewNavigate(next: Bool) {
        guard let webView = previewWebView else { return }
        let fn = next ? "next" : "prev"
        let js = "JSON.stringify(window.meFind ? window.meFind.\(fn)() : {count:0,current:0})"
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            self?.applyPreviewResult(result)
        }
    }

    /// 프리뷰가 재로드된 후(편집·테마 변경 등) 검색을 다시 적용
    func reapplyPreviewSearchIfNeeded() {
        guard isVisible, searchTarget == .preview, !searchText.isEmpty else { return }
        findAllInPreview()
    }

    private func applyPreviewResult(_ result: Any?) {
        guard let json = result as? String,
              let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            totalMatches = 0
            currentMatchIndex = 0
            return
        }
        let count = (obj["count"] as? Int) ?? 0
        let current = (obj["current"] as? Int) ?? 0
        totalMatches = count
        currentMatchIndex = max(0, current - 1)
    }

    /// JavaScript 문자열 리터럴용 이스케이프 (작은따옴표 컨텍스트)
    private static func jsEscape(_ s: String) -> String {
        return s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    // MARK: - 바꾸기 (에디터 전용)

    func replaceCurrent() {
        guard searchTarget == .editor,
              let textView = textView,
              !matchRanges.isEmpty,
              currentMatchIndex < matchRanges.count else { return }

        let range = matchRanges[currentMatchIndex]
        if textView.shouldChangeText(in: range, replacementString: replaceText) {
            textView.textStorage?.replaceCharacters(in: range, with: replaceText)
            textView.didChangeText()
        }
        findAll()
    }

    func replaceAll() {
        guard searchTarget == .editor,
              let textView = textView,
              !matchRanges.isEmpty else { return }

        // 뒤에서부터 바꿔야 앞쪽 range가 밀리지 않음
        for range in matchRanges.reversed() {
            if textView.shouldChangeText(in: range, replacementString: replaceText) {
                textView.textStorage?.replaceCharacters(in: range, with: replaceText)
                textView.didChangeText()
            }
        }
        findAll()
    }

    // MARK: - 하이라이트 (포커스를 빼앗지 않음)

    private func scrollToCurrentMatch() {
        guard let textView = textView,
              currentMatchIndex < matchRanges.count else { return }

        let range = matchRanges[currentMatchIndex]
        // scrollRangeToVisible만 호출 — setSelectedRange 하지 않아 포커스 유지
        textView.scrollRangeToVisible(range)
    }

    private func highlightMatches() {
        guard let textView = textView,
              let layoutManager = textView.layoutManager else { return }

        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        for (i, range) in matchRanges.enumerated() {
            let color = (i == currentMatchIndex) ? currentHighlightColor : highlightColor
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        }
    }

    func clearEditorHighlights() {
        guard let textView = textView,
              let layoutManager = textView.layoutManager else { return }

        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
    }

    func clearPreviewHighlights() {
        previewWebView?.evaluateJavaScript("if (window.meFind) window.meFind.clear();", completionHandler: nil)
    }

    func clearAllHighlights() {
        clearEditorHighlights()
        clearPreviewHighlights()
    }

    // MARK: - NSPanel 관리

    private func showPanel() {
        if panel == nil {
            createPanel()
        }

        panel?.makeKeyAndOrderFront(nil)
        positionPanel()

        // 검색 필드에 포커스 + 기존 값 전체 선택 (레이아웃 완료 후)
        DispatchQueue.main.async { [weak self] in
            self?.focusSearchField()
        }
    }

    private func createPanel() {
        let newPanel = FindReplacePanel(manager: self)
        newPanel.title = "찾기 및 바꾸기"
        newPanel.isFloatingPanel = true
        newPanel.becomesKeyOnlyIfNeeded = false
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = false
        newPanel.styleMask = [.titled, .closable, .utilityWindow, .hudWindow]

        let hostingView = NSHostingView(rootView: FindReplaceBar(manager: self))
        newPanel.contentView = hostingView

        // 패널 크기 자동 조정
        let fittingSize = hostingView.fittingSize
        newPanel.setContentSize(NSSize(width: max(420, fittingSize.width), height: fittingSize.height))

        self.panel = newPanel
    }

    private func positionPanel() {
        guard let panel = panel,
              let editorWindow = textView?.window else { return }

        let editorFrame = editorWindow.frame
        // 에디터 윈도우 우상단에 위치
        let panelX = editorFrame.maxX - panel.frame.width - 20
        let panelY = editorFrame.maxY - panel.frame.height - 60
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
    }

    /// showReplace 변경 시 패널 크기 재조정
    func updatePanelSize() {
        guard let panel = panel else { return }
        if let hostingView = panel.contentView as? NSHostingView<FindReplaceBar> {
            let fittingSize = hostingView.fittingSize
            let newSize = NSSize(width: max(420, fittingSize.width), height: fittingSize.height)
            panel.setContentSize(newSize)
        }
    }
}

// MARK: - 찾기/바꾸기 NSPanel

class FindReplacePanel: NSPanel {
    weak var manager: FindReplaceManager?

    convenience init(manager: FindReplaceManager) {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 60),
            styleMask: [.titled, .closable, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        self.manager = manager
    }

    // Enter/Shift+Enter로 다음/이전 찾기 (반복 가능)
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 36 {
            // 검색어를 최근 검색에 기록 (Enter = 검색 확정)
            manager?.recordRecentSearch()
            if event.modifierFlags.contains(.shift) {
                manager?.findPrevious()
            } else {
                manager?.findNext()
            }
            return
        }
        super.sendEvent(event)
    }

    // Escape 키로 닫기
    override func cancelOperation(_ sender: Any?) {
        manager?.close()
    }

    // 윈도우 닫기 버튼(X)
    override func close() {
        manager?.close()
    }
}

// MARK: - 찾기/바꾸기 패널 뷰

struct FindReplaceBar: View {
    @ObservedObject var manager: FindReplaceManager

    var body: some View {
        VStack(spacing: 8) {
            // 검색 대상 선택 (프리뷰가 표시 중일 때만)
            if manager.isPreviewAvailable {
                Picker("", selection: $manager.searchTarget) {
                    Text("에디터").tag(FindReplaceManager.SearchTarget.editor)
                    Text("미리보기").tag(FindReplaceManager.SearchTarget.preview)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("검색 대상 (에디터 소스 / 미리보기)")
            }

            // 찾기 행
            HStack(spacing: 6) {
                // 네이티브 검색 필드 (돋보기 아이콘 + 최근 검색 히스토리 내장)
                RecentSearchField(
                    text: $manager.searchText,
                    placeholder: "찾기",
                    onSetup: { field in manager.searchField = field }
                )
                .frame(minWidth: 180, maxWidth: .infinity)
                .frame(height: 24)

                if manager.totalMatches > 0 {
                    Text("\(manager.currentMatchIndex + 1)/\(manager.totalMatches)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 44, alignment: .center)
                } else if !manager.searchText.isEmpty {
                    Text("없음")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(minWidth: 44, alignment: .center)
                }

                // 대소문자 구분 토글
                Button(action: { manager.caseSensitive.toggle() }) {
                    Text("Aa")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 20)
                        .background(manager.caseSensitive ? Color.accentColor.opacity(0.3) : Color.clear)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help("대소문자 구분")

                Button(action: { manager.findPrevious() }) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("이전 찾기 (⇧⏎)")
                .disabled(manager.totalMatches == 0)

                Button(action: { manager.findNext() }) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("다음 찾기 (⏎)")
                .disabled(manager.totalMatches == 0)

                // 바꾸기 토글 (에디터 검색 시에만 — 프리뷰는 렌더 결과라 바꾸기 불가)
                if manager.searchTarget == .editor {
                    Button(action: {
                        manager.showReplace.toggle()
                        // 크기 재조정을 위해 약간의 딜레이
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            manager.updatePanelSize()
                        }
                    }) {
                        Image(systemName: manager.showReplace ? "chevron.up.chevron.down" : "arrow.triangle.swap")
                    }
                    .buttonStyle(.plain)
                    .help(manager.showReplace ? "바꾸기 닫기" : "바꾸기 열기")
                }
            }

            // 바꾸기 행
            if manager.showReplace && manager.searchTarget == .editor {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.swap")
                        .foregroundColor(.secondary)
                        .frame(width: 16)

                    TextField("바꾸기", text: $manager.replaceText)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 180)

                    Button("바꾸기") {
                        manager.replaceCurrent()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(manager.totalMatches == 0)

                    Button("모두 바꾸기") {
                        manager.replaceAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(manager.totalMatches == 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onAppear {
            // 최초 표시 시 검색 필드에 포커스 + 전체 선택
            DispatchQueue.main.async { manager.focusSearchField() }
        }
    }
}

// MARK: - 네이티브 검색 필드 (최근 검색 히스토리 + 초기화 메뉴 내장)

struct RecentSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSetup: ((NSSearchField) -> Void)?

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchAction(_:))
        field.sendsWholeSearchString = true
        field.sendsSearchStringImmediately = false

        // 최근 검색 히스토리 활성화 (자동 저장 + 드롭다운/초기화 메뉴)
        field.recentsAutosaveName = "MarkdownEditorFindRecents"
        field.maximumRecents = 10
        field.searchMenuTemplate = Coordinator.makeSearchMenu()

        field.stringValue = text
        onSetup?(field)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: RecentSearchField

        init(_ parent: RecentSearchField) { self.parent = parent }

        // 타이핑 시 바인딩 갱신 → 실시간 검색
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        // 최근 검색 선택 / 취소(x) 버튼 등으로 값이 바뀐 경우 바인딩 동기화
        @objc func searchAction(_ sender: NSSearchField) {
            parent.text = sender.stringValue
        }

        // 최근 검색 드롭다운 메뉴 템플릿 (태그 값은 AppKit 표준 상수)
        static func makeSearchMenu() -> NSMenu {
            let menu = NSMenu(title: "Recents")

            let recentsTitle = NSMenuItem(title: "최근 검색", action: nil, keyEquivalent: "")
            recentsTitle.tag = 1000 // NSSearchFieldRecentsTitleMenuItemTag
            menu.addItem(recentsTitle)

            let recentsItem = NSMenuItem(title: "항목", action: nil, keyEquivalent: "")
            recentsItem.tag = 1001 // NSSearchFieldRecentsMenuItemTag
            menu.addItem(recentsItem)

            let noRecents = NSMenuItem(title: "최근 검색 없음", action: nil, keyEquivalent: "")
            noRecents.tag = 1003 // NSSearchFieldNoRecentsMenuItemTag
            menu.addItem(noRecents)

            menu.addItem(NSMenuItem.separator())

            let clear = NSMenuItem(title: "최근 검색 지우기", action: nil, keyEquivalent: "")
            clear.tag = 1002 // NSSearchFieldClearRecentsMenuItemTag
            menu.addItem(clear)

            return menu
        }
    }
}

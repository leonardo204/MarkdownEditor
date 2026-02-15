import SwiftUI
import AppKit

// MARK: - 찾기/바꾸기 매니저

class FindReplaceManager: ObservableObject {
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

    weak var textView: NSTextView?
    private var matchRanges: [NSRange] = []
    private var panel: FindReplacePanel?

    private let highlightColor = NSColor.systemYellow.withAlphaComponent(0.4)
    private let currentHighlightColor = NSColor.systemOrange.withAlphaComponent(0.6)

    // MARK: - 패널 표시/닫기

    func show(withReplace: Bool = false) {
        showReplace = withReplace
        isVisible = true

        // 선택된 텍스트가 있으면 검색어로 설정
        if let textView = textView {
            let selectedRange = textView.selectedRange()
            if selectedRange.length > 0 {
                searchText = (textView.string as NSString).substring(with: selectedRange)
            }
        }

        findAll()
        showPanel()
    }

    func close() {
        // 닫기 시 현재 매치 위치로 에디터 커서 이동
        if !matchRanges.isEmpty && currentMatchIndex < matchRanges.count {
            textView?.setSelectedRange(matchRanges[currentMatchIndex])
            textView?.window?.makeKeyAndOrderFront(nil)
        }

        isVisible = false
        clearHighlights()
        matchRanges = []
        totalMatches = 0
        currentMatchIndex = 0
        panel?.orderOut(nil)
    }

    // MARK: - 검색

    func findAll() {
        guard let textView = textView, !searchText.isEmpty else {
            clearHighlights()
            matchRanges = []
            totalMatches = 0
            currentMatchIndex = 0
            return
        }

        clearHighlights()

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
        guard !matchRanges.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchRanges.count
        highlightMatches()
        scrollToCurrentMatch()
    }

    func findPrevious() {
        guard !matchRanges.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchRanges.count) % matchRanges.count
        highlightMatches()
        scrollToCurrentMatch()
    }

    // MARK: - 바꾸기

    func replaceCurrent() {
        guard let textView = textView,
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
        guard let textView = textView,
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

    func clearHighlights() {
        guard let textView = textView,
              let layoutManager = textView.layoutManager else { return }

        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
    }

    // MARK: - NSPanel 관리

    private func showPanel() {
        if panel == nil {
            createPanel()
        }

        panel?.makeKeyAndOrderFront(nil)
        positionPanel()
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
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // 찾기 행
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .frame(width: 16)

                TextField("찾기", text: $manager.searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFieldFocused)
                    .frame(minWidth: 180)

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

                // 바꾸기 토글
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

            // 바꾸기 행
            if manager.showReplace {
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
        .onAppear { searchFieldFocused = true }
    }
}

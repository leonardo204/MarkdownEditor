import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - 아웃라인 상태
// 커서 라인은 스크롤/커서 이동마다 갱신되므로 @State로 두면 에디터·프리뷰를 포함한
// 전체 body가 매 틱 재평가된다. 아웃라인 사이드바만 구독하도록 별도 객체로 분리한다.
// (소유자인 DocumentContentView는 @State로 "보관만" 하고 구독하지 않는다)
class OutlineState: ObservableObject {
    @Published var currentLine: Int = 0
}

// MARK: - 스크롤 동기화 관리자
// 에디터와 프리뷰 간 스크롤 동기화 관리 (퍼센트 기반, 단순화)
class ScrollSyncManager: ObservableObject {
    @Published var isEnabled: Bool = true
    private var lastSyncTime: CFTimeInterval = 0

    // 아웃라인 클릭 시 설정 — 프리뷰 smooth scroll 동안 에디터 스크롤 기반 라인 업데이트 억제
    var lastOutlineClickTime: CFTimeInterval = 0

    // 참조
    weak var editorScrollView: NSScrollView?
    weak var previewWebView: WKWebView?

    // MARK: - 에코 차단
    //
    // 프리뷰 방향: 에코 판별은 JS 쪽 "사용자 입력 게이트"가 담당한다.
    // 프로그램적 scrollTo와 리플로우는 사용자 입력을 동반하지 않으므로 메시지 자체가 오지 않는다.
    // (카운터 토큰 방식은 rAF 이벤트 병합과 궁합이 나빠 에코가 사용자 스크롤로 오인됐다 — 제거함)
    //
    // 에디터 방향: 프로그램적 스크롤 "구간"을 플래그로 덮어 그 사이의 알림을 전부 무시한다.
    //
    // 건수를 세지 않는 이유: clipView.setBoundsOrigin() 1회가 내부적으로 boundsDidChange를
    // 2건 post한다(가시 창의 copy-on-scroll 경로 — 알림#1은 NSView setBoundsOrigin,
    // 알림#2는 _selfBoundsChanged → translateOriginToPoint:). 건수는 창 가시성과 AppKit
    // 버전에 따라 달라지므로, 1건만 소비하는 래치는 나머지를 통과시켜 에코가 샌다.
    // 알림이 setBoundsOrigin 내부에서 동기 발생하므로 다음 런루프 턴에 해제하면 구간이 정확히 덮인다.
    private var isProgrammaticEditorScroll = false

    // 프리뷰 로드 직후 잡음 억제 기한
    private var loadSettleUntil: CFTimeInterval = 0

    // 최근 에디터 사용자 스크롤 시각 — 양방향 동시 동기화를 막기 위해 최근 조작 주체를 우선한다
    private var lastEditorUserScrollTime: CFTimeInterval = 0

    // 에디터 라인(0-based) → UTF-16 문자 오프셋. Coordinator의 lineStarts 캐시를 재사용해
    // 프리뷰→에디터 역동기화가 매 틱 O(n) 스캔을 하지 않도록 빠른 조회를 주입받는다.
    var editorLineToOffset: ((Int) -> Int)?

    // MARK: - 에디터 스크롤 시 프리뷰 동기화 (VSCode식 라인 앵커 보간)

    /// 프로그램적 에디터 스크롤 구간인지 (스크롤 핸들러의 무거운 작업을 건너뛰는 판단에 사용)
    var isProgrammaticScrollActive: Bool { isProgrammaticEditorScroll }

    /// 매 스크롤 틱 호출되는 경량 훅 — 조작 주체만 기록한다(에코면 무시).
    /// 실제 프리뷰 스크롤은 scrollViewDidScroll이 계산한 라인을 syncPreviewToEditorLine으로 넘긴다.
    func editorDidScroll() {
        guard isEnabled else { return }
        if isProgrammaticEditorScroll { return }   // 프리뷰발 프로그램적 스크롤 = 에코
        lastEditorUserScrollTime = CACurrentMediaTime()
    }

    /// 에디터 최상단 가시 라인(0-based)을 프리뷰에 보간 스크롤로 전달한다.
    /// scrollViewDidScroll이 이미 빠른 경로로 구한 라인을 넘겨받아 재계산을 피한다.
    func syncPreviewToEditorLine(_ line: Int) {
        guard isEnabled, !isProgrammaticEditorScroll,
              let webView = previewWebView else { return }

        // 60fps 쓰로틀 (직전 커밋의 부드러움 유지 — 틱당 작업량을 고정)
        let now = CACurrentMediaTime()
        guard now - lastSyncTime >= 0.016 else { return }
        lastSyncTime = now

        webView.evaluateJavaScript("if(typeof meScrollToLine==='function')meScrollToLine(\(line));",
                                   completionHandler: nil)
    }

    // MARK: - 프리뷰 스크롤 시 에디터 동기화

    func previewDidScroll(sourceLine: Double) {
        guard isEnabled else { return }

        let now = CACurrentMediaTime()

        // 로드 정착 창: 크기를 모르는 리소스(원격 이미지 등)가 뒤늦게 로드되며 일으키는
        // 초기 리플로우를 사용자 스크롤로 오인하지 않도록 억제한다.
        if now < loadSettleUntil { return }

        // 방향 우선순위: 사용자가 에디터를 스크롤하는 중이면 프리뷰가 에디터를 되돌리지 못하게 한다.
        // 양방향 동시 동기화는 항상 위험하므로 최근 조작 주체를 우선한다.
        if now - lastEditorUserScrollTime < 0.5 { return }

        syncEditorToLine(sourceLine)
    }

    /// 프리뷰 페이지 로드 완료 시점에 호출 — 이후 일정 시간 프리뷰→에디터 동기화를 억제한다.
    func beginLoadSettling(duration: TimeInterval = 0.4) {
        loadSettleUntil = CACurrentMediaTime() + duration
    }

    // MARK: - 동기화 로직 (라인 앵커 기반)

    /// 프리뷰를 지정 소스 라인으로 프로그램적 스크롤한다(로드 직후 초기 정렬용).
    /// 되돌아오는 scroll 이벤트는 사용자 입력이 없으므로 JS 게이트가 걸러낸다.
    func scrollPreviewToLine(_ line: Int, in webView: WKWebView) {
        webView.evaluateJavaScript("if(typeof meScrollToLine==='function')meScrollToLine(\(line));",
                                   completionHandler: nil)
    }

    /// 프리뷰가 보고한 소스 라인(소수 가능)을 에디터의 y좌표로 보간해 스크롤한다.
    /// 라인→오프셋은 주입된 빠른 조회(lineStarts 이진탐색), y좌표는 사전 계산된 레이아웃에서
    /// boundingRect로 구하므로 틱당 비용이 낮다.
    private func syncEditorToLine(_ sourceLine: Double) {
        guard let scrollView = editorScrollView,
              let textView = scrollView.documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let lineToOffset = editorLineToOffset else { return }

        let clipView = scrollView.contentView
        let ns = textView.string as NSString

        let floorLine = max(0, Int(floor(sourceLine)))
        let frac = CGFloat(sourceLine - Double(floorLine))

        let off0 = min(lineToOffset(floorLine), ns.length)
        let off1 = min(lineToOffset(floorLine + 1), ns.length)

        func y(for offset: Int) -> CGFloat {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: offset, length: 0),
                                                      actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            return rect.origin.y + textView.textContainerInset.height
        }

        let y0 = y(for: off0)
        let y1 = off1 > off0 ? y(for: off1) : y0
        var target = y0 + frac * (y1 - y0)

        let scrollableHeight = textView.frame.height - clipView.bounds.height
        guard scrollableHeight > 0 else { return }
        target = min(max(0, target), scrollableHeight)

        // 이미 목표 위치면 대입하지 않는다 (불필요한 알림·레이아웃 유발 방지)
        guard abs(clipView.bounds.origin.y - target) >= 1.0 else { return }

        // 대입이 동기 발생시키는 boundsDidChange를 전부 덮도록 구간을 연다.
        // 해제는 다음 런루프 턴 — 그 시점엔 알림이 모두 처리된 뒤다.
        isProgrammaticEditorScroll = true
        clipView.setBoundsOrigin(NSPoint(x: 0, y: target))
        DispatchQueue.main.async { self.isProgrammaticEditorScroll = false }
    }

    /// 에디터 현재 커서 라인(0-based) — 프리뷰 로드 직후 초기 정렬용(1회성이라 O(n) 허용).
    func getEditorCursorLine() -> Int {
        guard let scrollView = editorScrollView,
              let textView = scrollView.documentView as? NSTextView else { return 0 }
        let ns = textView.string as NSString
        let loc = min(textView.selectedRange().location, ns.length)
        return ns.substring(to: loc).components(separatedBy: "\n").count - 1
    }

}

// MARK: - 프리뷰 업데이트 디바운서
// 편집 중에는 프리뷰 업데이트를 지연시켜 깜빡임 방지
class PreviewDebouncer: ObservableObject {
    private var debounceTimer: Timer?
    private var updateAction: (() -> Void)?
    private let delay: TimeInterval

    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    func debounce(action: @escaping () -> Void) {
        updateAction = action
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.updateAction?()
        }
    }

    // 즉시 업데이트 (탭 전환 등)
    func updateNow(action: @escaping () -> Void) {
        debounceTimer?.invalidate()
        action()
    }
}

// MARK: - 에디터 + 미리보기 분할 뷰
struct EditorPreviewSplitView: View {
    @ObservedObject var documentManager: DocumentManager
    @ObservedObject var appState: AppState
    @ObservedObject var actionHandler: EditorActionHandler
    @ObservedObject var scrollSyncManager: ScrollSyncManager
    @Binding var htmlContent: String
    let onFileDrop: ([URL]) -> Void
    var onImageDrop: ((NSImage, String) -> String?)?
    let onContentChange: (String) -> Void
    var findReplaceManager: FindReplaceManager?
    var onCursorLineChange: ((Int) -> Void)?
    var showOutline: Bool = false
    // 구독하지 않고 전달만 한다 (@ObservedObject로 받으면 캐스케이드가 되살아난다)
    let outlineState: OutlineState
    var onSelectHeading: ((Int, Int) -> Void)?
    var focusMode: Bool = false
    var typewriterMode: Bool = false
    var onInsertImageFromFile: (() -> Void)?
    var onImageFilesDrop: (([URL]) -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // 아웃라인 패널 (HSplitView 외부에 배치하여 레이아웃 깨짐 방지)
            if showOutline {
                OutlineView(
                    content: documentManager.content,
                    outlineState: outlineState,
                    onSelectHeading: onSelectHeading,
                    scrollTarget: $appState.outlineScrollTarget
                )
                Divider()
            }

            // 에디터 + 미리보기 분할
            GeometryReader { geo in
                if appState.showPreviewPane {
                    HSplitView {
                        editorPanel
                            .frame(minWidth: 300, idealWidth: geo.size.width / 2)
                        previewPanel
                            .frame(minWidth: 300, idealWidth: geo.size.width / 2)
                    }
                    .id("split_\(appState.showPreviewPane)")
                } else {
                    editorPanel
                }
            }
        }
    }

    // 에디터 패널
    private var editorPanel: some View {
        VStack(spacing: 0) {
            // 에디터 헤더
            EditorHeader(theme: $appState.editorTheme, appState: appState)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // 툴바
            ToolbarView(onAction: { action in
                actionHandler.applyFormatting(action)
                onContentChange(documentManager.content)
            }, onInsertImageFromFile: onInsertImageFromFile)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            // 에디터 뷰
            SimpleEditorView(
                content: $documentManager.content,
                theme: appState.editorTheme,
                fontSize: appState.fontSize,
                showLineNumbers: appState.showLineNumbers,
                onFileDrop: onFileDrop,
                onImageDrop: onImageDrop,
                onImageFilesDrop: onImageFilesDrop,
                actionHandler: actionHandler,
                onContentChange: onContentChange,
                scrollSyncManager: scrollSyncManager,
                findReplaceManager: findReplaceManager,
                onCursorLineChange: onCursorLineChange,
                focusMode: focusMode,
                typewriterMode: typewriterMode
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            StatusBarView(content: documentManager.content)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // 미리보기 패널
    private var previewPanel: some View {
        VStack(spacing: 0) {
            // 미리보기 헤더
            PreviewHeader(
                theme: $appState.previewTheme,
                autoReload: $appState.autoReloadPreview
            )

            Divider()

            // 미리보기 뷰
            PreviewView(
                htmlContent: htmlContent,
                theme: appState.previewTheme,
                scrollSyncManager: scrollSyncManager,
                findReplaceManager: findReplaceManager,
                documentURL: documentManager.currentFileURL
            )
        }
    }
}

// MARK: - FocusedValue를 통해 현재 윈도우의 DocumentManager 접근
struct DocumentManagerKey: FocusedValueKey {
    typealias Value = DocumentManager
}

extension FocusedValues {
    var documentManager: DocumentManager? {
        get { self[DocumentManagerKey.self] }
        set { self[DocumentManagerKey.self] = newValue }
    }
}

// MARK: - 에디터 헤더
struct EditorHeader: View {
    @Binding var theme: EditorTheme
    @ObservedObject var appState: AppState

    var body: some View {
        HStack {
            Text("header.editor")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

            // 미리보기 토글
            Toggle(isOn: Binding(
                get: { appState.showPreviewPane },
                set: { newValue in
                    appState.showPreviewPane = newValue
                    appState.saveSettings()
                }
            )) {
                HStack(spacing: 4) {
                    Image(systemName: appState.showPreviewPane ? "rectangle.split.2x1.fill" : "rectangle.fill")
                        .font(.system(size: 12))
                    Text("header.preview")
                        .font(.system(size: 11))
                }
                .foregroundColor(appState.showPreviewPane ? .accentColor : .secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help(appState.showPreviewPane ? "header.hide_preview" : "header.show_preview")
            .accessibilityLabel(appState.showPreviewPane ? L("header.hide_preview") : L("header.show_preview"))

            // 테마 선택
            Picker(L("header.theme"), selection: $theme) {
                ForEach(EditorTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 미리보기 헤더
struct PreviewHeader: View {
    @Binding var theme: PreviewTheme
    @Binding var autoReload: Bool

    var body: some View {
        HStack {
            Text("header.preview")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

            // 자동 새로고침 체크박스
            Toggle("header.auto_reload", isOn: $autoReload)
                .toggleStyle(.checkbox)
                .font(.caption)

            // 테마 선택
            Picker(L("header.theme"), selection: $theme) {
                ForEach(PreviewTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 상태 바
struct StatusBarView: View {
    let content: String

    private var wordCount: Int {
        let words = content.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }

    private var charCount: Int {
        return content.count
    }

    private var readingTime: String {
        let minutes = max(1, wordCount / 200)
        if wordCount < 200 {
            return L("status.reading_time_short")
        }
        return L("status.reading_time", minutes)
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(L("status.words", wordCount))
            Text(L("status.chars", charCount))
            Text(readingTime)
            Spacer()
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 아웃라인 아이템
struct OutlineItem: Identifiable {
    let id = UUID()
    let level: Int      // 1-6
    let title: String
    let line: Int       // 0-based line number
}

// MARK: - 아웃라인 뷰
struct OutlineView: View {
    let content: String
    // 커서 라인 변경을 실제로 구독하는 유일한 뷰
    @ObservedObject var outlineState: OutlineState
    var onSelectHeading: ((Int, Int) -> Void)?  // (line number, heading index) callback
    @Binding var scrollTarget: OutlineScrollTarget

    private var currentLine: Int { outlineState.currentLine }  // 에디터 커서의 현재 라인 (0-based)

    // 현재 커서 위치에 해당하는 헤딩 라인 (마지막 헤딩 ≤ currentLine)
    // 이미 계산된 items를 받아 재스캔을 피한다.
    private func activeHeadingLine(in items: [OutlineItem]) -> Int? {
        var activeLine: Int? = nil
        for item in items {
            if item.line <= currentLine {
                activeLine = item.line
            } else {
                break
            }
        }
        return activeLine
    }

    private var headings: [OutlineItem] {
        var items: [OutlineItem] = []
        let lines = content.components(separatedBy: "\n")
        var inCodeBlock = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 코드 블록 내부는 무시
            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                continue
            }
            if inCodeBlock { continue }

            // 헤딩 파싱
            if trimmed.hasPrefix("#") {
                var level = 0
                for char in trimmed {
                    if char == "#" { level += 1 }
                    else { break }
                }
                if level >= 1 && level <= 6 && trimmed.count > level {
                    let title = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        items.append(OutlineItem(level: level, title: title, line: index))
                    }
                }
            }
        }
        return items
    }

    var body: some View {
        // headings는 computed라 참조할 때마다 문서 전체를 스캔한다.
        // ForEach 행마다 activeHeadingLine을 통해 재평가되면 헤딩 H개일 때 전체 스캔이 H회 발생 →
        // 진입부에서 1회만 계산해 지역 변수로 쓴다.
        let items = headings
        let active = activeHeadingLine(in: items)

        return VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                Text("outline.title")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $scrollTarget) {
                    ForEach(OutlineScrollTarget.allCases, id: \.self) { target in
                        Text(target.displayName).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if items.isEmpty {
                VStack {
                    Spacer()
                    Text("outline.empty")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let isActive = item.line == active
                            Button(action: {
                                DebugLogger.shared.log("[Outline] Button tapped: index:\(index), line:\(item.line), title:'\(item.title)', activeHeadingLine:\(String(describing: active)), currentLine:\(currentLine)")
                                onSelectHeading?(item.line, index)
                            }) {
                                HStack(spacing: 4) {
                                    Text(String(repeating: "  ", count: item.level - 1))
                                        .font(.system(size: 11, design: .monospaced))
                                    Text(item.title)
                                        .font(.system(size: fontSize(for: item.level)))
                                        .fontWeight(item.level <= 2 ? .semibold : .regular)
                                        .foregroundColor(isActive ? .accentColor : .primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                                .cornerRadius(4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 200)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func fontSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 13
        case 2: return 12.5
        default: return 12
        }
    }
}

#Preview {
    let dm = DocumentManager()
    EditorPreviewSplitView(
        documentManager: dm,
        appState: AppState(),
        actionHandler: EditorActionHandler(),
        scrollSyncManager: ScrollSyncManager(),
        htmlContent: .constant("<p>Preview</p>"),
        onFileDrop: { _ in },
        onImageDrop: { _, _ in nil },
        onContentChange: { _ in },
        outlineState: OutlineState()
    )
}

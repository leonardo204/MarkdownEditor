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

    // MARK: - 에디터 스크롤 시 프리뷰 동기화

    /// 프로그램적 에디터 스크롤 구간인지 (스크롤 핸들러의 무거운 작업을 건너뛰는 판단에 사용)
    var isProgrammaticScrollActive: Bool { isProgrammaticEditorScroll }

    func editorDidScroll() {
        guard isEnabled else { return }

        // 우리가 syncEditorToPreview에서 만든 스크롤 구간이면 전부 무시
        if isProgrammaticEditorScroll { return }

        // 여기까지 왔으면 에코가 아닌 실제 에디터 스크롤 → 조작 주체를 에디터로 기록
        let now = CACurrentMediaTime()
        lastEditorUserScrollTime = now

        // 쓰로틀링
        guard now - lastSyncTime >= 0.016 else { return }
        lastSyncTime = now

        syncPreviewToEditor()
    }

    // MARK: - 프리뷰 스크롤 시 에디터 동기화

    func previewDidScroll(scrollPercent: Double) {
        guard isEnabled else { return }

        let now = CACurrentMediaTime()

        // 로드 정착 창: 크기를 모르는 리소스(원격 이미지 등)가 뒤늦게 로드되며 일으키는
        // 초기 리플로우를 사용자 스크롤로 오인하지 않도록 억제한다.
        if now < loadSettleUntil { return }

        // 방향 우선순위: 사용자가 에디터를 스크롤하는 중이면 프리뷰가 에디터를 되돌리지 못하게 한다.
        // 양방향 동시 동기화는 항상 위험하므로 최근 조작 주체를 우선한다.
        if now - lastEditorUserScrollTime < 0.5 { return }

        syncEditorToPreview(scrollPercent: scrollPercent)
    }

    /// 프리뷰 페이지 로드 완료 시점에 호출 — 이후 일정 시간 프리뷰→에디터 동기화를 억제한다.
    func beginLoadSettling(duration: TimeInterval = 0.4) {
        loadSettleUntil = CACurrentMediaTime() + duration
    }

    // MARK: - 동기화 로직 (단순 퍼센트 기반)

    /// 프리뷰를 지정 퍼센트로 프로그램적 스크롤한다.
    /// 되돌아오는 scroll 이벤트는 사용자 입력이 없으므로 JS 게이트가 걸러낸다.
    func scrollPreviewToPercent(_ percent: Double, in webView: WKWebView) {
        let clamped = min(1.0, max(0.0, percent))
        let js = """
        (function() {
            var h = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) - window.innerHeight;
            if (h <= 0) return;
            var target = h * \(clamped);
            if (Math.abs(target - window.scrollY) < 0.5) return;
            window.scrollTo(0, target);
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func syncPreviewToEditor() {
        guard editorScrollView != nil,
              let webView = previewWebView else { return }

        scrollPreviewToPercent(getEditorScrollPercent(), in: webView)
    }

    private func syncEditorToPreview(scrollPercent: Double) {
        guard let scrollView = editorScrollView,
              let documentView = scrollView.documentView else { return }

        let clipView = scrollView.contentView
        let scrollableHeight = documentView.frame.height - clipView.bounds.height

        guard scrollableHeight > 0 else { return }

        // 러버밴드 오버스크롤로 0..1 밖의 퍼센트가 올 수 있다 → 클램프하지 않으면
        // 에디터가 문서 경계 밖으로 밀려난다.
        let clamped = min(1.0, max(0.0, scrollPercent))
        let target = scrollableHeight * CGFloat(clamped)

        // 이미 목표 위치면 대입하지 않는다 (불필요한 알림·레이아웃 유발 방지)
        guard abs(clipView.bounds.origin.y - target) >= 1.0 else { return }

        // 대입이 동기 발생시키는 boundsDidChange를 전부 덮도록 구간을 연다.
        // 해제는 다음 런루프 턴 — 그 시점엔 알림이 모두 처리된 뒤다.
        isProgrammaticEditorScroll = true
        clipView.setBoundsOrigin(NSPoint(x: 0, y: target))
        DispatchQueue.main.async { self.isProgrammaticEditorScroll = false }
    }

    // 에디터 스크롤 퍼센트 계산 (스크롤 위치 기반)
    func getEditorScrollPercent() -> Double {
        guard let scrollView = editorScrollView,
              let documentView = scrollView.documentView else { return 0 }

        let clipView = scrollView.contentView
        let scrollableHeight = documentView.frame.height - clipView.bounds.height

        guard scrollableHeight > 0 else { return 0 }
        return min(1.0, max(0.0, Double(clipView.bounds.origin.y / scrollableHeight)))
    }

    // 에디터 커서 라인 기반 퍼센트 계산 (편집 시 사용)
    func getEditorCursorLinePercent() -> Double {
        guard let scrollView = editorScrollView,
              let textView = scrollView.documentView as? NSTextView else { return 0 }

        let text = textView.string
        let nsText = text as NSString
        // selectedRange는 UTF-16 오프셋이므로 상한도 UTF-16 길이를 써야 한다.
        // text.count(Character 수)와 혼용하면 한글 등 멀티바이트 문서에서 엉뚱한 위치를 자른다.
        let cursorPosition = min(textView.selectedRange().location, nsText.length)

        // 커서 위치까지의 라인 수 계산
        let textUpToCursor = nsText.substring(to: cursorPosition)
        let currentLine = textUpToCursor.components(separatedBy: "\n").count

        // 전체 라인 수
        let totalLines = max(1, text.components(separatedBy: "\n").count)

        guard totalLines > 1 else { return 0 }
        return min(1.0, Double(currentLine - 1) / Double(totalLines - 1))
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
            Text("Editor")
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
                    Text("Preview")
                        .font(.system(size: 11))
                }
                .foregroundColor(appState.showPreviewPane ? .accentColor : .secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help(appState.showPreviewPane ? "Hide Preview" : "Show Preview")
            .accessibilityLabel(appState.showPreviewPane ? "Hide Preview" : "Show Preview")

            // 테마 선택
            Picker("Theme", selection: $theme) {
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
            Text("Preview")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

            // 자동 새로고침 체크박스
            Toggle("Auto reload", isOn: $autoReload)
                .toggleStyle(.checkbox)
                .font(.caption)

            // 테마 선택
            Picker("Theme", selection: $theme) {
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
            return "< 1 min"
        }
        return "\(minutes) min"
    }

    var body: some View {
        HStack(spacing: 16) {
            Text("\(wordCount) words")
            Text("\(charCount) chars")
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
                Text("Outline")
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
                    Text("No headings")
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

import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - 스크롤 동기화 관리자
// 에디터와 프리뷰 간 스크롤 동기화 관리 (퍼센트 기반, 단순화)
class ScrollSyncManager: ObservableObject {
    enum ScrollSource {
        case none
        case editor
        case preview
    }

    @Published var isEnabled: Bool = true
    private var currentSource: ScrollSource = .none
    private var lastSyncTime: CFTimeInterval = 0

    // 참조
    weak var editorScrollView: NSScrollView?
    weak var previewWebView: WKWebView?

    // 소스 리셋 타이머
    private var resetTimer: Timer?

    // MARK: - 에디터 스크롤 시 프리뷰 동기화

    func editorDidScroll() {
        guard isEnabled, currentSource != .preview else { return }

        // 쓰로틀링
        let now = CACurrentMediaTime()
        guard now - lastSyncTime >= 0.016 else { return }
        lastSyncTime = now

        currentSource = .editor
        syncPreviewToEditor()
        scheduleSourceReset()
    }

    // MARK: - 프리뷰 스크롤 시 에디터 동기화

    func previewDidScroll(scrollPercent: Double) {
        guard isEnabled, currentSource != .editor else { return }

        currentSource = .preview
        syncEditorToPreview(scrollPercent: scrollPercent)
        scheduleSourceReset()
    }

    // MARK: - 동기화 로직 (단순 퍼센트 기반)

    deinit {
        resetTimer?.invalidate()
    }

    private func syncPreviewToEditor() {
        guard let _ = editorScrollView,
              let webView = previewWebView else { return }

        let percent = getEditorScrollPercent()

        let js = """
        (function() {
            var h = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) - window.innerHeight;
            if (h > 0) window.scrollTo(0, h * \(percent));
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func syncEditorToPreview(scrollPercent: Double) {
        guard let scrollView = editorScrollView,
              let documentView = scrollView.documentView else { return }

        let clipView = scrollView.contentView
        let scrollableHeight = documentView.frame.height - clipView.bounds.height

        if scrollableHeight > 0 {
            clipView.setBoundsOrigin(NSPoint(x: 0, y: scrollableHeight * CGFloat(scrollPercent)))
        }
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
        let cursorPosition = textView.selectedRange().location

        // 커서 위치까지의 라인 수 계산
        let textUpToCursor = (text as NSString).substring(to: min(cursorPosition, text.count))
        let currentLine = textUpToCursor.components(separatedBy: "\n").count

        // 전체 라인 수
        let totalLines = max(1, text.components(separatedBy: "\n").count)

        guard totalLines > 1 else { return 0 }
        return min(1.0, Double(currentLine - 1) / Double(totalLines - 1))
    }

    private func scheduleSourceReset() {
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.currentSource = .none
        }
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
    var currentLine: Int = 0
    var onSelectHeading: ((Int) -> Void)?
    var focusMode: Bool = false
    var typewriterMode: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // 아웃라인 패널 (HSplitView 외부에 배치하여 레이아웃 깨짐 방지)
            if showOutline {
                OutlineView(
                    content: documentManager.content,
                    currentLine: currentLine,
                    onSelectHeading: onSelectHeading
                )
                Divider()
            }

            // 에디터 + 미리보기 분할
            HSplitView {
                editorPanel
                previewPanel
            }
        }
    }

    // 에디터 패널
    private var editorPanel: some View {
        VStack(spacing: 0) {
            // 에디터 헤더
            EditorHeader(theme: $appState.editorTheme)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // 툴바
            ToolbarView { action in
                actionHandler.applyFormatting(action)
                onContentChange(documentManager.content)
            }
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
        .frame(minWidth: 300)
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
                scrollSyncManager: scrollSyncManager
            )
        }
        .frame(minWidth: 300)
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

    var body: some View {
        HStack {
            Text("Editor")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

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
    var currentLine: Int = 0  // 에디터 커서의 현재 라인 (0-based)
    var onSelectHeading: ((Int) -> Void)?  // line number callback

    // 현재 커서 위치에 해당하는 헤딩 라인 (마지막 헤딩 ≤ currentLine)
    private var activeHeadingLine: Int? {
        var activeLine: Int? = nil
        for item in headings {
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
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                Text("Outline")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if headings.isEmpty {
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
                        ForEach(headings) { item in
                            let isActive = item.line == activeHeadingLine
                            Button(action: {
                                onSelectHeading?(item.line)
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
        onContentChange: { _ in }
    )
}

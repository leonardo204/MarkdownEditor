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

    private func syncPreviewToEditor() {
        guard let scrollView = editorScrollView,
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
    let onContentChange: (String) -> Void

    var body: some View {
        HSplitView {
            // 에디터 패널
            editorPanel

            // 미리보기 패널
            previewPanel
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
                actionHandler: actionHandler,
                onContentChange: onContentChange,
                scrollSyncManager: scrollSyncManager
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#Preview {
    let dm = DocumentManager()
    EditorPreviewSplitView(
        documentManager: dm,
        appState: AppState(),
        actionHandler: EditorActionHandler(),
        scrollSyncManager: ScrollSyncManager(),
        htmlContent: .constant("<p>Preview</p>"),
        onFileDrop: { _ in },
        onContentChange: { _ in }
    )
}

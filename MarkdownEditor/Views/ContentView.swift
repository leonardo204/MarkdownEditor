import SwiftUI
import WebKit

// MARK: - 스크롤 동기화 관리자
// 에디터와 프리뷰 간 스크롤 동기화 관리
class ScrollSyncManager: ObservableObject {
    // 스크롤 소스 (어디서 스크롤이 시작되었는지)
    enum ScrollSource {
        case none
        case editor
        case preview
    }

    @Published var isEnabled: Bool = true
    private var currentSource: ScrollSource = .none
    private var lastScrollTime: CFTimeInterval = 0
    private let minScrollInterval: CFTimeInterval = 0.008 // ~120fps

    // 참조
    weak var editorScrollView: NSScrollView?
    weak var previewWebView: WKWebView?

    // 스크롤 소스 리셋 타이머
    private var resetTimer: Timer?

    // MARK: - 에디터 스크롤 처리

    func editorDidScroll() {
        guard isEnabled else { return }

        // 프리뷰에서 시작된 스크롤이면 무시
        if currentSource == .preview { return }

        // 쓰로틀링: 너무 빈번한 호출 방지
        let now = CACurrentMediaTime()
        guard now - lastScrollTime >= minScrollInterval else { return }
        lastScrollTime = now

        currentSource = .editor
        syncPreviewToEditor()
        scheduleSourceReset()
    }

    // MARK: - 프리뷰 스크롤 처리

    func previewDidScroll(scrollPercent: Double) {
        guard isEnabled else { return }

        // 에디터에서 시작된 스크롤이면 무시
        if currentSource == .editor { return }

        currentSource = .preview
        syncEditorToPreview(scrollPercent: scrollPercent)
        scheduleSourceReset()
    }

    // MARK: - 동기화 로직

    private func syncPreviewToEditor() {
        guard let scrollView = editorScrollView,
              let webView = previewWebView else { return }

        let scrollPercent = calculateEditorScrollPercent(scrollView)

        // JavaScript로 프리뷰 스크롤 (즉시 실행, 애니메이션 없음)
        let js = """
        (function() {
            var height = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
            var scrollableHeight = height - window.innerHeight;
            if (scrollableHeight > 0) {
                window.scrollTo({top: scrollableHeight * \(scrollPercent), behavior: 'instant'});
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func syncEditorToPreview(scrollPercent: Double) {
        guard let scrollView = editorScrollView,
              let documentView = scrollView.documentView else { return }
        let clipView = scrollView.contentView

        let documentHeight = documentView.frame.height
        let clipHeight = clipView.bounds.height
        let scrollableHeight = documentHeight - clipHeight

        if scrollableHeight > 0 {
            let newY = scrollableHeight * CGFloat(scrollPercent)
            // 즉시 스크롤 (애니메이션 없음)
            clipView.setBoundsOrigin(NSPoint(x: 0, y: newY))
        }
    }

    private func calculateEditorScrollPercent(_ scrollView: NSScrollView) -> Double {
        guard let documentView = scrollView.documentView else { return 0 }
        let clipView = scrollView.contentView

        let documentHeight = documentView.frame.height
        let clipHeight = clipView.bounds.height
        let scrollableHeight = documentHeight - clipHeight

        if scrollableHeight <= 0 { return 0 }

        let currentY = clipView.bounds.origin.y
        return min(1.0, max(0.0, Double(currentY / scrollableHeight)))
    }

    // MARK: - 소스 리셋

    private func scheduleSourceReset() {
        resetTimer?.invalidate()
        resetTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.currentSource = .none
        }
    }
}

// 메인 콘텐츠 뷰
// 에디터와 미리보기를 분할 화면으로 표시

struct MainContentView: View {
    // 각 윈도우마다 독립적인 DocumentManager 생성
    @StateObject private var documentManager = DocumentManager()
    @StateObject private var appState = AppState()
    @StateObject private var actionHandler = EditorActionHandler()
    @StateObject private var scrollSyncManager = ScrollSyncManager()
    @State private var htmlContent: String = ""
    @Environment(\.openWindow) private var openWindow

    private let markdownProcessor = MarkdownProcessor()

    var body: some View {
        HSplitView {
            // 에디터 패널
            VStack(spacing: 0) {
                // 에디터 헤더
                EditorHeader(theme: $appState.editorTheme)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                // 툴바
                ToolbarView { action in
                    actionHandler.applyFormatting(action)
                    updatePreview()
                }
                .fixedSize(horizontal: false, vertical: true)

                Divider()

                // 에디터 뷰 (SimpleEditorView 사용)
                SimpleEditorView(
                    content: $documentManager.content,
                    theme: appState.editorTheme,
                    fontSize: appState.fontSize,
                    showLineNumbers: appState.showLineNumbers,
                    onFileDrop: { fileURLs in
                        handleFileDrop(fileURLs)
                    },
                    actionHandler: actionHandler,
                    onContentChange: { newContent in
                        documentManager.updateContent(newContent)
                        updatePreview()
                    },
                    scrollSyncManager: scrollSyncManager
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 300)

            // 미리보기 패널
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
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle(documentManager.windowTitle + (documentManager.isModified ? " *" : ""))
        .focusedSceneValue(\.documentManager, documentManager)
        .onAppear {
            // Pending 파일이 있으면 로드
            if let pendingURL = PendingFileManager.shared.popPendingFile() {
                documentManager.loadFile(from: pendingURL)
            }
            updatePreview()
        }
        .background(WindowAccessor(documentManager: documentManager))
        .onChange(of: documentManager.content) { _ in
            if appState.autoReloadPreview {
                updatePreview()
            }
        }
    }

    private func updatePreview() {
        htmlContent = markdownProcessor.convertToHTML(documentManager.content)
    }

    // 드래그 앤 드롭 처리 (여러 파일 지원)
    private func handleFileDrop(_ fileURLs: [URL]) {
        guard !fileURLs.isEmpty else { return }

        var urlsToOpenInNewWindows: [URL] = []

        // 현재 창이 비어있으면 첫 번째 파일을 현재 창에서 열기
        if documentManager.currentFileURL == nil && documentManager.content.isEmpty {
            documentManager.loadFile(from: fileURLs[0])
            updatePreview()
            // 나머지 파일들은 새 창에서 열기
            urlsToOpenInNewWindows = Array(fileURLs.dropFirst())
        } else {
            // 수정 사항이 있으면 저장 확인
            if documentManager.isModified {
                if !documentManager.confirmSaveIfNeeded() {
                    return  // 취소됨
                }
            }
            // 모든 파일을 새 창에서 열기
            urlsToOpenInNewWindows = fileURLs
        }

        // 새 창에서 파일 열기
        for fileURL in urlsToOpenInNewWindows {
            openFileInNewWindow(fileURL)
        }
    }

    // 새 창에서 파일 열기
    private func openFileInNewWindow(_ fileURL: URL) {
        // 파일 URL을 pending 큐에 추가하고 새 창 열기
        PendingFileManager.shared.addPendingFile(fileURL)
        // SwiftUI의 openWindow 사용
        openWindow(id: "main")
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

// MARK: - 새 창 열기용 Pending 파일 관리
class PendingFileManager {
    static let shared = PendingFileManager()
    private var pendingFileURLs: [URL] = []
    private let lock = NSLock()

    // 파일 추가
    func addPendingFile(_ url: URL) {
        lock.lock()
        pendingFileURLs.append(url)
        lock.unlock()
    }

    // 다음 파일 가져오기 (큐에서 제거)
    func popPendingFile() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return pendingFileURLs.isEmpty ? nil : pendingFileURLs.removeFirst()
    }
}

// MARK: - 윈도우 접근자 (DocumentManager를 윈도우에 등록 및 닫기 처리)
struct WindowAccessor: NSViewRepresentable {
    let documentManager: DocumentManager

    func makeCoordinator() -> Coordinator {
        Coordinator(documentManager: documentManager)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                WindowDocumentManagerRegistry.shared.register(documentManager, for: window)
                // 윈도우 delegate 설정
                context.coordinator.setupWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                WindowDocumentManagerRegistry.shared.register(documentManager, for: window)
                context.coordinator.setupWindow(window)
            }
        }
    }

    class Coordinator: NSObject, NSWindowDelegate {
        let documentManager: DocumentManager
        weak var window: NSWindow?

        init(documentManager: DocumentManager) {
            self.documentManager = documentManager
        }

        func setupWindow(_ window: NSWindow) {
            guard self.window !== window else { return }
            self.window = window
            window.delegate = self
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard documentManager.isModified else { return true }

            let alert = NSAlert()
            alert.messageText = "변경 사항을 저장하시겠습니까?"
            alert.informativeText = "저장하지 않으면 변경 사항이 손실됩니다."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "저장")
            alert.addButton(withTitle: "저장 안 함")
            alert.addButton(withTitle: "취소")

            let response = alert.runModal()

            switch response {
            case .alertFirstButtonReturn:  // 저장
                documentManager.saveDocument()
                return true
            case .alertSecondButtonReturn:  // 저장 안 함
                return true
            case .alertThirdButtonReturn:  // 취소
                return false
            default:
                return false
            }
        }

        func windowWillClose(_ notification: Notification) {
            if let window = notification.object as? NSWindow {
                WindowDocumentManagerRegistry.shared.unregister(for: window)
            }
        }
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
    MainContentView()
        .environmentObject(DocumentManager())
}

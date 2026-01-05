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

// MARK: - 메인 콘텐츠 뷰
// 탭 바 + 에디터 + 미리보기

struct MainContentView: View {
    // 탭 관리자
    @StateObject private var tabManager = TabManager()
    @StateObject private var appState = AppState()
    @StateObject private var actionHandler = EditorActionHandler()
    @StateObject private var scrollSyncManager = ScrollSyncManager()
    @State private var htmlContent: String = ""
    @State private var pendingFileCheckTimer: Timer?

    private let markdownProcessor = MarkdownProcessor()

    // 현재 선택된 DocumentManager
    private var currentDocumentManager: DocumentManager? {
        tabManager.currentDocumentManager
    }

    var body: some View {
        VStack(spacing: 0) {
            // 커스텀 탭 바
            TabBarView(tabManager: tabManager) {
                // 새 탭 추가
                tabManager.addNewTab()
            }

            // 에디터 + 미리보기
            if let documentManager = currentDocumentManager {
                EditorPreviewSplitView(
                    documentManager: documentManager,
                    appState: appState,
                    actionHandler: actionHandler,
                    scrollSyncManager: scrollSyncManager,
                    htmlContent: $htmlContent,
                    onFileDrop: handleFileDrop,
                    onContentChange: { newContent in
                        documentManager.updateContent(newContent)
                        updatePreview()
                    }
                )
            } else {
                // 탭이 없는 경우 (일반적으로 발생하지 않음)
                Text("No document")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle(windowTitle)
        .focusedSceneValue(\.documentManager, currentDocumentManager)
        .focusedSceneValue(\.tabManager, tabManager)
        .onAppear {
            DebugLogger.shared.log("MainContentView.onAppear")

            // 즉시 pending 파일 확인
            if tryLoadPendingFile() {
                DebugLogger.shared.log("Loaded pending file immediately")
            } else {
                // 파일이 없으면 폴링 시작 (최대 1초간)
                DebugLogger.shared.log("No pending file, starting polling")
                startPendingFilePolling()
            }

            updatePreview()
        }
        .onDisappear {
            pendingFileCheckTimer?.invalidate()
            pendingFileCheckTimer = nil
        }
        .background(WindowAccessor(tabManager: tabManager))
        .onChange(of: tabManager.selectedTabIndex) { _ in
            // 탭 변경 시 프리뷰 업데이트
            updatePreview()
        }
        .onChange(of: currentDocumentManager?.content) { _ in
            if appState.autoReloadPreview {
                updatePreview()
            }
        }
    }

    // 윈도우 타이틀
    private var windowTitle: String {
        guard let dm = currentDocumentManager else { return "Untitled" }
        return dm.windowTitle + (dm.isModified ? " *" : "")
    }

    // pending 파일 로드 시도 (성공하면 true)
    private func tryLoadPendingFile() -> Bool {
        guard let dm = currentDocumentManager else { return false }

        // 이미 파일이 열려있으면 스킵
        guard dm.currentFileURL == nil && dm.content.isEmpty else {
            return false
        }

        if let pendingURL = FileOpenManager.shared.popPendingFile() {
            DebugLogger.shared.log("Loading pending file: \(pendingURL.lastPathComponent)")
            dm.loadFile(from: pendingURL)
            updatePreview()
            return true
        }
        return false
    }

    // 폴링으로 pending 파일 확인 (타이밍 문제 해결용)
    private func startPendingFilePolling() {
        var attempts = 0
        let maxAttempts = 20  // 최대 1초 (50ms * 20)

        pendingFileCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            attempts += 1

            if tryLoadPendingFile() {
                DebugLogger.shared.log("Polling: loaded file on attempt \(attempts)")
                timer.invalidate()
                pendingFileCheckTimer = nil
            } else if attempts >= maxAttempts {
                DebugLogger.shared.log("Polling: max attempts reached, stopping")
                timer.invalidate()
                pendingFileCheckTimer = nil
            }
        }
    }

    private func updatePreview() {
        guard let dm = currentDocumentManager else {
            htmlContent = ""
            return
        }
        htmlContent = markdownProcessor.convertToHTML(dm.content)
    }

    // 드래그 앤 드롭 처리 (여러 파일 지원)
    private func handleFileDrop(_ fileURLs: [URL]) {
        guard !fileURLs.isEmpty else { return }
        guard let dm = currentDocumentManager else { return }

        let openInNewTab = UserDefaults.standard.object(forKey: "openFilesInNewTab") as? Bool ?? true
        DebugLogger.shared.log("handleFileDrop: \(fileURLs.count) files, openInNewTab: \(openInNewTab)")

        var urlsToOpen: [URL] = []

        // 현재 탭이 비어있으면 첫 번째 파일을 현재 탭에서 열기
        if dm.currentFileURL == nil && dm.content.isEmpty {
            // 첫 번째 파일이 이미 열려있는지 확인
            if let existingIndex = tabManager.tabs.firstIndex(where: {
                $0.documentManager.currentFileURL?.standardizedFileURL == fileURLs[0].standardizedFileURL
            }) {
                tabManager.selectTab(at: existingIndex)
            } else {
                dm.loadFile(from: fileURLs[0])
                updatePreview()
            }
            // 나머지 파일들
            urlsToOpen = Array(fileURLs.dropFirst())
        } else {
            // 현재 문서가 있으면 모든 파일을 새 탭에서 열기
            urlsToOpen = fileURLs
        }

        // 새 탭에서 파일 열기
        for url in urlsToOpen {
            // 이미 열린 파일인지 확인
            if let existingIndex = tabManager.tabs.firstIndex(where: {
                $0.documentManager.currentFileURL?.standardizedFileURL == url.standardizedFileURL
            }) {
                tabManager.selectTab(at: existingIndex)
            } else if openInNewTab {
                // 새 탭에서 열기
                tabManager.openFileInNewTab(url: url)
            } else {
                // 새 윈도우에서 열기
                FileOpenManager.shared.addPendingFile(url, checkDuplicate: false)
                NewWindowTrigger.shared.trigger()
            }
        }
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
    }
}

// MARK: - FocusedValue를 통해 현재 윈도우의 DocumentManager/TabManager 접근
struct DocumentManagerKey: FocusedValueKey {
    typealias Value = DocumentManager
}

struct TabManagerKey: FocusedValueKey {
    typealias Value = TabManager
}

extension FocusedValues {
    var documentManager: DocumentManager? {
        get { self[DocumentManagerKey.self] }
        set { self[DocumentManagerKey.self] = newValue }
    }

    var tabManager: TabManager? {
        get { self[TabManagerKey.self] }
        set { self[TabManagerKey.self] = newValue }
    }
}


// MARK: - 윈도우 접근자 (TabManager를 윈도우에 등록 및 닫기 처리)
struct WindowAccessor: NSViewRepresentable {
    let tabManager: TabManager

    func makeCoordinator() -> Coordinator {
        Coordinator(tabManager: tabManager)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DebugLogger.shared.log("WindowAccessor.makeNSView called")
        DispatchQueue.main.async {
            if let window = view.window {
                DebugLogger.shared.log("WindowAccessor.makeNSView - Registering window")
                WindowTabManagerRegistry.shared.register(tabManager, for: window)
                // 윈도우 delegate 설정
                context.coordinator.setupWindow(window)
            } else {
                DebugLogger.shared.log("WindowAccessor.makeNSView - No window yet")
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                WindowTabManagerRegistry.shared.register(tabManager, for: window)
                context.coordinator.setupWindow(window)
            }
        }
    }

    class Coordinator: NSObject, NSWindowDelegate {
        let tabManager: TabManager
        weak var window: NSWindow?

        init(tabManager: TabManager) {
            self.tabManager = tabManager
        }

        func setupWindow(_ window: NSWindow) {
            guard self.window !== window else { return }
            self.window = window
            window.delegate = self
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            // 모든 탭의 수정사항 확인
            return tabManager.confirmSaveAllIfNeeded()
        }

        func windowWillClose(_ notification: Notification) {
            if let window = notification.object as? NSWindow {
                WindowTabManagerRegistry.shared.unregister(for: window)
            }
        }
    }
}

// MARK: - 윈도우별 TabManager 레지스트리
class WindowTabManagerRegistry {
    static let shared = WindowTabManagerRegistry()
    private var registry: [ObjectIdentifier: (window: NSWindow, manager: TabManager)] = [:]

    func register(_ tabManager: TabManager, for window: NSWindow) {
        registry[ObjectIdentifier(window)] = (window, tabManager)
    }

    func unregister(for window: NSWindow) {
        registry.removeValue(forKey: ObjectIdentifier(window))
    }

    func tabManager(for window: NSWindow) -> TabManager? {
        return registry[ObjectIdentifier(window)]?.manager
    }

    var allTabManagers: [TabManager] {
        return registry.values.map { $0.manager }
    }

    // 파일이 이미 열려있는지 확인하고, 열려있으면 해당 탭으로 이동
    func bringToFrontIfAlreadyOpen(_ fileURL: URL) -> Bool {
        for (_, entry) in registry {
            if let tabIndex = entry.manager.tabs.firstIndex(where: {
                $0.documentManager.currentFileURL?.standardizedFileURL == fileURL.standardizedFileURL
            }) {
                entry.manager.selectTab(at: tabIndex)
                entry.window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return true
            }
        }
        return false
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
}

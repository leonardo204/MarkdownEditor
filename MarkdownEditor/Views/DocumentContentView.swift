import SwiftUI
import WebKit

// MARK: - 문서 콘텐츠 뷰
// NSHostingView에서 호스팅되는 SwiftUI 루트 뷰
// DocumentManager를 외부(DocumentWindowController)에서 주입받음

struct DocumentContentView: View {
    // DocumentManager는 외부에서 주입됨 (DocumentWindowController가 소유)
    @ObservedObject var documentManager: DocumentManager

    // 앱 상태 및 에디터 상태
    @StateObject private var appState = AppState()
    @StateObject private var actionHandler = EditorActionHandler()
    @StateObject private var scrollSyncManager = ScrollSyncManager()
    @StateObject private var previewDebouncer = PreviewDebouncer(delay: 0.3)

    // HTML 콘텐츠 (프리뷰용)
    @State private var htmlContent: String = ""

    private let markdownProcessor = MarkdownProcessor()

    var body: some View {
        EditorPreviewSplitView(
            documentManager: documentManager,
            appState: appState,
            actionHandler: actionHandler,
            scrollSyncManager: scrollSyncManager,
            htmlContent: $htmlContent,
            onFileDrop: handleFileDrop,
            onContentChange: { newContent in
                documentManager.updateContent(newContent)
                // 디바운스: 편집 중에는 프리뷰 업데이트 지연
                previewDebouncer.debounce {
                    updatePreview()
                }
            }
        )
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            DebugLogger.shared.log("DocumentContentView.onAppear")
            updatePreview()
        }
        .onChange(of: documentManager.content) { _ in
            // DocumentManager의 content가 외부에서 변경될 때 (파일 로드 등)
            previewDebouncer.updateNow {
                updatePreview()
            }
        }
    }

    // MARK: - 프리뷰 업데이트

    private func updatePreview() {
        htmlContent = markdownProcessor.convertToHTML(documentManager.content)
    }

    // MARK: - 드래그 앤 드롭 처리 (파일)

    private func handleFileDrop(_ fileURLs: [URL]) {
        guard !fileURLs.isEmpty else { return }

        DebugLogger.shared.log("DocumentContentView.handleFileDrop: \(fileURLs.count) files")

        // 현재 문서가 비어있으면 첫 번째 파일을 현재 윈도우에서 열기
        if documentManager.currentFileURL == nil && documentManager.content.isEmpty {
            // 이미 열린 파일인지 확인
            if let existingController = TabService.shared.findController(for: fileURLs[0]) {
                existingController.window?.makeKeyAndOrderFront(nil)
                // 나머지 파일들은 새 윈도우에서 열기
                for url in fileURLs.dropFirst() {
                    TabService.shared.openDocument(url: url)
                }
            } else {
                documentManager.loadFile(from: fileURLs[0])
                updatePreview()

                // 나머지 파일들은 새 윈도우에서 열기
                for url in fileURLs.dropFirst() {
                    TabService.shared.openDocument(url: url)
                }
            }
        } else {
            // 현재 문서가 있으면 모든 파일을 새 윈도우에서 열기
            for url in fileURLs {
                TabService.shared.openDocument(url: url)
            }
        }
    }
}

#Preview {
    DocumentContentView(documentManager: DocumentManager())
}

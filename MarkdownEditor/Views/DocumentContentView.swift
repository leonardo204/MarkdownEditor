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
    @StateObject private var findReplaceManager = FindReplaceManager()

    // HTML 콘텐츠 (프리뷰용)
    @State private var htmlContent: String = ""

    // 아웃라인 표시 여부
    @State private var showOutline: Bool = false

    // 현재 커서 라인 (아웃라인 하이라이트용)
    @State private var currentLine: Int = 0

    // 포커스 모드 표시 여부
    @State private var focusMode: Bool = false

    // Typewriter Mode 상태
    @State private var typewriterMode: Bool = false

    private let markdownProcessor = MarkdownProcessor()

    var body: some View {
        EditorPreviewSplitView(
            documentManager: documentManager,
            appState: appState,
            actionHandler: actionHandler,
            scrollSyncManager: scrollSyncManager,
            htmlContent: $htmlContent,
            onFileDrop: handleFileDrop,
            onImageDrop: handleImageDrop,
            onContentChange: { newContent in
                documentManager.updateContent(newContent)
                // 디바운스: 편집 중에는 프리뷰 업데이트 지연
                previewDebouncer.debounce {
                    updatePreview()
                }
                // 찾기 패널 열려있으면 매치 갱신
                if findReplaceManager.isVisible {
                    findReplaceManager.findAll()
                }
            },
            findReplaceManager: findReplaceManager,
            onCursorLineChange: { line in
                currentLine = line
            },
            showOutline: showOutline,
            currentLine: currentLine,
            onSelectHeading: { lineNumber in
                scrollToLine(lineNumber)
            },
            focusMode: focusMode,
            typewriterMode: typewriterMode
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleOutline"))) { _ in
            showOutline.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleFocusMode"))) { _ in
            focusMode.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleTypewriterMode"))) { _ in
            typewriterMode.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFindPanel"))) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                findReplaceManager.show(withReplace: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowReplacePanel"))) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                findReplaceManager.show(withReplace: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindNext"))) { _ in
            findReplaceManager.findNext()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindPrevious"))) { _ in
            findReplaceManager.findPrevious()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseFindPanel"))) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                findReplaceManager.close()
            }
        }
    }

    // MARK: - 프리뷰 업데이트

    private func updatePreview() {
        htmlContent = markdownProcessor.convertToHTML(documentManager.content)
    }

    // MARK: - 헤딩으로 스크롤

    private func scrollToLine(_ lineNumber: Int) {
        // EditorTextView의 스크롤 동기화 매니저를 통해 스크롤
        guard let scrollView = scrollSyncManager.editorScrollView,
              let textView = scrollView.documentView as? NSTextView else { return }

        let text = textView.string
        let lines = text.components(separatedBy: "\n")

        // 해당 라인의 문자 위치 계산
        var charIndex = 0
        for i in 0..<min(lineNumber, lines.count) {
            charIndex += lines[i].count + 1 // +1 for newline
        }

        // 해당 위치로 스크롤
        let range = NSRange(location: min(charIndex, text.count), length: 0)
        textView.scrollRangeToVisible(range)
        textView.setSelectedRange(range)
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

    // MARK: - 이미지 드롭 처리

    private func handleImageDrop(image: NSImage, suggestedName: String) -> String? {
        guard let fileURL = documentManager.currentFileURL else {
            // Untitled 문서면 먼저 저장 요청
            let alert = NSAlert()
            alert.messageText = "문서를 먼저 저장해주세요"
            alert.informativeText = "이미지를 삽입하려면 문서를 먼저 저장해야 합니다."
            alert.runModal()
            return nil
        }

        // 이미지 저장 디렉토리
        let imageDir = fileURL.deletingLastPathComponent().appendingPathComponent("images")
        try? FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)

        // 이미지를 PNG로 저장
        let imageURL = imageDir.appendingPathComponent(suggestedName)

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: imageURL)
            DebugLogger.shared.log("Saved image: \(imageURL.lastPathComponent)")
            return "images/\(suggestedName)"
        } catch {
            DebugLogger.shared.log("Image save failed: \(error)")
            return nil
        }
    }
}

#Preview {
    DocumentContentView(documentManager: DocumentManager())
}

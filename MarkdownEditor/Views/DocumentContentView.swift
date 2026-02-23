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
                DebugLogger.shared.log("[Outline] onCursorLineChange: \(line), previous currentLine: \(currentLine)")
                currentLine = line
            },
            showOutline: showOutline,
            currentLine: currentLine,
            onSelectHeading: { lineNumber, headingIndex in
                DebugLogger.shared.log("[Outline] === HEADING CLICKED === line:\(lineNumber), index:\(headingIndex), target:\(appState.outlineScrollTarget), currentLine(before):\(currentLine)")
                // 아웃라인 클릭 타임스탬프 기록 (프리뷰 smooth scroll 동안 스크롤 기반 덮어쓰기 방지)
                scrollSyncManager.lastOutlineClickTime = CACurrentMediaTime()
                moveCursorToLine(lineNumber)
                DebugLogger.shared.log("[Outline] after moveCursorToLine, currentLine:\(currentLine)")
                switch appState.outlineScrollTarget {
                case .editor:
                    scrollEditorToLine(lineNumber)
                case .preview:
                    scrollPreviewToHeading(headingIndex)
                }
                DebugLogger.shared.log("[Outline] after scroll, currentLine:\(currentLine)")
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

    // MARK: - 커서 이동 (스크롤 없이)
    // 에디터 커서만 해당 라인으로 이동 → textViewDidChangeSelection 발동
    // → currentLine 업데이트 + lastSelectionTime 설정 (scrollViewDidScroll 덮어쓰기 방지)
    private func moveCursorToLine(_ lineNumber: Int) {
        guard let scrollView = scrollSyncManager.editorScrollView,
              let textView = scrollView.documentView as? NSTextView else {
            DebugLogger.shared.log("[Outline] moveCursorToLine FAILED: no scrollView or textView")
            return
        }

        let nsText = textView.string as NSString
        let lines = textView.string.components(separatedBy: "\n")

        var charIndex = 0
        for i in 0..<min(lineNumber, lines.count) {
            charIndex += (lines[i] as NSString).length + 1
        }

        let location = min(charIndex, nsText.length)
        DebugLogger.shared.log("[Outline] moveCursorToLine(\(lineNumber)) → charIndex:\(charIndex), location:\(location), totalLength:\(nsText.length)")
        textView.setSelectedRange(NSRange(location: location, length: 0))
        DebugLogger.shared.log("[Outline] setSelectedRange done, actual selectedRange: \(textView.selectedRange())")
    }

    // MARK: - 에디터 헤딩으로 스크롤
    private func scrollEditorToLine(_ lineNumber: Int) {
        guard let scrollView = scrollSyncManager.editorScrollView,
              let textView = scrollView.documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let lines = textView.string.components(separatedBy: "\n")
        var charIndex = 0
        for i in 0..<min(lineNumber, lines.count) {
            charIndex += (lines[i] as NSString).length + 1
        }

        let nsText = textView.string as NSString
        let location = min(charIndex, nsText.length)
        let range = NSRange(location: location, length: 0)

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let targetY = lineRect.origin.y + textView.textContainerInset.height
        scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: - 프리뷰 헤딩으로 스크롤

    private func scrollPreviewToHeading(_ headingIndex: Int) {
        guard let webView = scrollSyncManager.previewWebView else { return }

        let js = """
        (function() {
            var headings = document.querySelectorAll('h1,h2,h3,h4,h5,h6');
            if (headings.length > \(headingIndex)) {
                headings[\(headingIndex)].scrollIntoView({behavior:'smooth', block:'start'});
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
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

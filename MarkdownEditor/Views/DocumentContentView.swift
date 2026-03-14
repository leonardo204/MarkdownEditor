import SwiftUI
import WebKit

enum MarkdownImageHelper {
    static func encodeImagePath(_ path: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "()")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }

    // HTML 내 로컬 이미지 src를 base64 data URI로 변환
    static func embedLocalImages(in html: String, documentURL: URL) -> String {
        let docDir = documentURL.deletingLastPathComponent()
        let pattern = #"<img\s+([^>]*?)src="([^"]+)"([^>]*?)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))
        guard !matches.isEmpty else { return html }

        // 원본에서 조각별로 조립 (인덱스 어긋남 방지)
        var result = ""
        var lastEnd = 0

        for match in matches {
            let fullRange = match.range(at: 0)
            let src = nsHTML.substring(with: match.range(at: 2))

            // 변환 불필요한 src는 원본 유지
            guard !src.hasPrefix("data:"), !src.hasPrefix("http://"), !src.hasPrefix("https://") else {
                result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location + fullRange.length - lastEnd))
                lastEnd = fullRange.location + fullRange.length
                continue
            }

            // 이미지 파일 URL 결정
            let imageURL: URL
            if src.hasPrefix("file://") {
                guard let url = URL(string: src) else {
                    result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location + fullRange.length - lastEnd))
                    lastEnd = fullRange.location + fullRange.length
                    continue
                }
                imageURL = url
            } else {
                let decoded = src.removingPercentEncoding ?? src
                imageURL = docDir.appendingPathComponent(decoded)
            }

            // 파일 읽기
            guard FileManager.default.fileExists(atPath: imageURL.path),
                  let data = try? Data(contentsOf: imageURL) else {
                result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location + fullRange.length - lastEnd))
                lastEnd = fullRange.location + fullRange.length
                continue
            }

            let ext = imageURL.pathExtension.lowercased()
            let mime: String
            switch ext {
            case "png": mime = "image/png"
            case "jpg", "jpeg": mime = "image/jpeg"
            case "gif": mime = "image/gif"
            case "svg": mime = "image/svg+xml"
            case "webp": mime = "image/webp"
            case "bmp": mime = "image/bmp"
            case "tiff", "tif": mime = "image/tiff"
            default: mime = "image/png"
            }

            let base64 = data.base64EncodedString()
            let dataURI = "data:\(mime);base64,\(base64)"

            // match 앞의 원본 텍스트 + 치환된 img 태그
            result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
            let beforeSrc = nsHTML.substring(with: match.range(at: 1))
            let afterSrc = nsHTML.substring(with: match.range(at: 3))
            result += "<img \(beforeSrc)src=\"\(dataURI)\"\(afterSrc)>"
            lastEnd = fullRange.location + fullRange.length
        }

        // 마지막 match 이후 나머지
        if lastEnd < nsHTML.length {
            result += nsHTML.substring(from: lastEnd)
        }

        return result
    }

    static func markdownImageSnippet(imageURL: URL, docDir: URL) -> String {
        let fileName = imageURL.deletingPathExtension().lastPathComponent
        let imagePath = imageURL.path
        let docPath = docDir.path
        if imagePath.hasPrefix(docPath + "/") {
            // 문서 디렉토리 내부 → 상대경로
            let relativePath = String(imagePath.dropFirst(docPath.count + 1))
            let encodedPath = encodeImagePath(relativePath)
            return "![\(fileName)](\(encodedPath))"
        } else {
            // 문서 디렉토리 외부 → file:// 절대 URL
            let fileURLString = imageURL.absoluteString
            return "![\(fileName)](\(fileURLString))"
        }
    }
}

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
            typewriterMode: typewriterMode,
            onInsertImageFromFile: handleInsertImageFromFile,
            onImageFilesDrop: handleImageFilesDrop
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleOutline"))) { n in
            guard isMyWindow(n) else { return }
            showOutline.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleFocusMode"))) { n in
            guard isMyWindow(n) else { return }
            focusMode.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleTypewriterMode"))) { n in
            guard isMyWindow(n) else { return }
            typewriterMode.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowFindPanel"))) { n in
            guard isMyWindow(n) else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                findReplaceManager.show(withReplace: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowReplacePanel"))) { n in
            guard isMyWindow(n) else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                findReplaceManager.show(withReplace: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindNext"))) { n in
            guard isMyWindow(n) else { return }
            findReplaceManager.findNext()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindPrevious"))) { n in
            guard isMyWindow(n) else { return }
            findReplaceManager.findPrevious()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseFindPanel"))) { n in
            guard isMyWindow(n) else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                findReplaceManager.close()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("InsertImageFromFile"))) { n in
            guard isMyWindow(n) else { return }
            handleInsertImageFromFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestSaveBeforeImage"))) { notification in
            handleSaveBeforeImageDrop(notification: notification)
        }
    }

    // MARK: - 윈도우 스코핑
    private func isMyWindow(_ notification: NotificationCenter.Publisher.Output) -> Bool {
        guard let senderWindow = notification.object as? NSWindow else { return true }
        guard let myWindow = actionHandler.textView?.window else { return false }
        return senderWindow === myWindow
    }

    // MARK: - 프리뷰 업데이트

    private func updatePreview() {
        var html = markdownProcessor.convertToHTML(documentManager.content)
        // 로컬 이미지를 base64 data URI로 인라인 (WKWebView 샌드박스 대응)
        if let docURL = documentManager.currentFileURL {
            html = MarkdownImageHelper.embedLocalImages(in: html, documentURL: docURL)
        }
        htmlContent = html
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

    // MARK: - 파일에서 이미지 삽입 (NSOpenPanel)

    private func handleInsertImageFromFile() {
        if documentManager.currentFileURL == nil {
            let alert = NSAlert()
            alert.messageText = "문서를 먼저 저장해주세요"
            alert.informativeText = "이미지를 삽입하려면 문서를 먼저 저장해야 합니다.\n확인을 누르면 저장 화면이 열립니다."
            alert.addButton(withTitle: "확인")
            alert.addButton(withTitle: "취소")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            documentManager.saveDocumentAs()
            guard documentManager.currentFileURL != nil else { return }
        }

        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.allowedContentTypes = [.png, .jpeg, .gif, .svg, .webP, .tiff, .bmp]
        openPanel.message = "삽입할 이미지를 선택하세요"

        // 문서 디렉토리를 기본 위치로
        if let docURL = documentManager.currentFileURL {
            openPanel.directoryURL = docURL.deletingLastPathComponent()
        }

        guard openPanel.runModal() == .OK, !openPanel.urls.isEmpty else { return }

        guard let textView = actionHandler.textView else { return }

        guard let docURL = documentManager.currentFileURL else { return }
        let docDir = docURL.deletingLastPathComponent()
        let markdownSnippets = openPanel.urls.map { MarkdownImageHelper.markdownImageSnippet(imageURL: $0, docDir: docDir) }

        let insertion = markdownSnippets.joined(separator: "\n") + "\n"
        let selectedRange = textView.selectedRange()

        if textView.shouldChangeText(in: selectedRange, replacementString: insertion) {
            textView.textStorage?.replaceCharacters(in: selectedRange, with: insertion)
            textView.didChangeText()
            let newPosition = selectedRange.location + (insertion as NSString).length
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }

        // 콘텐츠 변경 반영
        documentManager.updateContent(textView.string)
        previewDebouncer.debounce {
            updatePreview()
        }
    }

    // MARK: - 이미 존재하는 이미지 파일 드롭 처리 (저장 불필요)
    private func handleImageFilesDrop(_ imageURLs: [URL]) {
        if documentManager.currentFileURL == nil {
            // Untitled 문서면 notification으로 저장 유도
            NotificationCenter.default.post(
                name: NSNotification.Name("RequestSaveBeforeImage"),
                object: nil,
                userInfo: [
                    "textView": actionHandler.textView as Any,
                    "imageURLs": imageURLs
                ]
            )
            return
        }

        guard let textView = actionHandler.textView,
              let docURL = documentManager.currentFileURL else { return }

        let docDir = docURL.deletingLastPathComponent()
        let markdownSnippets = imageURLs.map { MarkdownImageHelper.markdownImageSnippet(imageURL: $0, docDir: docDir) }

        let insertion = markdownSnippets.joined(separator: "\n") + "\n"
        let selectedRange = textView.selectedRange()

        if textView.shouldChangeText(in: selectedRange, replacementString: insertion) {
            textView.textStorage?.replaceCharacters(in: selectedRange, with: insertion)
            textView.didChangeText()
            let newPosition = selectedRange.location + (insertion as NSString).length
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }

        documentManager.updateContent(textView.string)
        previewDebouncer.debounce { updatePreview() }
    }

    // MARK: - 미저장 문서 이미지 드롭 시 저장 유도
    private func handleSaveBeforeImageDrop(notification: NotificationCenter.Publisher.Output) {
        guard let userInfo = notification.userInfo,
              let sourceTextView = userInfo["textView"] as? NSTextView,
              sourceTextView === actionHandler.textView else { return }

        guard let imageURLs = userInfo["imageURLs"] as? [URL] else { return }

        let alert = NSAlert()
        alert.messageText = "문서를 먼저 저장해주세요"
        alert.informativeText = "이미지를 삽입하려면 문서를 먼저 저장해야 합니다.\n확인을 누르면 저장 화면이 열립니다."
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "취소")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        documentManager.saveDocumentAs()
        guard let docURL = documentManager.currentFileURL,
              let textView = actionHandler.textView else { return }

        let docDir = docURL.deletingLastPathComponent()
        let markdownSnippets = imageURLs.map { MarkdownImageHelper.markdownImageSnippet(imageURL: $0, docDir: docDir) }

        let insertion = markdownSnippets.joined(separator: "\n") + "\n"
        let selectedRange = textView.selectedRange()
        if textView.shouldChangeText(in: selectedRange, replacementString: insertion) {
            textView.textStorage?.replaceCharacters(in: selectedRange, with: insertion)
            textView.didChangeText()
            let newPosition = selectedRange.location + (insertion as NSString).length
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }
        documentManager.updateContent(textView.string)
        previewDebouncer.debounce { updatePreview() }
    }

    // MARK: - 이미지 드롭 처리

    private func handleImageDrop(image: NSImage, suggestedName: String) -> String? {
        if documentManager.currentFileURL == nil {
            let alert = NSAlert()
            alert.messageText = "문서를 먼저 저장해주세요"
            alert.informativeText = "이미지를 삽입하려면 문서를 먼저 저장해야 합니다.\n확인을 누르면 저장 화면이 열립니다."
            alert.addButton(withTitle: "확인")
            alert.addButton(withTitle: "취소")
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            documentManager.saveDocumentAs()
            guard documentManager.currentFileURL != nil else { return nil }
        }

        // PNG 데이터 생성
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            DebugLogger.shared.log("[ImageDrop] Image data conversion failed")
            return nil
        }

        // NSSavePanel로 사용자에게 저장 위치 선택 (Sandbox 권한 자동 획득)
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = suggestedName
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true

        // 문서 디렉토리의 images/ 폴더를 기본 위치로 제안
        if let docURL = documentManager.currentFileURL {
            let imageDir = docURL.deletingLastPathComponent().appendingPathComponent("images")
            savePanel.directoryURL = imageDir
        }

        guard savePanel.runModal() == .OK, let savedURL = savePanel.url else {
            return nil
        }

        do {
            try pngData.write(to: savedURL)
            DebugLogger.shared.log("[ImageDrop] Saved image: \(savedURL.path)")

            // 문서 기준 상대 경로 계산
            if let docURL = documentManager.currentFileURL {
                let docDir = docURL.deletingLastPathComponent()
                let imagePath = savedURL.path
                let docPath = docDir.path

                if imagePath.hasPrefix(docPath + "/") {
                    let relativePath = String(imagePath.dropFirst(docPath.count + 1))
                    return relativePath
                }
            }

            // 상대 경로 계산 실패 시 절대 경로
            return savedURL.path
        } catch {
            DebugLogger.shared.log("[ImageDrop] Image save failed: \(error)")
            return nil
        }
    }
}

#Preview {
    DocumentContentView(documentManager: DocumentManager())
}

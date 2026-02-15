import SwiftUI
import AppKit

// 마크다운 에디터 뷰
// NSTextView 기반 + 텍스트 선택 포맷팅 지원

// MARK: - 에디터 액션 핸들러
class EditorActionHandler: ObservableObject {
    weak var textView: NSTextView?

    // 선택된 텍스트에 포맷팅 적용
    func applyFormatting(_ action: MarkdownAction) {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return }

        let selectedRange = textView.selectedRange()
        let selectedText = (textStorage.string as NSString).substring(with: selectedRange)

        let replacement: String
        if selectedRange.length > 0 {
            // 선택된 텍스트가 있으면 포맷팅 적용
            replacement = formatText(selectedText, with: action)
        } else {
            // 선택된 텍스트가 없으면 샘플 텍스트 삽입
            replacement = action.insertText
        }

        // 텍스트 교체
        if textView.shouldChangeText(in: selectedRange, replacementString: replacement) {
            textStorage.replaceCharacters(in: selectedRange, with: replacement)
            textView.didChangeText()

            // 커서 위치 조정
            let newPosition = selectedRange.location + replacement.count
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }
    }

    private func formatText(_ text: String, with action: MarkdownAction) -> String {
        switch action {
        case .heading(let level):
            return String(repeating: "#", count: level) + " " + text
        case .bold:
            return "**\(text)**"
        case .italic:
            return "*\(text)*"
        case .strikethrough:
            return "~~\(text)~~"
        case .highlight:
            return "==\(text)=="
        case .inlineCode:
            return "`\(text)`"
        case .codeBlock:
            return "```\n\(text)\n```"
        case .link:
            return "[\(text)](url)"
        case .image:
            return "![\(text)](image-url)"
        case .bulletList:
            return text.components(separatedBy: "\n").map { "- \($0)" }.joined(separator: "\n")
        case .numberedList:
            return text.components(separatedBy: "\n").enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        case .taskList:
            return text.components(separatedBy: "\n").map { "- [ ] \($0)" }.joined(separator: "\n")
        case .blockquote:
            return text.components(separatedBy: "\n").map { "> \($0)" }.joined(separator: "\n")
        case .inlineMath:
            return "$\(text)$"
        case .blockMath:
            return "$$\n\(text)\n$$"
        case .mermaid:
            // 선택된 텍스트를 mermaid 코드 블록으로 감싸기
            return "```mermaid\n\(text)\n```"
        case .plantuml:
            // 선택된 텍스트를 plantuml 코드 블록으로 감싸기
            return "```plantuml\n\(text)\n```"
        default:
            return action.insertText
        }
    }
}

// MARK: - SimpleEditorView
struct SimpleEditorView: View {
    @Binding var content: String
    var theme: EditorTheme
    var fontSize: CGFloat
    var showLineNumbers: Bool = true
    var onFileDrop: (([URL]) -> Void)?
    var onImageDrop: ((NSImage, String) -> String?)?
    var actionHandler: EditorActionHandler?
    var onContentChange: ((String) -> Void)?
    var scrollSyncManager: ScrollSyncManager?
    var findReplaceManager: FindReplaceManager?
    var onCursorLineChange: ((Int) -> Void)?
    var focusMode: Bool = false
    var typewriterMode: Bool = false

    @State private var lineCount: Int = 1

    var body: some View {
        HStack(spacing: 0) {
            // 라인 번호 영역
            if showLineNumbers {
                LineNumberView(
                    lineCount: lineCount,
                    theme: theme,
                    fontSize: fontSize
                )
            }

            // NSTextView 기반 에디터
            MarkdownNSTextView(
                content: $content,
                theme: theme,
                fontSize: fontSize,
                lineCount: $lineCount,
                onFileDrop: onFileDrop,
                actionHandler: actionHandler,
                onContentChange: onContentChange,
                scrollSyncManager: scrollSyncManager,
                findReplaceManager: findReplaceManager,
                onCursorLineChange: onCursorLineChange,
                focusMode: focusMode,
                typewriterMode: typewriterMode
            )
        }
        .background(Color(theme.backgroundColor))
        .onAppear {
            updateLineCount(content)
        }
    }

    private func updateLineCount(_ text: String) {
        lineCount = max(1, text.components(separatedBy: "\n").count)
    }
}

// MARK: - NSTextView 래퍼
struct MarkdownNSTextView: NSViewRepresentable {
    @Binding var content: String
    var theme: EditorTheme
    var fontSize: CGFloat
    @Binding var lineCount: Int
    var onFileDrop: (([URL]) -> Void)?
    var actionHandler: EditorActionHandler?
    var onContentChange: ((String) -> Void)?
    var scrollSyncManager: ScrollSyncManager?
    var findReplaceManager: FindReplaceManager?
    var onCursorLineChange: ((Int) -> Void)?
    var focusMode: Bool = false
    var typewriterMode: Bool = false

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = theme.backgroundColor

        // 텍스트 뷰 생성
        let textView = EditorTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = false
        textView.isIncrementalSearchingEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.onFileDrop = onFileDrop
        textView.focusModeEnabled = focusMode
        textView.typewriterModeEnabled = typewriterMode

        // 텍스트 뷰 크기 설정
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // 텍스트 컨테이너 설정
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // 스크롤 뷰에 텍스트 뷰 설정
        scrollView.documentView = textView

        // 초기 내용 및 스타일 설정
        textView.string = content
        applyTheme(to: textView)

        // 액션 핸들러 연결
        actionHandler?.textView = textView

        // 찾기/바꾸기 매니저에 텍스트뷰 연결
        findReplaceManager?.textView = textView

        // 커서 라인 콜백 연결
        context.coordinator.onCursorLineChange = onCursorLineChange

        // 스크롤 동기화 매니저에 등록
        scrollSyncManager?.editorScrollView = scrollView

        // 스크롤 이벤트 감지
        context.coordinator.scrollSyncManager = scrollSyncManager
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }

        // 텍스트 뷰 크기 조정
        let contentSize = scrollView.contentSize
        textView.frame.size.width = contentSize.width
        textView.textContainer?.containerSize = NSSize(width: contentSize.width - 16, height: CGFloat.greatestFiniteMagnitude)

        // 내용 업데이트 (변경된 경우에만)
        if textView.string != content && !context.coordinator.isUpdating {
            let selectedRanges = textView.selectedRanges
            textView.string = content
            textView.selectedRanges = selectedRanges
        }

        // 테마 업데이트
        applyTheme(to: textView)
        scrollView.backgroundColor = theme.backgroundColor

        // 파일 드롭 핸들러 업데이트
        textView.onFileDrop = onFileDrop
        textView.focusModeEnabled = focusMode
        textView.typewriterModeEnabled = typewriterMode

        // 액션 핸들러 업데이트
        actionHandler?.textView = textView

        // 콘텐츠 변경 콜백 업데이트
        context.coordinator.onContentChange = onContentChange
        context.coordinator.onCursorLineChange = onCursorLineChange

        // 찾기/바꾸기 매니저 업데이트
        findReplaceManager?.textView = textView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content, lineCount: $lineCount, onContentChange: onContentChange)
    }

    private func applyTheme(to textView: NSTextView) {
        textView.backgroundColor = theme.backgroundColor
        textView.insertionPointColor = theme.cursorColor
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selectionColor
        ]

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.textColor = theme.textColor
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, NSTextViewDelegate {
        var content: Binding<String>
        var lineCount: Binding<Int>
        var onContentChange: ((String) -> Void)?
        var onCursorLineChange: ((Int) -> Void)?
        var scrollSyncManager: ScrollSyncManager?
        var isUpdating = false

        init(content: Binding<String>, lineCount: Binding<Int>, onContentChange: ((String) -> Void)?) {
            self.content = content
            self.lineCount = lineCount
            self.onContentChange = onContentChange
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // 커서 이동 시 현재 라인 번호 계산 및 포커스/타자기 모드 처리
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? EditorTextView else { return }

            // 현재 라인 번호 계산
            let text = textView.string
            let cursorPosition = textView.selectedRange().location
            let textUpToCursor = (text as NSString).substring(to: min(cursorPosition, text.count))
            let currentLine = textUpToCursor.components(separatedBy: "\n").count - 1  // 0-based
            onCursorLineChange?(currentLine)

            // 포커스 모드 / 타자기 모드
            if textView.focusModeEnabled {
                textView.applyFocusMode()
            }
            if textView.typewriterModeEnabled {
                textView.centerCurrentLine()
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }

            isUpdating = true
            let newText = textView.string
            content.wrappedValue = newText
            lineCount.wrappedValue = max(1, newText.components(separatedBy: "\n").count)

            // 콘텐츠 변경 콜백 호출
            onContentChange?(newText)

            isUpdating = false
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            scrollSyncManager?.editorDidScroll()

            // 스크롤 시 보이는 첫 줄 기준으로 아웃라인 업데이트
            guard let clipView = notification.object as? NSClipView,
                  let textView = clipView.documentView as? NSTextView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let visibleRect = clipView.documentVisibleRect
            let topPoint = NSPoint(x: 0, y: visibleRect.origin.y + textView.textContainerInset.height)
            let glyphIndex = layoutManager.glyphIndex(for: topPoint, in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            let text = textView.string
            let textUpToVisible = (text as NSString).substring(to: min(charIndex, text.count))
            let visibleLine = textUpToVisible.components(separatedBy: "\n").count - 1
            onCursorLineChange?(visibleLine)
        }
    }
}

// MARK: - 에디터 텍스트 뷰 (드래그 앤 드롭 지원)
class EditorTextView: NSTextView {
    var onFileDrop: (([URL]) -> Void)?
    var onImageDrop: ((NSImage, String) -> String?)?  // image, suggested name -> saved relative path
    var focusModeEnabled: Bool = false {
        didSet {
            if focusModeEnabled {
                applyFocusMode()
            } else {
                removeFocusMode()
            }
        }
    }
    var typewriterModeEnabled: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    func applyFocusMode() {
        guard let textStorage = textStorage, let _ = layoutManager else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)

        // Find the current paragraph range
        let cursorLocation = selectedRange().location
        let paragraphRange = (string as NSString).paragraphRange(for: NSRange(location: min(cursorLocation, string.count), length: 0))

        // Dim all text
        textStorage.addAttribute(.foregroundColor, value: (textColor ?? .white).withAlphaComponent(0.3), range: fullRange)

        // Highlight current paragraph
        if let color = textColor {
            textStorage.addAttribute(.foregroundColor, value: color, range: paragraphRange)
        }
    }

    private func removeFocusMode() {
        guard let textStorage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        if let color = textColor {
            textStorage.addAttribute(.foregroundColor, value: color, range: fullRange)
        }
    }

    func centerCurrentLine() {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let scrollView = enclosingScrollView else { return }

        let cursorRange = selectedRange()
        let glyphRange = layoutManager.glyphRange(forCharacterRange: cursorRange, actualCharacterRange: nil)
        let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        let visibleHeight = scrollView.contentView.bounds.height
        let targetY = lineRect.midY - visibleHeight / 2 + textContainerInset.height
        let maxY = frame.height - visibleHeight
        let clampedY = max(0, min(targetY, maxY))

        scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: clampedY))
    }

    override func keyDown(with event: NSEvent) {
        // Escape: 찾기 패널 닫기
        if event.keyCode == 53 {
            NotificationCenter.default.post(name: NSNotification.Name("CloseFindPanel"), object: nil)
            return
        }
        // Tab 키 처리 (스페이스 4개로 변환)
        if event.keyCode == 48 {
            insertText("    ", replacementRange: selectedRange())
            return
        }
        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        // 이미지 파일 드롭
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            let imageExts = ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff"]
            let textExts = ["md", "markdown", "txt", "text"]
            let allExts = imageExts + textExts
            if urls.contains(where: { allExts.contains($0.pathExtension.lowercased()) }) {
                return .copy
            }
        }
        // 클립보드 이미지
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            // 텍스트 파일 드롭
            let textExtensions = ["md", "markdown", "txt", "text"]
            let textURLs = urls.filter { textExtensions.contains($0.pathExtension.lowercased()) }
            if !textURLs.isEmpty {
                onFileDrop?(textURLs)
                return true
            }

            // 이미지 파일 드롭
            let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff"]
            let imageURLs = urls.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            if !imageURLs.isEmpty {
                for imageURL in imageURLs {
                    if let image = NSImage(contentsOf: imageURL) {
                        let name = imageURL.lastPathComponent
                        if let relativePath = onImageDrop?(image, name) {
                            let markdown = "![\(imageURL.deletingPathExtension().lastPathComponent)](\(relativePath))"
                            insertText(markdown, replacementRange: selectedRange())
                        }
                    }
                }
                return true
            }
        }

        // 클립보드 이미지 (스크린샷 붙여넣기 등)
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let image = images.first {
            let timestamp = Int(Date().timeIntervalSince1970)
            let name = "pasted-image-\(timestamp).png"
            if let relativePath = onImageDrop?(image, name) {
                let markdown = "![pasted image](\(relativePath))"
                insertText(markdown, replacementRange: selectedRange())
            }
            return true
        }

        return super.performDragOperation(sender)
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        // 클립보드에 이미지가 있는 경우
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil),
           let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            let timestamp = Int(Date().timeIntervalSince1970)
            let name = "pasted-image-\(timestamp).png"
            if let relativePath = onImageDrop?(image, name) {
                let markdown = "![pasted image](\(relativePath))"
                insertText(markdown, replacementRange: selectedRange())
                return
            }
        }

        // 기본 붙여넣기
        super.paste(sender)
    }
}

// MARK: - 라인 번호 뷰
struct LineNumberView: View {
    let lineCount: Int
    let theme: EditorTheme
    let fontSize: CGFloat

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...max(1, lineCount), id: \.self) { number in
                    Text("\(number)")
                        .font(.system(size: fontSize * 0.85, design: .monospaced))
                        .foregroundColor(Color(theme.lineNumberColor))
                        .frame(height: fontSize * 1.35)
                }
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
            .padding(.leading, 4)
        }
        .frame(width: 44)
        .background(Color(theme.gutterBackgroundColor))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(theme.gutterBorderColor)),
            alignment: .trailing
        )
    }
}

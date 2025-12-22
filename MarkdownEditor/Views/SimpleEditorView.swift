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
    var actionHandler: EditorActionHandler?
    var onContentChange: ((String) -> Void)?
    var scrollSyncManager: ScrollSyncManager?

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
                scrollSyncManager: scrollSyncManager
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
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.onFileDrop = onFileDrop

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

        // 액션 핸들러 업데이트
        actionHandler?.textView = textView

        // 콘텐츠 변경 콜백 업데이트
        context.coordinator.onContentChange = onContentChange
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
        var scrollSyncManager: ScrollSyncManager?
        var isUpdating = false

        init(content: Binding<String>, lineCount: Binding<Int>, onContentChange: ((String) -> Void)?) {
            self.content = content
            self.lineCount = lineCount
            self.onContentChange = onContentChange
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
        }
    }
}

// MARK: - 에디터 텍스트 뷰 (드래그 앤 드롭 지원)
class EditorTextView: NSTextView {
    var onFileDrop: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func keyDown(with event: NSEvent) {
        // Tab 키 처리 (스페이스 4개로 변환)
        if event.keyCode == 48 {
            insertText("    ", replacementRange: selectedRange())
            return
        }
        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            // 지원하는 파일 확장자만 필터링
            let supportedExtensions = ["md", "markdown", "txt", "text"]
            let validURLs = urls.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }

            if !validURLs.isEmpty {
                onFileDrop?(validURLs)
                return true
            }
        }

        return super.performDragOperation(sender)
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

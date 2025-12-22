import SwiftUI
import AppKit

// NSTextView를 래핑한 Markdown 에디터 뷰
// 라인 번호, 구문 강조를 지원합니다.

struct EditorView: NSViewRepresentable {
    @Binding var content: String
    var theme: EditorTheme
    var fontSize: CGFloat
    var showLineNumbers: Bool
    var onTextChange: ((String) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // 텍스트 컨테이너 설정
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        // 기본 스타일 설정
        textView.textContainerInset = NSSize(width: 8, height: 12)

        // 라인 번호 뷰 설정
        let lineNumberView = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = lineNumberView
        scrollView.hasVerticalRuler = showLineNumbers
        scrollView.rulersVisible = showLineNumbers

        scrollView.documentView = textView

        // 초기 내용 설정
        textView.string = content
        applyTheme(to: textView, theme: theme, fontSize: fontSize)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }

        // 내용 업데이트 (변경된 경우에만)
        if textView.string != content {
            let selectedRanges = textView.selectedRanges
            textView.string = content
            textView.selectedRanges = selectedRanges
        }

        // 테마 및 스타일 업데이트
        applyTheme(to: textView, theme: theme, fontSize: fontSize)

        // 라인 번호 표시 설정
        scrollView.hasVerticalRuler = showLineNumbers
        scrollView.rulersVisible = showLineNumbers

        // 구문 강조 적용
        context.coordinator.applySyntaxHighlighting(to: textView, theme: theme)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyTheme(to textView: NSTextView, theme: EditorTheme, fontSize: CGFloat) {
        textView.backgroundColor = theme.backgroundColor
        textView.insertionPointColor = theme.cursorColor
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selectionColor
        ]

        // 폰트 설정
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.textColor = theme.textColor

        // 라인 번호 뷰 업데이트
        if let rulerView = textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView {
            rulerView.updateTheme(theme)
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        private var isUpdating = false

        init(_ parent: EditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let textView = notification.object as? NSTextView else { return }

            isUpdating = true
            parent.content = textView.string
            parent.onTextChange?(textView.string)

            // 구문 강조 적용
            applySyntaxHighlighting(to: textView, theme: parent.theme)

            isUpdating = false
        }

        func applySyntaxHighlighting(to textView: NSTextView, theme: EditorTheme) {
            guard let textStorage = textView.textStorage else { return }

            let text = textView.string
            let fullRange = NSRange(location: 0, length: text.utf16.count)

            // 기본 색상 적용
            textStorage.addAttribute(.foregroundColor, value: theme.textColor, range: fullRange)

            // 구문 강조 패턴 적용
            let highlighter = SyntaxHighlighter(theme: theme)
            highlighter.highlight(textStorage)
        }
    }
}

// MARK: - 커스텀 NSTextView
class MarkdownTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        // Tab 키 처리 (스페이스 4개로 변환)
        if event.keyCode == 48 { // Tab
            insertText("    ", replacementRange: selectedRange())
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - 라인 번호 뷰
class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private var theme: EditorTheme = .dark

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.ruleThickness = 44
        self.clientView = textView

        // 텍스트 변경 알림 구독
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    func updateTheme(_ theme: EditorTheme) {
        self.theme = theme
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // 배경 그리기
        theme.backgroundColor.setFill()
        rect.fill()

        // 구분선 그리기
        let separatorColor = theme.lineNumberColor.withAlphaComponent(0.3)
        separatorColor.setStroke()
        let separatorPath = NSBezierPath()
        separatorPath.move(to: NSPoint(x: ruleThickness - 1, y: rect.minY))
        separatorPath.line(to: NSPoint(x: ruleThickness - 1, y: rect.maxY))
        separatorPath.lineWidth = 1
        separatorPath.stroke()

        // 폰트 및 속성 설정
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.lineNumberColor
        ]

        // 텍스트 뷰의 보이는 영역 계산
        let visibleRect = textView.visibleRect
        let textContainerInset = textView.textContainerInset

        // 텍스트의 전체 범위
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        // 라인 번호 그리기
        var lineNumber = 1
        var glyphIndex = 0
        let textString = textView.string as NSString

        // 보이는 영역 이전의 라인 수 계산
        if glyphRange.location > 0 {
            let precedingRange = NSRange(location: 0, length: glyphRange.location)
            let precedingString = textString.substring(with: precedingRange)
            lineNumber = precedingString.components(separatedBy: "\n").count
        }

        var currentIndex = glyphRange.location
        while currentIndex < NSMaxRange(glyphRange) {
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: currentIndex, effectiveRange: &lineRange)

            // 라인 번호 문자열
            let lineNumberString = "\(lineNumber)"
            let stringSize = lineNumberString.size(withAttributes: attributes)

            // 라인 번호 위치 계산 (오른쪽 정렬)
            let x = ruleThickness - stringSize.width - 8
            let y = lineRect.origin.y + textContainerInset.height - visibleRect.origin.y + (lineRect.height - stringSize.height) / 2

            // 보이는 영역 내에서만 그리기
            if y >= -stringSize.height && y <= rect.height + stringSize.height {
                lineNumberString.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
            }

            // 다음 라인으로
            currentIndex = NSMaxRange(lineRange)
            lineNumber += 1
        }
    }
}

// MARK: - 구문 강조
class SyntaxHighlighter {
    let theme: EditorTheme

    init(theme: EditorTheme) {
        self.theme = theme
    }

    func highlight(_ textStorage: NSTextStorage) {
        let text = textStorage.string
        let fullRange = NSRange(location: 0, length: text.utf16.count)

        // 헤딩 (#, ##, ###, ...)
        applyPattern("^#{1,6}\\s.*$", color: headingColor, to: textStorage, in: text)

        // Bold (**text** 또는 __text__)
        applyPattern("\\*\\*[^*]+\\*\\*|__[^_]+__", color: boldColor, to: textStorage, in: text)

        // Italic (*text* 또는 _text_)
        applyPattern("(?<![*_])\\*[^*]+\\*(?![*])|(?<![*_])_[^_]+_(?![_])", color: italicColor, to: textStorage, in: text)

        // 인라인 코드 (`code`)
        applyPattern("`[^`]+`", color: codeColor, to: textStorage, in: text)

        // 코드 블록 (```...```)
        applyPattern("```[\\s\\S]*?```", color: codeColor, to: textStorage, in: text)

        // 링크 ([text](url))
        applyPattern("\\[([^\\]]+)\\]\\(([^\\)]+)\\)", color: linkColor, to: textStorage, in: text)

        // 이미지 (![alt](url))
        applyPattern("!\\[([^\\]]+)\\]\\(([^\\)]+)\\)", color: linkColor, to: textStorage, in: text)

        // 인용구 (> text)
        applyPattern("^>\\s.*$", color: blockquoteColor, to: textStorage, in: text)

        // 리스트 마커 (-, *, +, 1.)
        applyPattern("^\\s*[-*+]\\s|^\\s*\\d+\\.\\s", color: listMarkerColor, to: textStorage, in: text)

        // 체크박스 (- [ ] 또는 - [x])
        applyPattern("^\\s*[-*+]\\s\\[[ xX]\\]", color: listMarkerColor, to: textStorage, in: text)

        // 수평선 (---, ***, ___)
        applyPattern("^[-*_]{3,}\\s*$", color: hrColor, to: textStorage, in: text)
    }

    private func applyPattern(_ pattern: String, color: NSColor, to textStorage: NSTextStorage, in text: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }

        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: range)

        for match in matches {
            textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }

    // MARK: - 테마 색상
    private var headingColor: NSColor {
        theme == .dark ? NSColor(red: 0.380, green: 0.686, blue: 0.937, alpha: 1.0) : NSColor(red: 0.251, green: 0.471, blue: 0.949, alpha: 1.0)
    }

    private var boldColor: NSColor {
        theme == .dark ? NSColor(red: 0.898, green: 0.753, blue: 0.482, alpha: 1.0) : NSColor(red: 0.596, green: 0.408, blue: 0.004, alpha: 1.0)
    }

    private var italicColor: NSColor {
        theme == .dark ? NSColor(red: 0.773, green: 0.525, blue: 0.773, alpha: 1.0) : NSColor(red: 0.651, green: 0.149, blue: 0.643, alpha: 1.0)
    }

    private var codeColor: NSColor {
        theme == .dark ? NSColor(red: 0.596, green: 0.765, blue: 0.478, alpha: 1.0) : NSColor(red: 0.314, green: 0.631, blue: 0.310, alpha: 1.0)
    }

    private var linkColor: NSColor {
        theme == .dark ? NSColor(red: 0.337, green: 0.714, blue: 0.761, alpha: 1.0) : NSColor(red: 0.004, green: 0.522, blue: 0.737, alpha: 1.0)
    }

    private var blockquoteColor: NSColor {
        theme == .dark ? NSColor(red: 0.361, green: 0.388, blue: 0.443, alpha: 1.0) : NSColor(red: 0.627, green: 0.631, blue: 0.655, alpha: 1.0)
    }

    private var listMarkerColor: NSColor {
        theme == .dark ? NSColor(red: 0.878, green: 0.424, blue: 0.451, alpha: 1.0) : NSColor(red: 0.894, green: 0.337, blue: 0.286, alpha: 1.0)
    }

    private var hrColor: NSColor {
        theme == .dark ? NSColor(red: 0.500, green: 0.500, blue: 0.500, alpha: 1.0) : NSColor(red: 0.600, green: 0.600, blue: 0.600, alpha: 1.0)
    }
}

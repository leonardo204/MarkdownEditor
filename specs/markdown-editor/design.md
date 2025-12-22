# 설계 문서

## 개요

이 문서는 macOS용 네이티브 Markdown 에디터 애플리케이션의 기술 설계를 정의합니다. SwiftUI와 Swift로 작성되며, 확장된 Markdown(CommonMark + GFM + 추가 확장)을 지원하고 Mermaid 다이어그램 렌더링, 파일 Drag & Drop, DMG 배포 및 Apple 공증을 포함합니다.

### 기술 스택

| 구성 요소 | 기술 선택 | 근거 |
|-----------|-----------|------|
| UI 프레임워크 | SwiftUI | macOS 네이티브, 선언적 UI |
| Markdown 파싱 | swift-markdown (Apple) | GFM 지원, cmark-gfm 기반, 공식 지원 |
| 미리보기 렌더링 | WKWebView | JavaScript 라이브러리 활용 가능 |
| 수식 렌더링 | KaTeX (JavaScript) | 빠른 렌더링, 경량 |
| Mermaid 렌더링 | Mermaid.js | 표준 다이어그램 라이브러리, 클라이언트 사이드 |
| PlantUML 렌더링 | PlantUML 공식 서버 API | 로컬 설치 불필요, 경량 |
| 코드 구문 강조 | Highlight.js | 다양한 언어 지원 |
| DMG 생성 | create-dmg | 자동화된 DMG 생성 |
| 공증 | notarytool | Apple 공식 도구 |

### 성능 최적화 전략

| 전략 | 설명 | 적용 대상 |
|------|------|-----------|
| Debouncing | 입력 후 300ms 대기 후 렌더링 | 미리보기 갱신 |
| Background Processing | 메인 스레드 외 처리 | Markdown 파싱, HTML 변환 |
| Caching | 렌더링 결과 캐싱 (SHA256 해시 키) | 다이어그램, 수식 |
| Lazy Loading | 화면에 보이는 영역만 렌더링 | 긴 문서 |
| Incremental Update | 변경된 블록만 업데이트 | 미리보기 DOM |
| Async/Await | 비동기 네트워크 요청 | PlantUML API 호출 |

## 아키텍처

### 전체 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────┐
│                        MarkdownEditor App                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Presentation Layer                     │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │    │
│  │  │  MainView   │  │  Toolbar    │  │  PreferencesView│  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  │    │
│  │  ┌─────────────────────────────────────────────────┐    │    │
│  │  │              SplitView                           │    │    │
│  │  │  ┌─────────────────┐  ┌─────────────────────┐   │    │    │
│  │  │  │  EditorView     │  │  PreviewView        │   │    │    │
│  │  │  │  (NSTextView)   │  │  (WKWebView)        │   │    │    │
│  │  │  └─────────────────┘  └─────────────────────┘   │    │    │
│  │  └─────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Business Logic Layer                   │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │    │
│  │  │ Document    │  │ Markdown    │  │ Theme           │  │    │
│  │  │ Manager     │  │ Processor   │  │ Manager         │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │    │
│  │  │ Export      │  │ Formatting  │  │ Settings        │  │    │
│  │  │ Service     │  │ Service     │  │ Manager         │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Data Layer                             │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │    │
│  │  │ FileManager │  │ UserDefaults│  │ HTML Templates  │  │    │
│  │  │ (File I/O)  │  │ (Settings)  │  │ (Resources)     │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### MVVM 패턴

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│     View       │────▶│   ViewModel    │────▶│     Model      │
│   (SwiftUI)    │◀────│  (@Observable) │◀────│   (Data)       │
└────────────────┘     └────────────────┘     └────────────────┘
      │                       │                      │
      │ User Actions          │ State Updates        │ Data
      │                       │                      │
```

## 컴포넌트 및 인터페이스

### 1. 앱 진입점

```swift
// MarkdownEditorApp.swift
@main
struct MarkdownEditorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) { /* 파일 메뉴 커맨드 */ }
            ToolbarCommands()
            TextEditingCommands()
        }

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}
```

### 2. 문서 모델

```swift
// MarkdownDocument.swift
struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }

    var content: String
    var metadata: DocumentMetadata

    init(content: String = "") {
        self.content = content
        self.metadata = DocumentMetadata()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
        metadata = DocumentMetadata()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

struct DocumentMetadata {
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var wordCount: Int = 0
    var characterCount: Int = 0
}
```

### 3. 메인 콘텐츠 뷰

```swift
// ContentView.swift
struct ContentView: View {
    @Binding var document: MarkdownDocument
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: EditorViewModel

    var body: some View {
        HSplitView {
            // 에디터 패널
            EditorView(
                content: $document.content,
                theme: appState.editorTheme
            )
            .frame(minWidth: 300)

            // 미리보기 패널
            PreviewContainerView(
                content: document.content,
                theme: appState.previewTheme,
                mode: appState.previewMode
            )
            .frame(minWidth: 300)
        }
        .toolbar { ToolbarContent() }
        .onDrop(of: [.fileURL], delegate: FileDropDelegate(document: $document))
    }
}
```

### 4. 에디터 뷰 (NSTextView 래퍼)

```swift
// EditorView.swift
struct EditorView: NSViewRepresentable {
    @Binding var content: String
    var theme: EditorTheme
    var onTextChange: ((String) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = MarkdownTextView()

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 16, height: 16)

        // 라인 번호 뷰 설정
        let lineNumberView = LineNumberView(textView: textView)
        scrollView.verticalRulerView = lineNumberView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }
        if textView.string != content {
            textView.string = content
        }
        textView.applyTheme(theme)
        textView.applySyntaxHighlighting()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
```

### 5. 라인 번호 뷰

```swift
// LineNumberView.swift
class LineNumberView: NSRulerView {
    weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.ruleThickness = 40
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // 라인 번호 렌더링 로직
        let visibleRect = textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        var lineNumber = 1
        var glyphIndex = 0

        while glyphIndex < NSMaxRange(visibleGlyphRange) {
            var effectiveRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)

            // 라인 번호 그리기
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let string = "\(lineNumber)"
            string.draw(at: NSPoint(x: ruleThickness - 8 - string.size(withAttributes: attributes).width,
                                    y: lineRect.origin.y + textView.textContainerInset.height - visibleRect.origin.y),
                       withAttributes: attributes)

            lineNumber += 1
            glyphIndex = NSMaxRange(effectiveRange)
        }
    }
}
```

### 6. Markdown 구문 강조

```swift
// SyntaxHighlighter.swift
class SyntaxHighlighter {
    struct Theme {
        var heading: NSColor
        var bold: NSColor
        var italic: NSColor
        var code: NSColor
        var link: NSColor
        var blockquote: NSColor
        var listMarker: NSColor
        var background: NSColor
        var text: NSColor
    }

    static let darkTheme = Theme(
        heading: NSColor(hex: "#61AFEF"),
        bold: NSColor(hex: "#E5C07B"),
        italic: NSColor(hex: "#C678DD"),
        code: NSColor(hex: "#98C379"),
        link: NSColor(hex: "#56B6C2"),
        blockquote: NSColor(hex: "#5C6370"),
        listMarker: NSColor(hex: "#E06C75"),
        background: NSColor(hex: "#282C34"),
        text: NSColor(hex: "#ABB2BF")
    )

    static let lightTheme = Theme(
        heading: NSColor(hex: "#4078F2"),
        bold: NSColor(hex: "#986801"),
        italic: NSColor(hex: "#A626A4"),
        code: NSColor(hex: "#50A14F"),
        link: NSColor(hex: "#0184BC"),
        blockquote: NSColor(hex: "#A0A1A7"),
        listMarker: NSColor(hex: "#E45649"),
        background: NSColor(hex: "#FAFAFA"),
        text: NSColor(hex: "#383A42")
    )

    // 패턴 정의
    private let patterns: [(pattern: String, style: HighlightStyle)] = [
        // 헤딩
        ("^#{1,6}\\s.*$", .heading),
        // Bold
        ("\\*\\*[^*]+\\*\\*|__[^_]+__", .bold),
        // Italic
        ("\\*[^*]+\\*|_[^_]+_", .italic),
        // 인라인 코드
        ("`[^`]+`", .code),
        // 링크
        ("\\[([^\\]]+)\\]\\(([^\\)]+)\\)", .link),
        // 인용구
        ("^>\\s.*$", .blockquote),
        // 리스트 마커
        ("^\\s*[-*+]\\s|^\\s*\\d+\\.\\s", .listMarker),
        // 코드 블록
        ("```[\\s\\S]*?```", .codeBlock),
    ]

    func highlight(_ attributedString: NSMutableAttributedString, with theme: Theme) {
        let text = attributedString.string
        let fullRange = NSRange(location: 0, length: text.utf16.count)

        // 기본 스타일 적용
        attributedString.addAttribute(.foregroundColor, value: theme.text, range: fullRange)

        // 각 패턴에 대해 하이라이팅 적용
        for (pattern, style) in patterns {
            applyPattern(pattern, style: style, to: attributedString, theme: theme)
        }
    }

    private func applyPattern(_ pattern: String, style: HighlightStyle,
                             to attributedString: NSMutableAttributedString, theme: Theme) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        let text = attributedString.string
        let range = NSRange(location: 0, length: text.utf16.count)

        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            let color = self.color(for: style, theme: theme)
            attributedString.addAttribute(.foregroundColor, value: color, range: matchRange)
        }
    }

    private func color(for style: HighlightStyle, theme: Theme) -> NSColor {
        switch style {
        case .heading: return theme.heading
        case .bold: return theme.bold
        case .italic: return theme.italic
        case .code, .codeBlock: return theme.code
        case .link: return theme.link
        case .blockquote: return theme.blockquote
        case .listMarker: return theme.listMarker
        }
    }
}
```

### 7. 미리보기 뷰 (WKWebView 래퍼)

```swift
// PreviewView.swift
struct PreviewView: NSViewRepresentable {
    var htmlContent: String
    var theme: PreviewTheme

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = wrapHTML(content: htmlContent, theme: theme)
        webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func wrapHTML(content: String, theme: PreviewTheme) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="preview-\(theme.rawValue).css">
            <link rel="stylesheet" href="highlight.min.css">
            <script src="highlight.min.js"></script>
            <script src="katex.min.js"></script>
            <link rel="stylesheet" href="katex.min.css">
            <script src="mermaid.min.js"></script>
            <script>
                mermaid.initialize({ startOnLoad: true, theme: '\(theme == .dark ? "dark" : "default")' });
            </script>
        </head>
        <body class="\(theme.rawValue)">
            <div class="markdown-body">
                \(content)
            </div>
            <script>
                hljs.highlightAll();
                renderMathInElement(document.body, {
                    delimiters: [
                        {left: '$$', right: '$$', display: true},
                        {left: '$', right: '$', display: false}
                    ]
                });
            </script>
        </body>
        </html>
        """
    }
}
```

### 8. Markdown 프로세서

```swift
// MarkdownProcessor.swift
import Markdown

class MarkdownProcessor {

    func parse(_ markdown: String) -> Document {
        return Document(parsing: markdown, options: [.parseBlockDirectives, .parseSymbolLinks])
    }

    func convertToHTML(_ markdown: String) -> String {
        let document = parse(markdown)
        var htmlVisitor = HTMLVisitor()
        return htmlVisitor.visit(document)
    }
}

// HTML 변환 Visitor
struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    mutating func defaultVisit(_ markup: Markup) -> String {
        return markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Document) -> String {
        return document.children.map { visit($0) }.joined()
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = heading.level
        let content = heading.children.map { visit($0) }.joined()
        return "<h\(level)>\(content)</h\(level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        let content = paragraph.children.map { visit($0) }.joined()
        return "<p>\(content)</p>\n"
    }

    mutating func visitText(_ text: Markdown.Text) -> String {
        return escapeHTML(text.string)
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        let content = strong.children.map { visit($0) }.joined()
        return "<strong>\(content)</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        let content = emphasis.children.map { visit($0) }.joined()
        return "<em>\(content)</em>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let language = codeBlock.language ?? ""
        let code = escapeHTML(codeBlock.code)

        // Mermaid 다이어그램 처리
        if language.lowercased() == "mermaid" {
            return "<div class=\"mermaid\">\(codeBlock.code)</div>\n"
        }

        return "<pre><code class=\"language-\(language)\">\(code)</code></pre>\n"
    }

    mutating func visitTable(_ table: Table) -> String {
        var html = "<table>\n<thead>\n<tr>\n"

        // 헤더 행
        for cell in table.head.cells {
            let content = cell.children.map { visit($0) }.joined()
            html += "<th>\(content)</th>\n"
        }
        html += "</tr>\n</thead>\n<tbody>\n"

        // 본문 행
        for row in table.body.rows {
            html += "<tr>\n"
            for cell in row.cells {
                let content = cell.children.map { visit($0) }.joined()
                html += "<td>\(content)</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</tbody>\n</table>\n"

        return html
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        let content = strikethrough.children.map { visit($0) }.joined()
        return "<del>\(content)</del>"
    }

    mutating func visitLink(_ link: Markdown.Link) -> String {
        let content = link.children.map { visit($0) }.joined()
        let destination = link.destination ?? ""
        return "<a href=\"\(destination)\">\(content)</a>"
    }

    mutating func visitImage(_ image: Markdown.Image) -> String {
        let alt = image.children.map { visit($0) }.joined()
        let source = image.source ?? ""
        return "<img src=\"\(source)\" alt=\"\(alt)\">"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let content = blockQuote.children.map { visit($0) }.joined()
        return "<blockquote>\(content)</blockquote>\n"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> String {
        let items = list.listItems.map { visitListItem($0) }.joined()
        return "<ul>\n\(items)</ul>\n"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> String {
        let items = list.listItems.map { visitListItem($0) }.joined()
        return "<ol>\n\(items)</ol>\n"
    }

    mutating func visitListItem(_ item: ListItem) -> String {
        // 체크박스 처리
        if let checkbox = item.checkbox {
            let checked = checkbox == .checked ? "checked" : ""
            let content = item.children.map { visit($0) }.joined()
            return "<li><input type=\"checkbox\" \(checked) disabled>\(content)</li>\n"
        }
        let content = item.children.map { visit($0) }.joined()
        return "<li>\(content)</li>\n"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        return "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitThematicBreak(_ break: ThematicBreak) -> String {
        return "<hr>\n"
    }

    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// 확장 문법 처리 (수식, 각주 등)
extension MarkdownProcessor {

    func processExtendedSyntax(_ html: String) -> String {
        var result = html

        // 수식 처리 ($$...$$ 블록, $...$ 인라인)
        result = processBlockMath(result)
        result = processInlineMath(result)

        // 각주 처리
        result = processFootnotes(result)

        // 하이라이트 처리 (==text==)
        result = processHighlight(result)

        // 위/아래 첨자 처리
        result = processSuperscript(result)
        result = processSubscript(result)

        return result
    }

    private func processBlockMath(_ html: String) -> String {
        let pattern = "\\$\\$([^$]+)\\$\\$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return html
        }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: "<div class=\"math-block\">$1</div>"
        )
    }

    private func processInlineMath(_ html: String) -> String {
        let pattern = "\\$([^$]+)\\$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: "<span class=\"math-inline\">$1</span>"
        )
    }

    private func processFootnotes(_ html: String) -> String {
        // 각주 참조: [^1]
        var result = html
        let refPattern = "\\[\\^(\\d+)\\](?!:)"
        if let regex = try? NSRegularExpression(pattern: refPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<sup><a href=\"#fn$1\" id=\"fnref$1\">$1</a></sup>"
            )
        }

        // 각주 정의: [^1]: 내용
        let defPattern = "\\[\\^(\\d+)\\]:\\s*(.+)"
        if let regex = try? NSRegularExpression(pattern: defPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<div class=\"footnote\" id=\"fn$1\"><sup>$1</sup> $2 <a href=\"#fnref$1\">↩</a></div>"
            )
        }

        return result
    }

    private func processHighlight(_ html: String) -> String {
        let pattern = "==([^=]+)=="
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: "<mark>$1</mark>"
        )
    }

    private func processSuperscript(_ html: String) -> String {
        let pattern = "\\^([^^]+)\\^"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: "<sup>$1</sup>"
        )
    }

    private func processSubscript(_ html: String) -> String {
        let pattern = "~([^~]+)~"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: "<sub>$1</sub>"
        )
    }
}
```

### 9. 파일 Drag & Drop

```swift
// FileDropDelegate.swift
struct FileDropDelegate: DropDelegate {
    @Binding var document: MarkdownDocument
    @State private var isTargeted = false

    let supportedTypes: [UTType] = [.markdown, .plainText, .text]

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: supportedTypes.map { $0.identifier })
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: supportedTypes.map { $0.identifier }).first else {
            return false
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, error in
            guard let urlData = data as? Data,
                  let url = URL(dataRepresentation: urlData, relativeTo: nil),
                  let content = try? String(contentsOf: url, encoding: .utf8) else {
                return
            }

            DispatchQueue.main.async {
                // 저장되지 않은 변경사항 확인
                if document.content.isEmpty || showSaveConfirmation() {
                    document.content = content
                }
            }
        }

        return true
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    private func showSaveConfirmation() -> Bool {
        let alert = NSAlert()
        alert.messageText = "저장되지 않은 변경사항"
        alert.informativeText = "현재 문서에 저장되지 않은 변경사항이 있습니다. 새 파일을 열면 변경사항이 손실됩니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "계속")
        alert.addButton(withTitle: "취소")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
```

### 10. 포맷팅 서비스

```swift
// FormattingService.swift
class FormattingService {

    enum FormatType {
        case bold
        case italic
        case strikethrough
        case code
        case link
        case image
        case heading(level: Int)
        case bulletList
        case numberedList
        case taskList
        case quote
        case table
        case horizontalRule
    }

    func format(_ text: String, selection: Range<String.Index>?, type: FormatType) -> (String, Range<String.Index>) {
        let selectedText = selection.map { String(text[$0]) } ?? ""

        switch type {
        case .bold:
            return wrapWith(text: text, selection: selection, prefix: "**", suffix: "**", placeholder: "bold text")
        case .italic:
            return wrapWith(text: text, selection: selection, prefix: "*", suffix: "*", placeholder: "italic text")
        case .strikethrough:
            return wrapWith(text: text, selection: selection, prefix: "~~", suffix: "~~", placeholder: "strikethrough")
        case .code:
            return wrapWith(text: text, selection: selection, prefix: "`", suffix: "`", placeholder: "code")
        case .link:
            return insertLink(text: text, selection: selection, selectedText: selectedText)
        case .image:
            return insertImage(text: text, selection: selection)
        case .heading(let level):
            return insertHeading(text: text, selection: selection, level: level)
        case .bulletList:
            return insertList(text: text, selection: selection, marker: "- ")
        case .numberedList:
            return insertList(text: text, selection: selection, marker: "1. ")
        case .taskList:
            return insertList(text: text, selection: selection, marker: "- [ ] ")
        case .quote:
            return insertQuote(text: text, selection: selection)
        case .table:
            return insertTable(text: text, selection: selection)
        case .horizontalRule:
            return insertHorizontalRule(text: text, selection: selection)
        }
    }

    private func wrapWith(text: String, selection: Range<String.Index>?,
                         prefix: String, suffix: String, placeholder: String) -> (String, Range<String.Index>) {
        var newText = text
        let insertText: String
        let newSelection: Range<String.Index>

        if let selection = selection, !selection.isEmpty {
            let selectedText = String(text[selection])
            insertText = "\(prefix)\(selectedText)\(suffix)"
            newText.replaceSubrange(selection, with: insertText)
            let start = selection.lowerBound
            let end = text.index(start, offsetBy: insertText.count)
            newSelection = start..<end
        } else {
            insertText = "\(prefix)\(placeholder)\(suffix)"
            let insertIndex = selection?.lowerBound ?? text.endIndex
            newText.insert(contentsOf: insertText, at: insertIndex)
            let start = text.index(insertIndex, offsetBy: prefix.count)
            let end = text.index(start, offsetBy: placeholder.count)
            newSelection = start..<end
        }

        return (newText, newSelection)
    }

    private func insertTable(text: String, selection: Range<String.Index>?) -> (String, Range<String.Index>) {
        let tableTemplate = """

        | Column 1 | Column 2 | Column 3 |
        |----------|----------|----------|
        | Cell 1   | Cell 2   | Cell 3   |

        """

        var newText = text
        let insertIndex = selection?.lowerBound ?? text.endIndex
        newText.insert(contentsOf: tableTemplate, at: insertIndex)

        return (newText, insertIndex..<text.index(insertIndex, offsetBy: tableTemplate.count))
    }

    // 기타 포맷팅 메서드들...
}
```

### 11. 테마 관리

```swift
// ThemeManager.swift
enum EditorTheme: String, CaseIterable {
    case dark
    case light

    var backgroundColor: NSColor {
        switch self {
        case .dark: return NSColor(hex: "#282C34")
        case .light: return NSColor(hex: "#FAFAFA")
        }
    }

    var textColor: NSColor {
        switch self {
        case .dark: return NSColor(hex: "#ABB2BF")
        case .light: return NSColor(hex: "#383A42")
        }
    }

    var syntaxHighlighter: SyntaxHighlighter.Theme {
        switch self {
        case .dark: return SyntaxHighlighter.darkTheme
        case .light: return SyntaxHighlighter.lightTheme
        }
    }
}

enum PreviewTheme: String, CaseIterable {
    case dark
    case light
}

@Observable
class ThemeManager {
    var editorTheme: EditorTheme = .dark
    var previewTheme: PreviewTheme = .dark

    func loadFromUserDefaults() {
        if let rawValue = UserDefaults.standard.string(forKey: "editorTheme"),
           let theme = EditorTheme(rawValue: rawValue) {
            editorTheme = theme
        }
        if let rawValue = UserDefaults.standard.string(forKey: "previewTheme"),
           let theme = PreviewTheme(rawValue: rawValue) {
            previewTheme = theme
        }
    }

    func save() {
        UserDefaults.standard.set(editorTheme.rawValue, forKey: "editorTheme")
        UserDefaults.standard.set(previewTheme.rawValue, forKey: "previewTheme")
    }
}
```

### 12. 내보내기 서비스

```swift
// ExportService.swift
class ExportService {
    private let markdownProcessor = MarkdownProcessor()

    func exportToHTML(content: String, theme: PreviewTheme) throws -> String {
        let htmlBody = markdownProcessor.convertToHTML(content)
        let processedHTML = markdownProcessor.processExtendedSyntax(htmlBody)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Exported Document</title>
            <style>
                \(getEmbeddedStyles(theme: theme))
            </style>
        </head>
        <body class="markdown-body">
            \(processedHTML)
        </body>
        </html>
        """
    }

    func saveHTML(content: String, to url: URL, theme: PreviewTheme) throws {
        let html = try exportToHTML(content: content, theme: theme)
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    private func getEmbeddedStyles(theme: PreviewTheme) -> String {
        guard let cssURL = Bundle.main.url(forResource: "preview-\(theme.rawValue)", withExtension: "css"),
              let css = try? String(contentsOf: cssURL) else {
            return ""
        }
        return css
    }
}
```

## 데이터 모델

### 앱 상태

```swift
// AppState.swift
@Observable
class AppState {
    var editorTheme: EditorTheme = .dark
    var previewTheme: PreviewTheme = .dark
    var previewMode: PreviewMode = .preview
    var autoReloadPreview: Bool = true
    var showLineNumbers: Bool = true
    var fontSize: CGFloat = 14
    var fontName: String = "SF Mono"

    init() {
        loadSettings()
    }

    func loadSettings() {
        let defaults = UserDefaults.standard

        if let rawValue = defaults.string(forKey: "editorTheme"),
           let theme = EditorTheme(rawValue: rawValue) {
            editorTheme = theme
        }

        if let rawValue = defaults.string(forKey: "previewTheme"),
           let theme = PreviewTheme(rawValue: rawValue) {
            previewTheme = theme
        }

        autoReloadPreview = defaults.bool(forKey: "autoReloadPreview")
        showLineNumbers = defaults.bool(forKey: "showLineNumbers")
        fontSize = CGFloat(defaults.float(forKey: "fontSize"))
        fontName = defaults.string(forKey: "fontName") ?? "SF Mono"
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(editorTheme.rawValue, forKey: "editorTheme")
        defaults.set(previewTheme.rawValue, forKey: "previewTheme")
        defaults.set(autoReloadPreview, forKey: "autoReloadPreview")
        defaults.set(showLineNumbers, forKey: "showLineNumbers")
        defaults.set(Float(fontSize), forKey: "fontSize")
        defaults.set(fontName, forKey: "fontName")
    }
}

enum PreviewMode: String {
    case preview
    case html
}
```

## 에러 처리

```swift
// Errors.swift
enum MarkdownEditorError: LocalizedError {
    case fileReadError(URL)
    case fileWriteError(URL)
    case unsupportedFileType(String)
    case exportError(String)
    case renderError(String)

    var errorDescription: String? {
        switch self {
        case .fileReadError(let url):
            return "파일을 읽을 수 없습니다: \(url.lastPathComponent)"
        case .fileWriteError(let url):
            return "파일을 저장할 수 없습니다: \(url.lastPathComponent)"
        case .unsupportedFileType(let type):
            return "지원하지 않는 파일 형식입니다: \(type)"
        case .exportError(let message):
            return "내보내기 오류: \(message)"
        case .renderError(let message):
            return "렌더링 오류: \(message)"
        }
    }
}

// 에러 처리 뷰 모디파이어
struct ErrorAlert: ViewModifier {
    @Binding var error: MarkdownEditorError?

    func body(content: Content) -> some View {
        content.alert(
            "오류",
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            ),
            presenting: error
        ) { _ in
            Button("확인") { error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
```

## 빌드 및 배포

### 프로젝트 구조

```
MarkdownEditor/
├── MarkdownEditor.xcodeproj/
├── MarkdownEditor/
│   ├── App/
│   │   └── MarkdownEditorApp.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── EditorView.swift
│   │   ├── PreviewView.swift
│   │   ├── ToolbarView.swift
│   │   └── PreferencesView.swift
│   ├── ViewModels/
│   │   └── EditorViewModel.swift
│   ├── Models/
│   │   ├── MarkdownDocument.swift
│   │   └── AppState.swift
│   ├── Services/
│   │   ├── MarkdownProcessor.swift
│   │   ├── FormattingService.swift
│   │   ├── ExportService.swift
│   │   └── SyntaxHighlighter.swift
│   ├── Utilities/
│   │   ├── FileDropDelegate.swift
│   │   ├── LineNumberView.swift
│   │   └── Extensions.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   │   └── AppIcon.appiconset/
│   │   ├── preview-dark.css
│   │   ├── preview-light.css
│   │   ├── highlight.min.js
│   │   ├── highlight.min.css
│   │   ├── katex.min.js
│   │   ├── katex.min.css
│   │   └── mermaid.min.js
│   └── Info.plist
├── scripts/
│   ├── build.sh
│   ├── create-icons.sh
│   └── create-dmg.sh
└── specs/
    └── markdown-editor/
        ├── requirements.md
        ├── design.md
        └── tasks.md
```

### 아이콘 생성 스크립트

```bash
#!/bin/bash
# scripts/create-icons.sh

SOURCE_IMAGE="icon.png"
ICONSET_DIR="MarkdownEditor/Resources/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$ICONSET_DIR"

# 다양한 크기로 아이콘 생성
sizes=(16 32 64 128 256 512 1024)
for size in "${sizes[@]}"; do
    sips -z $size $size "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_${size}x${size}.png"

    # @2x 버전 생성 (Retina 디스플레이용)
    if [ $size -le 512 ]; then
        double=$((size * 2))
        sips -z $double $double "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png"
    fi
done

# Contents.json 생성
cat > "$ICONSET_DIR/Contents.json" << 'EOF'
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

echo "아이콘 생성 완료!"
```

### DMG 생성 및 공증 스크립트

```bash
#!/bin/bash
# scripts/create-dmg.sh

APP_NAME="MarkdownEditor"
APP_PATH="build/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
SIGNING_IDENTITY="Developer ID Application: Your Name (XU8HS9JUTS)"
KEYCHAIN_PROFILE="notarytool"

# 1. Release 빌드
echo "=== Release 빌드 중... ==="
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath build \
    clean build

# 2. 앱 코드 서명
echo "=== 앱 코드 서명 중... ==="
codesign --force --deep --options runtime \
    --sign "${SIGNING_IDENTITY}" \
    "${APP_PATH}"

# 3. 앱 서명 검증
echo "=== 서명 검증 중... ==="
codesign --verify --verbose "${APP_PATH}"

# 4. DMG 생성
echo "=== DMG 생성 중... ==="
create-dmg \
    --volname "${VOLUME_NAME}" \
    --volicon "icon.png" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 150 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 450 185 \
    --no-internet-enable \
    "${DMG_NAME}" \
    "${APP_PATH}"

# 5. DMG 코드 서명
echo "=== DMG 코드 서명 중... ==="
codesign --force --sign "${SIGNING_IDENTITY}" "${DMG_NAME}"

# 6. 공증 제출
echo "=== 공증 제출 중... ==="
xcrun notarytool submit "${DMG_NAME}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait

# 7. 공증 스테이플
echo "=== 공증 티켓 스테이플 중... ==="
xcrun stapler staple "${DMG_NAME}"

# 8. 스테이플 검증
echo "=== 스테이플 검증 중... ==="
xcrun stapler validate "${DMG_NAME}"

echo "=== 완료! ==="
echo "DMG 파일: ${DMG_NAME}"
```

## 테스팅 전략

### 단위 테스트

```swift
// MarkdownProcessorTests.swift
import XCTest
@testable import MarkdownEditor

class MarkdownProcessorTests: XCTestCase {
    var processor: MarkdownProcessor!

    override func setUp() {
        processor = MarkdownProcessor()
    }

    func testHeadingConversion() {
        let markdown = "# Hello World"
        let html = processor.convertToHTML(markdown)
        XCTAssertTrue(html.contains("<h1>Hello World</h1>"))
    }

    func testBoldConversion() {
        let markdown = "**bold text**"
        let html = processor.convertToHTML(markdown)
        XCTAssertTrue(html.contains("<strong>bold text</strong>"))
    }

    func testTableConversion() {
        let markdown = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let html = processor.convertToHTML(markdown)
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th>A</th>"))
    }

    func testMermaidCodeBlock() {
        let markdown = """
        ```mermaid
        graph TD
            A --> B
        ```
        """
        let html = processor.convertToHTML(markdown)
        XCTAssertTrue(html.contains("<div class=\"mermaid\">"))
    }

    func testMathProcessing() {
        let html = "This is $x^2$ math"
        let processed = processor.processExtendedSyntax(html)
        XCTAssertTrue(processed.contains("<span class=\"math-inline\">"))
    }

    func testFootnoteProcessing() {
        let html = "Text[^1] and [^1]: footnote"
        let processed = processor.processExtendedSyntax(html)
        XCTAssertTrue(processed.contains("fnref1"))
    }
}
```

### UI 테스트

```swift
// MarkdownEditorUITests.swift
import XCTest

class MarkdownEditorUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testEditorTyping() {
        let editor = app.textViews["EditorTextView"]
        editor.click()
        editor.typeText("# Hello World")

        XCTAssertTrue(editor.value as? String == "# Hello World")
    }

    func testBoldFormatting() {
        let editor = app.textViews["EditorTextView"]
        editor.click()
        editor.typeText("test")
        editor.typeKey("a", modifierFlags: .command) // 전체 선택

        app.buttons["Bold"].click()

        XCTAssertTrue((editor.value as? String)?.contains("**test**") ?? false)
    }

    func testThemeToggle() {
        let themeButton = app.popUpButtons["EditorTheme"]
        themeButton.click()
        app.menuItems["Light"].click()

        // 테마 변경 확인
        XCTAssertTrue(themeButton.value as? String == "Light")
    }

    func testFileDragAndDrop() {
        // Drag & Drop 테스트는 실제 파일 시스템 접근이 필요하므로
        // 통합 테스트에서 수행
    }
}
```

### 통합 테스트

```swift
// IntegrationTests.swift
import XCTest
@testable import MarkdownEditor

class IntegrationTests: XCTestCase {

    func testDocumentSaveAndLoad() throws {
        let content = "# Test Document\n\nHello World"
        let document = MarkdownDocument(content: content)

        // 파일로 저장
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.md")
        let data = content.data(using: .utf8)!
        try data.write(to: tempURL)

        // 파일에서 로드
        let loadedData = try Data(contentsOf: tempURL)
        let loadedContent = String(data: loadedData, encoding: .utf8)

        XCTAssertEqual(content, loadedContent)

        // 정리
        try FileManager.default.removeItem(at: tempURL)
    }

    func testHTMLExport() throws {
        let content = "# Hello\n\n**Bold** text"
        let exportService = ExportService()

        let html = try exportService.exportToHTML(content: content, theme: .dark)

        XCTAssertTrue(html.contains("<h1>Hello</h1>"))
        XCTAssertTrue(html.contains("<strong>Bold</strong>"))
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
    }
}
```

## 성능 최적화 컴포넌트

### 1. Debouncer (입력 디바운싱)

```swift
// Debouncer.swift
actor Debouncer {
    private var task: Task<Void, Never>?
    private let duration: Duration

    init(duration: Duration = .milliseconds(300)) {
        self.duration = duration
    }

    func debounce(operation: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await operation()
        }
    }
}

// 사용 예시: EditorViewModel
@Observable
class EditorViewModel {
    private let debouncer = Debouncer(duration: .milliseconds(300))
    private let markdownProcessor = MarkdownProcessor()

    var content: String = "" {
        didSet {
            Task {
                await debouncer.debounce { [weak self] in
                    await self?.updatePreview()
                }
            }
        }
    }

    var htmlContent: String = ""

    @MainActor
    private func updatePreview() async {
        // 백그라운드에서 Markdown 처리
        let html = await Task.detached(priority: .userInitiated) {
            self.markdownProcessor.convertToHTML(self.content)
        }.value

        self.htmlContent = html
    }
}
```

### 2. 다이어그램 캐시 매니저

```swift
// DiagramCacheManager.swift
import CryptoKit

actor DiagramCacheManager {
    static let shared = DiagramCacheManager()

    private var cache: [String: CachedDiagram] = [:]
    private let maxCacheSize = 100
    private let maxCacheAge: TimeInterval = 3600 // 1시간

    struct CachedDiagram {
        let svg: String
        let timestamp: Date
    }

    private func cacheKey(for content: String, type: DiagramType) -> String {
        let data = Data((content + type.rawValue).utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func get(content: String, type: DiagramType) -> String? {
        let key = cacheKey(for: content, type: type)
        guard let cached = cache[key] else { return nil }

        // 캐시 만료 확인
        if Date().timeIntervalSince(cached.timestamp) > maxCacheAge {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached.svg
    }

    func set(content: String, type: DiagramType, svg: String) {
        let key = cacheKey(for: content, type: type)

        // 캐시 크기 제한
        if cache.count >= maxCacheSize {
            evictOldestEntries()
        }

        cache[key] = CachedDiagram(svg: svg, timestamp: Date())
    }

    private func evictOldestEntries() {
        let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        let toRemove = sorted.prefix(maxCacheSize / 4)
        for (key, _) in toRemove {
            cache.removeValue(forKey: key)
        }
    }

    func clearCache() {
        cache.removeAll()
    }
}

enum DiagramType: String {
    case mermaid
    case plantuml
}
```

### 3. PlantUML 서비스 (비동기 API 호출)

```swift
// PlantUMLService.swift
import Foundation
import zlib

actor PlantUMLService {
    static let shared = PlantUMLService()

    private let baseURL = "https://www.plantuml.com/plantuml/svg/"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func render(_ umlCode: String) async throws -> String {
        // 1. 캐시 확인
        if let cached = await DiagramCacheManager.shared.get(content: umlCode, type: .plantuml) {
            return cached
        }

        // 2. PlantUML 인코딩
        let encoded = encodePlantUML(umlCode)
        let url = URL(string: baseURL + encoded)!

        // 3. API 호출
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlantUMLError.serverError
        }

        guard let svg = String(data: data, encoding: .utf8) else {
            throw PlantUMLError.invalidResponse
        }

        // 4. 캐시 저장
        await DiagramCacheManager.shared.set(content: umlCode, type: .plantuml, svg: svg)

        return svg
    }

    // PlantUML 인코딩 (Deflate + Base64 변형)
    private func encodePlantUML(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return "" }

        // Deflate 압축
        let deflated = deflate(data)

        // PlantUML Base64 인코딩 (표준 Base64와 다름)
        return encodePlantUMLBase64(deflated)
    }

    private func deflate(_ data: Data) -> Data {
        var compressed = Data()
        data.withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) in
            let sourceBuffer = sourcePtr.bindMemory(to: UInt8.self)

            var stream = z_stream()
            stream.next_in = UnsafeMutablePointer(mutating: sourceBuffer.baseAddress)
            stream.avail_in = uInt(data.count)

            deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))

            var buffer = [UInt8](repeating: 0, count: 32768)
            repeat {
                stream.next_out = &buffer
                stream.avail_out = uInt(buffer.count)
                deflate(&stream, Z_FINISH)
                let count = buffer.count - Int(stream.avail_out)
                compressed.append(buffer, count: count)
            } while stream.avail_out == 0

            deflateEnd(&stream)
        }
        return compressed
    }

    private func encodePlantUMLBase64(_ data: Data) -> String {
        let alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
        var result = ""

        var i = 0
        while i < data.count {
            let b1 = Int(data[i])
            let b2 = i + 1 < data.count ? Int(data[i + 1]) : 0
            let b3 = i + 2 < data.count ? Int(data[i + 2]) : 0

            let c1 = b1 >> 2
            let c2 = ((b1 & 0x3) << 4) | (b2 >> 4)
            let c3 = ((b2 & 0xF) << 2) | (b3 >> 6)
            let c4 = b3 & 0x3F

            result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: c1)])
            result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: c2)])

            if i + 1 < data.count {
                result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: c3)])
            }
            if i + 2 < data.count {
                result.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: c4)])
            }

            i += 3
        }

        return result
    }
}

enum PlantUMLError: LocalizedError {
    case serverError
    case invalidResponse
    case encodingError

    var errorDescription: String? {
        switch self {
        case .serverError: return "PlantUML 서버 오류"
        case .invalidResponse: return "잘못된 응답"
        case .encodingError: return "인코딩 오류"
        }
    }
}
```

### 4. 통합 다이어그램 렌더러

```swift
// DiagramRenderer.swift
actor DiagramRenderer {
    static let shared = DiagramRenderer()

    private let plantUMLService = PlantUMLService.shared

    func render(code: String, type: DiagramType) async -> DiagramResult {
        // 캐시 확인
        if let cached = await DiagramCacheManager.shared.get(content: code, type: type) {
            return .success(cached)
        }

        switch type {
        case .mermaid:
            // Mermaid는 클라이언트 사이드 렌더링 (JavaScript)
            // HTML에 <div class="mermaid"> 태그로 삽입하면 mermaid.js가 처리
            let html = "<div class=\"mermaid\">\(escapeHTML(code))</div>"
            await DiagramCacheManager.shared.set(content: code, type: type, svg: html)
            return .success(html)

        case .plantuml:
            do {
                let svg = try await plantUMLService.render(code)
                return .success(svg)
            } catch {
                return .failure(error.localizedDescription)
            }
        }
    }

    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

enum DiagramResult {
    case success(String)
    case failure(String)

    var html: String {
        switch self {
        case .success(let content):
            return content
        case .failure(let error):
            return "<div class=\"diagram-error\">다이어그램 렌더링 오류: \(error)</div>"
        }
    }
}
```

### 5. Markdown 프로세서 (다이어그램 통합)

```swift
// MarkdownProcessor 확장
extension MarkdownProcessor {

    func convertToHTMLAsync(_ markdown: String) async -> String {
        // 1. 기본 HTML 변환 (백그라운드)
        var html = await Task.detached(priority: .userInitiated) {
            self.convertToHTML(markdown)
        }.value

        // 2. 확장 문법 처리
        html = processExtendedSyntax(html)

        // 3. 다이어그램 처리 (PlantUML은 비동기)
        html = await processDiagrams(html)

        return html
    }

    private func processDiagrams(_ html: String) async -> String {
        var result = html

        // PlantUML 코드 블록 찾기 및 렌더링
        let plantumlPattern = "<pre><code class=\"language-plantuml\">([\\s\\S]*?)</code></pre>"
        if let regex = try? NSRegularExpression(pattern: plantumlPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))

            // 역순으로 처리 (인덱스 변경 방지)
            for match in matches.reversed() {
                let codeRange = match.range(at: 1)
                let code = nsString.substring(with: codeRange)
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&amp;", with: "&")

                let diagramResult = await DiagramRenderer.shared.render(code: code, type: .plantuml)
                result = (result as NSString).replacingCharacters(in: match.range, with: diagramResult.html)
            }
        }

        return result
    }
}
```

### 6. 증분 업데이트 (Incremental DOM Update)

```swift
// IncrementalUpdater.swift
class IncrementalUpdater {
    private var previousBlocks: [ContentBlock] = []

    struct ContentBlock: Hashable {
        let id: String
        let type: BlockType
        let content: String
        let hash: String

        init(type: BlockType, content: String) {
            self.type = type
            self.content = content
            self.hash = SHA256.hash(data: Data(content.utf8))
                .compactMap { String(format: "%02x", $0) }.joined()
            self.id = "\(type.rawValue)-\(hash.prefix(8))"
        }
    }

    enum BlockType: String {
        case heading, paragraph, codeBlock, list, table, blockquote, diagram, other
    }

    func computeChanges(newContent: String) -> [Change] {
        let newBlocks = parseBlocks(newContent)
        var changes: [Change] = []

        let diff = newBlocks.difference(from: previousBlocks)

        for change in diff {
            switch change {
            case .insert(let offset, let block, _):
                changes.append(.insert(index: offset, block: block))
            case .remove(let offset, let block, _):
                changes.append(.remove(index: offset, blockId: block.id))
            }
        }

        previousBlocks = newBlocks
        return changes
    }

    private func parseBlocks(_ content: String) -> [ContentBlock] {
        // Markdown을 블록 단위로 파싱
        var blocks: [ContentBlock] = []
        let lines = content.components(separatedBy: "\n\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let type: BlockType
            if trimmed.hasPrefix("#") {
                type = .heading
            } else if trimmed.hasPrefix("```") {
                type = trimmed.contains("mermaid") || trimmed.contains("plantuml") ? .diagram : .codeBlock
            } else if trimmed.hasPrefix("|") {
                type = .table
            } else if trimmed.hasPrefix(">") {
                type = .blockquote
            } else if trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.first?.isNumber == true {
                type = .list
            } else {
                type = .paragraph
            }

            blocks.append(ContentBlock(type: type, content: trimmed))
        }

        return blocks
    }

    enum Change {
        case insert(index: Int, block: ContentBlock)
        case remove(index: Int, blockId: String)
        case update(index: Int, block: ContentBlock)
    }
}
```

### 7. 미리보기 뷰 (성능 최적화 적용)

```swift
// PreviewView.swift (최적화 버전)
struct PreviewView: NSViewRepresentable {
    var htmlContent: String
    var theme: PreviewTheme
    @StateObject private var updater = IncrementalUpdater()

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // JavaScript 메시지 핸들러 등록
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "updateBlock")
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // 초기 HTML 로드
        let initialHTML = createInitialHTML(theme: theme)
        webView.loadHTMLString(initialHTML, baseURL: Bundle.main.resourceURL)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // 증분 업데이트 계산
        let changes = updater.computeChanges(newContent: htmlContent)

        if changes.isEmpty {
            return
        }

        // JavaScript를 통한 DOM 업데이트 (전체 리로드 방지)
        for change in changes {
            switch change {
            case .insert(let index, let block):
                let js = "insertBlock(\(index), '\(block.id)', `\(escapeJS(block.content))`)"
                webView.evaluateJavaScript(js)
            case .remove(_, let blockId):
                let js = "removeBlock('\(blockId)')"
                webView.evaluateJavaScript(js)
            case .update(_, let block):
                let js = "updateBlock('\(block.id)', `\(escapeJS(block.content))`)"
                webView.evaluateJavaScript(js)
            }
        }

        // Mermaid 재렌더링 트리거
        webView.evaluateJavaScript("mermaid.init(undefined, '.mermaid')")
    }

    private func escapeJS(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    private func createInitialHTML(theme: PreviewTheme) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <link rel="stylesheet" href="preview-\(theme.rawValue).css">
            <script src="highlight.min.js"></script>
            <script src="katex.min.js"></script>
            <script src="mermaid.min.js"></script>
            <script>
                mermaid.initialize({
                    startOnLoad: false,
                    theme: '\(theme == .dark ? "dark" : "default")'
                });

                function insertBlock(index, id, content) {
                    const container = document.getElementById('content');
                    const div = document.createElement('div');
                    div.id = id;
                    div.innerHTML = content;
                    const children = container.children;
                    if (index >= children.length) {
                        container.appendChild(div);
                    } else {
                        container.insertBefore(div, children[index]);
                    }
                    processBlock(div);
                }

                function removeBlock(id) {
                    const block = document.getElementById(id);
                    if (block) block.remove();
                }

                function updateBlock(id, content) {
                    const block = document.getElementById(id);
                    if (block) {
                        block.innerHTML = content;
                        processBlock(block);
                    }
                }

                function processBlock(element) {
                    // 코드 하이라이팅
                    element.querySelectorAll('pre code').forEach(hljs.highlightElement);
                    // 수식 렌더링
                    renderMathInElement(element);
                    // Mermaid 렌더링
                    element.querySelectorAll('.mermaid').forEach(el => {
                        mermaid.init(undefined, el);
                    });
                }
            </script>
        </head>
        <body class="\(theme.rawValue)">
            <div id="content" class="markdown-body"></div>
        </body>
        </html>
        """
    }
}
```

## 참고 자료

- [swift-markdown (Apple)](https://github.com/swiftlang/swift-markdown)
- [swift-cmark](https://github.com/swiftlang/swift-cmark)
- [Mermaid.js](https://mermaid.js.org/)
- [PlantUML](https://plantuml.com/)
- [PlantUML Server API](https://plantuml.com/server)
- [KaTeX](https://katex.org/)
- [create-dmg](https://github.com/create-dmg/create-dmg)
- [Apple Notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

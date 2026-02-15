import Foundation
import Markdown

// swift-markdown AST 기반 Markdown → HTML 변환 프로세서
// CommonMark + GFM(테이블, 취소선, 체크리스트) + 확장 문법 지원

class MarkdownProcessor {

    // MARK: - 메인 변환 메서드
    func convertToHTML(_ markdown: String) -> String {
        // swift-markdown으로 파싱 (GFM 확장 활성화)
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])

        // AST → HTML 변환 (원본 소스를 전달하여 단일/이중 틸드 구별)
        var visitor = HTMLVisitor(sourceMarkdown: markdown)
        var html = visitor.visit(document)

        // swift-markdown이 처리하지 않는 확장 문법 후처리
        html = postProcessHighlight(html)

        return html
    }
}

// MARK: - HTML Visitor
// swift-markdown AST를 순회하며 HTML 생성

private struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    // 원본 소스 (단일/이중 틸드 구별용)
    private let sourceLines: [String]

    init(sourceMarkdown: String = "") {
        self.sourceLines = sourceMarkdown.components(separatedBy: "\n")
    }

    // MARK: - Document

    mutating func defaultVisit(_ markup: any Markup) -> String {
        return markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Document) -> String {
        return document.children.map { visit($0) }.joined(separator: "\n")
    }

    // MARK: - Block Elements

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = heading.level
        let content = heading.children.map { visit($0) }.joined()
        let id = generateHeadingId(from: heading.plainText)
        return "<h\(level) id=\"\(id)\">\(content)</h\(level)>"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        let content = paragraph.children.map { visit($0) }.joined()
        return "<p>\(content)</p>"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let content = blockQuote.children.map { visit($0) }.joined(separator: "\n")
        return "<blockquote>\(content)</blockquote>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let language = codeBlock.language?.lowercased() ?? ""
        let code = codeBlock.code

        // Mermaid 다이어그램
        if language == "mermaid" {
            return "<div class=\"mermaid\">\(code)</div>"
        }

        // PlantUML 다이어그램
        if language == "plantuml" {
            let escaped = code
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "\n", with: "&#10;")
            return "<div class=\"plantuml\" data-code=\"\(escaped)\">[PlantUML Diagram]</div>"
        }

        // 일반 코드 블록
        let langClass = language.isEmpty ? "" : " class=\"language-\(language)\""
        return "<pre><code\(langClass)>\(escapeHTML(code))</code></pre>"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        return "<hr>"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        return html.rawHTML
    }

    // MARK: - Lists

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let items = orderedList.children.map { visit($0) }.joined(separator: "\n")
        let start = orderedList.startIndex
        if start != 1 {
            return "<ol start=\"\(start)\">\n\(items)\n</ol>"
        }
        return "<ol>\n\(items)\n</ol>"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        let items = unorderedList.children.map { visit($0) }.joined(separator: "\n")
        return "<ul>\n\(items)\n</ul>"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        // 체크박스 리스트 아이템
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked
            let checkboxHtml = checked
                ? "<input type=\"checkbox\" disabled checked>"
                : "<input type=\"checkbox\" disabled>"
            let content = listItem.children.map { visit($0) }.joined()
            // <p> 태그 제거 (리스트 아이템 내에서는 불필요)
            let cleanContent = content
                .replacingOccurrences(of: "<p>", with: "")
                .replacingOccurrences(of: "</p>", with: "")
            return "<li>\(checkboxHtml) \(cleanContent.trimmingCharacters(in: .whitespacesAndNewlines))</li>"
        }

        let content = listItem.children.map { visit($0) }.joined()
        // 단일 문단이면 <p> 태그 제거
        let cleanContent: String
        let firstChild: (any Markup)? = listItem.childCount > 0 ? listItem.child(at: 0) : nil
        if listItem.childCount == 1, firstChild is Paragraph {
            cleanContent = content
                .replacingOccurrences(of: "<p>", with: "")
                .replacingOccurrences(of: "</p>", with: "")
        } else {
            cleanContent = content
        }
        return "<li>\(cleanContent.trimmingCharacters(in: .whitespacesAndNewlines))</li>"
    }

    // MARK: - Tables

    mutating func visitTable(_ table: Table) -> String {
        let content = table.children.map { visit($0) }.joined(separator: "\n")
        return "<table>\n\(content)\n</table>"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> String {
        let cells = tableHead.children.map { visit($0) }.joined()
        return "<thead>\n<tr>\(cells)</tr>\n</thead>"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> String {
        let rows = tableBody.children.map { visit($0) }.joined(separator: "\n")
        if rows.isEmpty { return "" }
        return "<tbody>\n\(rows)\n</tbody>"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> String {
        let cells = tableRow.children.map { visit($0) }.joined()
        return "<tr>\(cells)</tr>"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> String {
        let content = tableCell.children.map { visit($0) }.joined()
        let isHeader = tableCell.parent is Table.Head
        let tag = isHeader ? "th" : "td"

        // 정렬
        var style = ""
        let colIdx = tableCell.indexInParent
        if let table = findAncestor(of: tableCell, type: Table.self) {
            let alignments = table.columnAlignments
            if colIdx < alignments.count {
                switch alignments[colIdx] {
                case .left: style = " style=\"text-align: left;\""
                case .center: style = " style=\"text-align: center;\""
                case .right: style = " style=\"text-align: right;\""
                default: break
                }
            }
        }

        return "<\(tag)\(style)>\(content)</\(tag)>"
    }

    private func findAncestor<T: Markup>(of node: any Markup, type: T.Type) -> T? {
        var current = node.parent
        while let parent = current {
            if let match = parent as? T { return match }
            current = parent.parent
        }
        return nil
    }

    // MARK: - Inline Elements

    mutating func visitText(_ text: Text) -> String {
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

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        let content = strikethrough.children.map { visit($0) }.joined()

        // 원본 소스에서 ~~ (이중 틸드)인지 확인
        // ~single~ (단일 틸드)는 취소선이 아니라 원본 텍스트 복원
        if let range = strikethrough.range {
            let line = range.lowerBound.line - 1   // 0-based
            let col = range.lowerBound.column - 1   // 0-based
            if line >= 0 && line < sourceLines.count {
                let lineChars = Array(sourceLines[line])
                if col >= 0 && col + 1 < lineChars.count
                    && lineChars[col] == "~" && lineChars[col + 1] == "~" {
                    return "<del>\(content)</del>"
                }
            }
        }

        // 단일 틸드 — 취소선 아님, 틸드 복원
        return "~\(content)~"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        return "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        return inlineHTML.rawHTML
    }

    mutating func visitLink(_ link: Link) -> String {
        let content = link.children.map { visit($0) }.joined()
        let dest = link.destination ?? ""
        let title = link.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
        return "<a href=\"\(dest)\"\(title)>\(content)</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let alt = image.plainText
        let src = image.source ?? ""
        let title = image.title.map { " title=\"\(escapeHTML($0))\"" } ?? ""
        return "<img src=\"\(src)\" alt=\"\(escapeHTML(alt))\"\(title)>"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        return "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        return "<br>"
    }

    // MARK: - Helpers

    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func generateHeadingId(from text: String) -> String {
        var id = text.lowercased()
        id = id.replacingOccurrences(of: " ", with: "-")

        let allowedCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_"))
            .union(CharacterSet(charactersIn: "\u{AC00}"..."\u{D7A3}"))  // 한글
            .union(CharacterSet(charactersIn: "\u{3040}"..."\u{309F}"))  // 히라가나
            .union(CharacterSet(charactersIn: "\u{30A0}"..."\u{30FF}"))  // 카타카나
            .union(CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}"))  // CJK 한자

        id = id.unicodeScalars.filter { allowedCharacters.contains($0) }.map { String($0) }.joined()

        while id.contains("--") {
            id = id.replacingOccurrences(of: "--", with: "-")
        }
        id = id.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return id
    }
}

// MARK: - 후처리 (swift-markdown이 지원하지 않는 확장 문법)

private extension MarkdownProcessor {

    /// ==highlight== → <mark>highlight</mark>
    func postProcessHighlight(_ html: String) -> String {
        let pattern = "==([^=]+)=="
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: "<mark>$1</mark>"
        )
    }
}

import SwiftUI

// 마크다운 편집 툴바
// 텍스트 포맷팅 및 삽입 버튼 제공

struct ToolbarView: View {
    var onAction: (MarkdownAction) -> Void
    @State private var showTableSelector = false

    var body: some View {
        HStack(spacing: 2) {
            // 헤딩
            Menu {
                Button("Heading 1") { onAction(.heading(1)) }
                Button("Heading 2") { onAction(.heading(2)) }
                Button("Heading 3") { onAction(.heading(3)) }
                Button("Heading 4") { onAction(.heading(4)) }
                Button("Heading 5") { onAction(.heading(5)) }
                Button("Heading 6") { onAction(.heading(6)) }
            } label: {
                ToolbarButton(icon: "number", tooltip: "Heading")
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // 텍스트 스타일
            ToolbarButton(icon: "bold", tooltip: "Bold") {
                onAction(.bold)
            }
            ToolbarButton(icon: "italic", tooltip: "Italic") {
                onAction(.italic)
            }
            ToolbarButton(icon: "strikethrough", tooltip: "Strikethrough") {
                onAction(.strikethrough)
            }
            ToolbarButton(icon: "highlighter", tooltip: "Highlight") {
                onAction(.highlight)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // 코드
            ToolbarButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Inline Code") {
                onAction(.inlineCode)
            }
            ToolbarButton(icon: "rectangle.and.text.magnifyingglass", tooltip: "Code Block") {
                onAction(.codeBlock)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // 링크 및 이미지
            ToolbarButton(icon: "link", tooltip: "Link") {
                onAction(.link)
            }
            ToolbarButton(icon: "photo", tooltip: "Image") {
                onAction(.image)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // 리스트
            ToolbarButton(icon: "list.bullet", tooltip: "Bullet List") {
                onAction(.bulletList)
            }
            ToolbarButton(icon: "list.number", tooltip: "Numbered List") {
                onAction(.numberedList)
            }
            ToolbarButton(icon: "checklist", tooltip: "Task List") {
                onAction(.taskList)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // 인용 및 수평선
            ToolbarButton(icon: "text.quote", tooltip: "Blockquote") {
                onAction(.blockquote)
            }
            ToolbarButton(icon: "minus", tooltip: "Horizontal Rule") {
                onAction(.horizontalRule)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // 테이블 - 그리드 선택기
            TableSelectorButton { rows, cols in
                onAction(.table(rows: rows, cols: cols))
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // 다이어그램
            Menu {
                Button("Mermaid Diagram") { onAction(.mermaid) }
                Button("PlantUML Diagram") { onAction(.plantuml) }
            } label: {
                ToolbarButton(icon: "chart.bar.doc.horizontal", tooltip: "Diagram")
            }

            // 수식
            Menu {
                Button("Inline Math") { onAction(.inlineMath) }
                Button("Block Math") { onAction(.blockMath) }
            } label: {
                ToolbarButton(icon: "function", tooltip: "Math")
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 테이블 크기 선택 버튼
struct TableSelectorButton: View {
    var onSelect: (Int, Int) -> Void
    @State private var isPresented = false
    @State private var hoverRow = 0
    @State private var hoverCol = 0

    let maxRows = 10
    let maxCols = 10
    let cellSize: CGFloat = 28

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            Image(systemName: "tablecells")
                .font(.system(size: 13))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .help("Table")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                // 크기 표시
                Text("(\(hoverCol) x \(hoverRow))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                // 그리드
                VStack(spacing: 2) {
                    ForEach(1...maxRows, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(1...maxCols, id: \.self) { col in
                                Rectangle()
                                    .fill(col <= hoverCol && row <= hoverRow ?
                                          Color.accentColor.opacity(0.7) :
                                          Color.gray.opacity(0.3))
                                    .frame(width: cellSize, height: cellSize)
                                    .cornerRadius(2)
                                    .onHover { isHovering in
                                        if isHovering {
                                            hoverRow = row
                                            hoverCol = col
                                        }
                                    }
                                    .onTapGesture {
                                        onSelect(row, col)
                                        isPresented = false
                                        hoverRow = 0
                                        hoverCol = 0
                                    }
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(width: CGFloat(maxCols) * (cellSize + 2) + 16,
                   height: CGFloat(maxRows) * (cellSize + 2) + 50)
            .onAppear {
                hoverRow = 3
                hoverCol = 3
            }
        }
    }
}

// MARK: - 툴바 버튼
struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - 마크다운 액션
enum MarkdownAction {
    case heading(Int)
    case bold
    case italic
    case strikethrough
    case highlight
    case inlineCode
    case codeBlock
    case link
    case image
    case bulletList
    case numberedList
    case taskList
    case blockquote
    case horizontalRule
    case table(rows: Int, cols: Int)
    case mermaid
    case plantuml
    case inlineMath
    case blockMath

    // 삽입할 전체 텍스트
    var insertText: String {
        switch self {
        case .heading(let level):
            return String(repeating: "#", count: level) + " Heading \(level)\n"
        case .bold:
            return "**bold text**"
        case .italic:
            return "*italic text*"
        case .strikethrough:
            return "~~strikethrough~~"
        case .highlight:
            return "==highlighted=="
        case .inlineCode:
            return "`code`"
        case .codeBlock:
            return "```\ncode block\n```\n"
        case .link:
            return "[link text](https://example.com)"
        case .image:
            return "![alt text](image-url)"
        case .bulletList:
            return "- item 1\n- item 2\n- item 3\n"
        case .numberedList:
            return "1. item 1\n2. item 2\n3. item 3\n"
        case .taskList:
            return "- [ ] task 1\n- [ ] task 2\n- [x] completed task\n"
        case .blockquote:
            return "> quote text\n"
        case .horizontalRule:
            return "\n---\n"
        case .table(let rows, let cols):
            return generateTable(rows: rows, cols: cols)
        case .mermaid:
            return """
            ```mermaid
            graph TD
                A[Start] --> B{Decision}
                B -->|Yes| C[OK]
                B -->|No| D[Cancel]
            ```

            """
        case .plantuml:
            return """
            ```plantuml
            @startuml
            Alice -> Bob: Hello
            Bob --> Alice: Hi
            @enduml
            ```

            """
        case .inlineMath:
            return "$E = mc^2$"
        case .blockMath:
            return """
            $$
            \\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
            $$

            """
        }
    }

    // 테이블 생성
    private func generateTable(rows: Int, cols: Int) -> String {
        var result = ""

        // 헤더 행
        result += "|"
        for c in 1...cols {
            result += " Header \(c) |"
        }
        result += "\n"

        // 구분선
        result += "|"
        for _ in 1...cols {
            result += "----------|"
        }
        result += "\n"

        // 데이터 행 (rows > 1 인 경우에만)
        if rows > 1 {
            for r in 1...(rows - 1) {
                result += "|"
                for c in 1...cols {
                    result += " Cell \(r),\(c) |"
                }
                result += "\n"
            }
        }

        return result
    }

    // 레거시 지원 (prefix, suffix, wrapsSelection, defaultText)
    var prefix: String {
        switch self {
        case .heading(let level): return String(repeating: "#", count: level) + " "
        case .bold: return "**"
        case .italic: return "*"
        case .strikethrough: return "~~"
        case .highlight: return "=="
        case .inlineCode: return "`"
        case .codeBlock: return "```\n"
        case .link: return "["
        case .image: return "!["
        case .bulletList: return "- "
        case .numberedList: return "1. "
        case .taskList: return "- [ ] "
        case .blockquote: return "> "
        case .horizontalRule: return "\n---\n"
        case .table: return insertText
        case .mermaid: return insertText
        case .plantuml: return insertText
        case .inlineMath: return "$"
        case .blockMath: return "$$\n"
        }
    }

    var suffix: String {
        switch self {
        case .heading: return ""
        case .bold: return "**"
        case .italic: return "*"
        case .strikethrough: return "~~"
        case .highlight: return "=="
        case .inlineCode: return "`"
        case .codeBlock: return "\n```"
        case .link: return "](url)"
        case .image: return "](url)"
        case .bulletList, .numberedList, .taskList, .blockquote: return ""
        case .horizontalRule, .table, .mermaid, .plantuml: return ""
        case .inlineMath: return "$"
        case .blockMath: return "\n$$"
        }
    }

    var wrapsSelection: Bool {
        switch self {
        case .heading, .bulletList, .numberedList, .taskList, .blockquote,
             .horizontalRule, .table, .mermaid, .plantuml:
            return false
        default:
            return true
        }
    }

    var defaultText: String {
        switch self {
        case .heading: return "Heading"
        case .bold: return "bold text"
        case .italic: return "italic text"
        case .strikethrough: return "strikethrough"
        case .highlight: return "highlighted"
        case .inlineCode: return "code"
        case .codeBlock: return "code"
        case .link: return "link text"
        case .image: return "alt text"
        case .bulletList: return "list item"
        case .numberedList: return "list item"
        case .taskList: return "task item"
        case .blockquote: return "quote"
        case .inlineMath: return "E = mc^2"
        case .blockMath: return "\\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}"
        default: return ""
        }
    }
}

#Preview {
    ToolbarView { action in
        print("Action: \(action)")
    }
    .frame(width: 700)
}

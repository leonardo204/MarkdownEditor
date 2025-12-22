import SwiftUI

// 마크다운 편집 툴바
// 텍스트 포맷팅 및 삽입 버튼 제공

struct ToolbarView: View {
    var onAction: (MarkdownAction) -> Void

    var body: some View {
        HStack(spacing: 2) {
            // 헤딩
            Menu {
                Button("Heading 1 (⌘1)") { onAction(.heading(1)) }
                Button("Heading 2 (⌘2)") { onAction(.heading(2)) }
                Button("Heading 3 (⌘3)") { onAction(.heading(3)) }
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
            ToolbarButton(icon: "bold", tooltip: "Bold (⌘B)") {
                onAction(.bold)
            }
            ToolbarButton(icon: "italic", tooltip: "Italic (⌘I)") {
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
            ToolbarButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Inline Code (⌘`)") {
                onAction(.inlineCode)
            }
            ToolbarButton(icon: "rectangle.and.text.magnifyingglass", tooltip: "Code Block") {
                onAction(.codeBlock)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // 링크 및 이미지
            ToolbarButton(icon: "link", tooltip: "Link (⌘K)") {
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

            // 테이블
            ToolbarButton(icon: "tablecells", tooltip: "Table") {
                onAction(.table)
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
    case table
    case mermaid
    case plantuml
    case inlineMath
    case blockMath

    // 텍스트 삽입/래핑 정보
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
        case .horizontalRule: return "---\n"
        case .table: return """
            | Header 1 | Header 2 | Header 3 |
            |----------|----------|----------|
            | Cell 1   | Cell 2   | Cell 3   |

            """
        case .mermaid: return """
            ```mermaid
            graph TD
                A[Start] --> B{Decision}
                B -->|Yes| C[OK]
                B -->|No| D[Cancel]
            ```

            """
        case .plantuml: return """
            ```plantuml
            @startuml
            Alice -> Bob: Hello
            Bob --> Alice: Hi
            @enduml
            ```

            """
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

    // 선택된 텍스트를 래핑하는지 여부
    var wrapsSelection: Bool {
        switch self {
        case .heading, .bulletList, .numberedList, .taskList, .blockquote,
             .horizontalRule, .table, .mermaid, .plantuml:
            return false
        default:
            return true
        }
    }

    // 기본 텍스트 (선택이 없을 때)
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
    .frame(width: 600)
}

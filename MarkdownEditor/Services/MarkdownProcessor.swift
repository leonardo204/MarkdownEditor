import Foundation

// Markdown을 HTML로 변환하는 프로세서
// CommonMark + GFM + 확장 문법 지원

class MarkdownProcessor {

    // MARK: - 메인 변환 메서드
    func convertToHTML(_ markdown: String) -> String {
        var html = markdown

        // 1. 코드 블록 보호 (다른 변환의 영향을 받지 않도록)
        var codeBlocks: [String: String] = [:]
        html = protectCodeBlocks(html, storage: &codeBlocks)

        // 2. 인라인 코드 보호
        var inlineCodes: [String: String] = [:]
        html = protectInlineCode(html, storage: &inlineCodes)

        // 3. 블록 요소 변환
        html = convertHeadings(html)
        html = convertBlockquotes(html)
        html = convertHorizontalRules(html)
        html = convertLists(html)
        html = convertTables(html)

        // 4. 인라인 요소 변환
        html = convertBoldItalic(html)
        html = convertStrikethrough(html)
        html = convertLinks(html)
        html = convertImages(html)

        // 5. 확장 문법 변환
        html = convertFootnotes(html)
        html = convertHighlight(html)
        html = convertSuperscriptSubscript(html)

        // 6. 문단 변환
        html = convertParagraphs(html)

        // 7. 코드 블록 복원
        html = restoreCodeBlocks(html, storage: codeBlocks)
        html = restoreInlineCode(html, storage: inlineCodes)

        // 8. 수식 변환 (코드 복원 후)
        html = convertMath(html)

        return html
    }

    // MARK: - 코드 블록 보호/복원
    private func protectCodeBlocks(_ text: String, storage: inout [String: String]) -> String {
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }

        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for (index, match) in matches.reversed().enumerated() {
            guard let fullRange = Range(match.range, in: text),
                  let languageRange = Range(match.range(at: 1), in: text),
                  let codeRange = Range(match.range(at: 2), in: text) else { continue }

            let language = String(text[languageRange])
            let code = String(text[codeRange])
            let placeholder = "<!--CODEBLOCK_\(index)-->"

            // Mermaid 또는 PlantUML 다이어그램 처리
            let htmlBlock: String
            if language.lowercased() == "mermaid" {
                htmlBlock = "<div class=\"mermaid\">\(escapeHTML(code))</div>"
            } else if language.lowercased() == "plantuml" {
                htmlBlock = "<div class=\"plantuml\" data-code=\"\(escapeHTML(code).replacingOccurrences(of: "\n", with: "&#10;"))\">[PlantUML Diagram]</div>"
            } else {
                let langClass = language.isEmpty ? "" : " class=\"language-\(language)\""
                htmlBlock = "<pre><code\(langClass)>\(escapeHTML(code))</code></pre>"
            }

            storage[placeholder] = htmlBlock
            result = result.replacingCharacters(in: fullRange, with: placeholder)
        }

        return result
    }

    private func restoreCodeBlocks(_ text: String, storage: [String: String]) -> String {
        var result = text
        for (placeholder, html) in storage {
            result = result.replacingOccurrences(of: placeholder, with: html)
        }
        return result
    }

    // MARK: - 인라인 코드 보호/복원
    private func protectInlineCode(_ text: String, storage: inout [String: String]) -> String {
        let pattern = "`([^`]+)`"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }

        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for (index, match) in matches.reversed().enumerated() {
            guard let fullRange = Range(match.range, in: text),
                  let codeRange = Range(match.range(at: 1), in: text) else { continue }

            let code = String(text[codeRange])
            let placeholder = "<!--INLINECODE_\(index)-->"
            let htmlCode = "<code>\(escapeHTML(code))</code>"

            storage[placeholder] = htmlCode
            result = result.replacingCharacters(in: fullRange, with: placeholder)
        }

        return result
    }

    private func restoreInlineCode(_ text: String, storage: [String: String]) -> String {
        var result = text
        for (placeholder, html) in storage {
            result = result.replacingOccurrences(of: placeholder, with: html)
        }
        return result
    }

    // MARK: - 헤딩 변환
    private func convertHeadings(_ text: String) -> String {
        var result = text

        for level in (1...6).reversed() {
            let pattern = "^(\(String(repeating: "#", count: level)))\\s+(.+)$"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "<h\(level)>$2</h\(level)>"
                )
            }
        }

        return result
    }

    // MARK: - 인용구 변환
    private func convertBlockquotes(_ text: String) -> String {
        let pattern = "^>\\s?(.*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return text }

        var result = text
        var lines = result.components(separatedBy: "\n")
        var inBlockquote = false
        var blockquoteLines: [String] = []
        var processedLines: [String] = []

        for line in lines {
            if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let contentRange = Range(match.range(at: 1), in: line) {
                let content = String(line[contentRange])
                if !inBlockquote {
                    inBlockquote = true
                    blockquoteLines = []
                }
                blockquoteLines.append(content)
            } else {
                if inBlockquote {
                    processedLines.append("<blockquote>\(blockquoteLines.joined(separator: "<br>"))</blockquote>")
                    inBlockquote = false
                }
                processedLines.append(line)
            }
        }

        if inBlockquote {
            processedLines.append("<blockquote>\(blockquoteLines.joined(separator: "<br>"))</blockquote>")
        }

        return processedLines.joined(separator: "\n")
    }

    // MARK: - 수평선 변환
    private func convertHorizontalRules(_ text: String) -> String {
        let pattern = "^[-*_]{3,}\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "<hr>"
        )
    }

    // MARK: - 리스트 변환
    private func convertLists(_ text: String) -> String {
        var result = text

        // 체크박스 리스트
        let taskPattern = "^(\\s*)[-*+]\\s+\\[([ xX])\\]\\s+(.*)$"
        if let regex = try? NSRegularExpression(pattern: taskPattern, options: [.anchorsMatchLines]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1<li><input type=\"checkbox\" disabled$2>$3</li>"
            )
            // 체크 표시 처리
            result = result.replacingOccurrences(of: "disabled ", with: "disabled ")
            result = result.replacingOccurrences(of: "disabledx", with: "disabled checked")
            result = result.replacingOccurrences(of: "disabledX", with: "disabled checked")
        }

        // 순서 없는 리스트
        let ulPattern = "^(\\s*)[-*+]\\s+(.*)$"
        if let regex = try? NSRegularExpression(pattern: ulPattern, options: [.anchorsMatchLines]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<li>$2</li>"
            )
        }

        // 순서 있는 리스트
        let olPattern = "^(\\s*)\\d+\\.\\s+(.*)$"
        if let regex = try? NSRegularExpression(pattern: olPattern, options: [.anchorsMatchLines]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<li>$2</li>"
            )
        }

        // 연속된 <li> 태그를 <ul> 또는 <ol>로 래핑
        result = wrapListItems(result)

        return result
    }

    private func wrapListItems(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inList = false

        for line in lines {
            if line.hasPrefix("<li>") {
                if !inList {
                    result.append("<ul>")
                    inList = true
                }
                result.append(line)
            } else {
                if inList {
                    result.append("</ul>")
                    inList = false
                }
                result.append(line)
            }
        }

        if inList {
            result.append("</ul>")
        }

        return result.joined(separator: "\n")
    }

    // MARK: - 테이블 변환
    private func convertTables(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var tableLines: [String] = []
        var inTable = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                if !inTable {
                    inTable = true
                    tableLines = []
                }
                tableLines.append(trimmed)
            } else {
                if inTable {
                    result.append(convertTableLines(tableLines))
                    inTable = false
                    tableLines = []
                }
                result.append(line)
            }
        }

        if inTable {
            result.append(convertTableLines(tableLines))
        }

        return result.joined(separator: "\n")
    }

    private func convertTableLines(_ lines: [String]) -> String {
        guard lines.count >= 2 else { return lines.joined(separator: "\n") }

        var html = "<table>\n"

        // 헤더 행
        let headerCells = parseTableRow(lines[0])
        html += "<thead>\n<tr>\n"
        for cell in headerCells {
            html += "<th>\(cell)</th>\n"
        }
        html += "</tr>\n</thead>\n"

        // 구분선 건너뛰기 (lines[1])

        // 본문 행
        if lines.count > 2 {
            html += "<tbody>\n"
            for i in 2..<lines.count {
                let cells = parseTableRow(lines[i])
                html += "<tr>\n"
                for cell in cells {
                    html += "<td>\(cell)</td>\n"
                }
                html += "</tr>\n"
            }
            html += "</tbody>\n"
        }

        html += "</table>"
        return html
    }

    private func parseTableRow(_ row: String) -> [String] {
        var cells = row.components(separatedBy: "|")
        // 앞뒤 빈 요소 제거
        if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            cells.removeFirst()
        }
        if cells.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            cells.removeLast()
        }
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Bold/Italic 변환
    private func convertBoldItalic(_ text: String) -> String {
        var result = text

        // Bold + Italic (***text*** 또는 ___text___)
        let boldItalicPattern = "\\*\\*\\*([^*]+)\\*\\*\\*|___([^_]+)___"
        if let regex = try? NSRegularExpression(pattern: boldItalicPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<strong><em>$1$2</em></strong>"
            )
        }

        // Bold (**text** 또는 __text__)
        let boldPattern = "\\*\\*([^*]+)\\*\\*|__([^_]+)__"
        if let regex = try? NSRegularExpression(pattern: boldPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<strong>$1$2</strong>"
            )
        }

        // Italic (*text* 또는 _text_)
        let italicPattern = "\\*([^*]+)\\*|_([^_]+)_"
        if let regex = try? NSRegularExpression(pattern: italicPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<em>$1$2</em>"
            )
        }

        return result
    }

    // MARK: - 취소선 변환
    private func convertStrikethrough(_ text: String) -> String {
        let pattern = "~~([^~]+)~~"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "<del>$1</del>"
        )
    }

    // MARK: - 링크 변환
    private func convertLinks(_ text: String) -> String {
        let pattern = "\\[([^\\]]+)\\]\\(([^\\)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "<a href=\"$2\">$1</a>"
        )
    }

    // MARK: - 이미지 변환
    private func convertImages(_ text: String) -> String {
        let pattern = "!\\[([^\\]]+)\\]\\(([^\\)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "<img src=\"$2\" alt=\"$1\">"
        )
    }

    // MARK: - 각주 변환
    private func convertFootnotes(_ text: String) -> String {
        var result = text

        // 각주 참조: [^1]
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
        if let regex = try? NSRegularExpression(pattern: defPattern, options: [.anchorsMatchLines]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<div class=\"footnote\" id=\"fn$1\"><sup>$1</sup> $2 <a href=\"#fnref$1\">↩</a></div>"
            )
        }

        return result
    }

    // MARK: - 수식 변환
    private func convertMath(_ text: String) -> String {
        var result = text

        // 블록 수식 ($$...$$)
        let blockPattern = "\\$\\$([^$]+)\\$\\$"
        if let regex = try? NSRegularExpression(pattern: blockPattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<div class=\"math-block\">$1</div>"
            )
        }

        // 인라인 수식 ($...$)
        let inlinePattern = "\\$([^$]+)\\$"
        if let regex = try? NSRegularExpression(pattern: inlinePattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<span class=\"math-inline\">$1</span>"
            )
        }

        return result
    }

    // MARK: - 하이라이트 변환
    private func convertHighlight(_ text: String) -> String {
        let pattern = "==([^=]+)=="
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "<mark>$1</mark>"
        )
    }

    // MARK: - 위/아래 첨자 변환
    private func convertSuperscriptSubscript(_ text: String) -> String {
        var result = text

        // 위 첨자 (^text^)
        let supPattern = "\\^([^^]+)\\^"
        if let regex = try? NSRegularExpression(pattern: supPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<sup>$1</sup>"
            )
        }

        // 아래 첨자 (~text~) - 취소선과 구분하기 위해 단일 ~만 사용
        let subPattern = "~([^~]+)~"
        if let regex = try? NSRegularExpression(pattern: subPattern) {
            // 취소선(~~)이 아닌 경우만 변환
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let matchedText = String(result[range])
                if !matchedText.hasPrefix("~~") {
                    // 아래 첨자로 변환
                    if let contentRange = Range(match.range(at: 1), in: result) {
                        let content = String(result[contentRange])
                        result = result.replacingCharacters(in: range, with: "<sub>\(content)</sub>")
                    }
                }
            }
        }

        return result
    }

    // MARK: - 문단 변환
    private func convertParagraphs(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n\n")
        var result: [String] = []

        for block in lines {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // 이미 HTML 태그로 시작하는 경우 그대로 유지
            if trimmed.hasPrefix("<") {
                result.append(trimmed)
            } else {
                // 일반 텍스트는 <p> 태그로 래핑
                let paragraphContent = trimmed.replacingOccurrences(of: "\n", with: "<br>")
                result.append("<p>\(paragraphContent)</p>")
            }
        }

        return result.joined(separator: "\n")
    }

    // MARK: - HTML 이스케이프
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

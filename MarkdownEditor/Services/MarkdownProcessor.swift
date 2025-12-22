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
        var result = text
        var placeholderIndex = 0

        // 4개 백틱, 3개 백틱, 틸드 순으로 처리 (긴 것부터)
        let fencePatterns = [
            ("````", "````(\\w*)[ \\t]*\\n([\\s\\S]*?)\\n?````"),
            ("```", "```(\\w*)[ \\t]*\\n([\\s\\S]*?)\\n?```"),
            ("~~~", "~~~(\\w*)[ \\t]*\\n([\\s\\S]*?)\\n?~~~")
        ]

        for (_, pattern) in fencePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

            // 매칭을 반복적으로 찾아서 처리 (한 번에 하나씩)
            while true {
                let nsResult = result as NSString
                guard let match = regex.firstMatch(in: result, range: NSRange(location: 0, length: nsResult.length)) else {
                    break
                }

                guard let languageRange = Range(match.range(at: 1), in: result),
                      let codeRange = Range(match.range(at: 2), in: result) else { break }

                let language = String(result[languageRange])
                let code = String(result[codeRange])
                let placeholder = "<!--CODEBLOCK\(placeholderIndex)-->"

                // Mermaid 또는 PlantUML 다이어그램 처리
                let htmlBlock: String
                if language.lowercased() == "mermaid" {
                    htmlBlock = "<div class=\"mermaid\">\(code)</div>"
                } else if language.lowercased() == "plantuml" {
                    htmlBlock = "<div class=\"plantuml\" data-code=\"\(code.replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "\n", with: "&#10;"))\">[PlantUML Diagram]</div>"
                } else {
                    let langClass = language.isEmpty ? "" : " class=\"language-\(language)\""
                    htmlBlock = "<pre><code\(langClass)>\(escapeHTML(code))</code></pre>"
                }

                storage[placeholder] = htmlBlock

                // NSString으로 교체 (UTF-16 인덱스 일관성)
                result = nsResult.replacingCharacters(in: match.range, with: placeholder)
                placeholderIndex += 1
            }
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

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else { return text }

        // 매칭 정보를 미리 수집
        var replacements: [(range: NSRange, placeholder: String)] = []

        for (index, match) in matches.enumerated() {
            guard let codeRange = Range(match.range(at: 1), in: text) else { continue }

            let code = String(text[codeRange])
            let placeholder = "<!--INLINECODE\(index)-->"
            let htmlCode = "<code>\(escapeHTML(code))</code>"

            storage[placeholder] = htmlCode
            replacements.append((range: match.range, placeholder: placeholder))
        }

        // 뒤에서부터 교체
        var result = nsText as String
        for replacement in replacements.reversed() {
            let startIndex = result.index(result.startIndex, offsetBy: replacement.range.location)
            let endIndex = result.index(startIndex, offsetBy: replacement.range.length)
            result = result.replacingCharacters(in: startIndex..<endIndex, with: replacement.placeholder)
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

        // 체크박스 리스트 (data-type="task")
        let taskPattern = "^(\\s*)[-*+]\\s+\\[([ xX])\\]\\s+(.*)$"
        if let regex = try? NSRegularExpression(pattern: taskPattern, options: [.anchorsMatchLines]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<li data-type=\"task\"><input type=\"checkbox\" disabled$2> $3</li>"
            )
            // 체크 표시 처리
            result = result.replacingOccurrences(of: "disabled ", with: "disabled ")
            result = result.replacingOccurrences(of: "disabledx", with: "disabled checked")
            result = result.replacingOccurrences(of: "disabledX", with: "disabled checked")
        }

        // 순서 있는 리스트 (data-type="ordered") - 불릿보다 먼저 처리
        let olPattern = "^(\\s*)\\d+\\.\\s+(.*)$"
        if let regex = try? NSRegularExpression(pattern: olPattern, options: [.anchorsMatchLines]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<li data-type=\"ordered\">$2</li>"
            )
        }

        // 순서 없는 리스트 (data-type="bullet")
        let ulPattern = "^(\\s*)[-*+]\\s+(.*)$"
        if let regex = try? NSRegularExpression(pattern: ulPattern, options: [.anchorsMatchLines]) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<li data-type=\"bullet\">$2</li>"
            )
        }

        // 연속된 <li> 태그를 <ul> 또는 <ol>로 래핑
        result = wrapListItems(result)

        return result
    }

    private func wrapListItems(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var currentListType: String? = nil  // "ordered", "bullet", "task"

        for line in lines {
            if line.hasPrefix("<li") {
                // 리스트 타입 감지
                var listType = "bullet"
                if line.contains("data-type=\"ordered\"") {
                    listType = "ordered"
                } else if line.contains("data-type=\"task\"") {
                    listType = "task"
                } else if line.contains("data-type=\"bullet\"") {
                    listType = "bullet"
                }

                // 새로운 리스트 시작 또는 타입 변경
                if currentListType == nil {
                    // 리스트 시작 전 빈 줄 추가
                    if !result.isEmpty && result.last != "" {
                        result.append("")
                    }
                    let tag = listType == "ordered" ? "<ol>" : "<ul>"
                    result.append(tag)
                    currentListType = listType
                } else if currentListType != listType {
                    // 타입이 변경되면 현재 리스트 닫고 새로 시작
                    let closeTag = currentListType == "ordered" ? "</ol>" : "</ul>"
                    result.append(closeTag)
                    result.append("")
                    let openTag = listType == "ordered" ? "<ol>" : "<ul>"
                    result.append(openTag)
                    currentListType = listType
                }

                // data-type 속성 제거하고 추가
                let cleanLine = line
                    .replacingOccurrences(of: " data-type=\"ordered\"", with: "")
                    .replacingOccurrences(of: " data-type=\"bullet\"", with: "")
                    .replacingOccurrences(of: " data-type=\"task\"", with: "")
                result.append(cleanLine)
            } else {
                if currentListType != nil {
                    let closeTag = currentListType == "ordered" ? "</ol>" : "</ul>"
                    result.append(closeTag)
                    result.append("")
                    currentListType = nil
                }
                result.append(line)
            }
        }

        // 마지막 리스트 닫기
        if let listType = currentListType {
            let closeTag = listType == "ordered" ? "</ol>" : "</ul>"
            result.append(closeTag)
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

        // 구분선 찾기 (|---|---|와 같은 패턴)
        var separatorIndex = -1
        for (index, line) in lines.enumerated() {
            let trimmed = line.replacingOccurrences(of: " ", with: "")
            // |---|---| 또는 |:---|:---| 패턴 확인
            if trimmed.contains("|-") || trimmed.contains("-|") || trimmed.contains(":--") {
                separatorIndex = index
                break
            }
        }

        // 구분선이 없으면 일반 테이블로 처리
        if separatorIndex < 1 {
            return lines.joined(separator: "\n")
        }

        var html = "<table>\n"

        // 헤더 행 (구분선 이전의 모든 행)
        html += "<thead>\n"
        for i in 0..<separatorIndex {
            let headerCells = parseTableRow(lines[i])
            html += "<tr>\n"
            for cell in headerCells {
                html += "<th>\(cell)</th>\n"
            }
            html += "</tr>\n"
        }
        html += "</thead>\n"

        // 본문 행 (구분선 이후)
        if lines.count > separatorIndex + 1 {
            html += "<tbody>\n"
            for i in (separatorIndex + 1)..<lines.count {
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
        // 빈 줄로 블록 분리
        let blocks = text.components(separatedBy: "\n\n")
        var result: [String] = []

        // 블록 레벨 HTML 태그들 (<!--CODEBLOCK은 블록, <!--INLINECODE는 인라인)
        let blockTags = ["<table", "<ul", "<ol", "<blockquote", "<pre", "<h1", "<h2", "<h3", "<h4", "<h5", "<h6", "<hr", "<div", "<!--codeblock"]

        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // 블록 레벨 HTML 태그로 시작하는 경우
            let lowercased = trimmed.lowercased()
            let isBlockElement = blockTags.contains { lowercased.hasPrefix($0) }

            if isBlockElement {
                // 블록 요소는 그대로 유지 (테이블 내 줄바꿈은 변환하지 않음)
                result.append(trimmed)
            } else {
                // 일반 텍스트/인라인 요소는 <p> 태그로 래핑하고 줄바꿈을 <br>로 변환
                let paragraphContent = trimmed.replacingOccurrences(of: "\n", with: "<br>\n")
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

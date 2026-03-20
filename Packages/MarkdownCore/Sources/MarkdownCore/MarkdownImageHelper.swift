import Foundation

public enum MarkdownImageHelper {
    public static func encodeImagePath(_ path: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "()")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }

    // HTML 내 로컬 이미지 src를 base64 data URI로 변환
    public static func embedLocalImages(in html: String, documentURL: URL) -> String {
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

    /// QL extension용: 로컬 이미지를 placeholder로 치환 (샌드박스로 파일 접근 불가)
    public static func replaceLocalImagesWithPlaceholder(in html: String) -> String {
        let pattern = #"<img\s+([^>]*?)src="([^"]+)"([^>]*?)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))
        guard !matches.isEmpty else { return html }

        var result = ""
        var lastEnd = 0

        for match in matches {
            let fullRange = match.range(at: 0)
            let src = nsHTML.substring(with: match.range(at: 2))

            // 원격 이미지와 data URI는 그대로 유지
            if src.hasPrefix("data:") || src.hasPrefix("http://") || src.hasPrefix("https://") {
                result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location + fullRange.length - lastEnd))
                lastEnd = fullRange.location + fullRange.length
                continue
            }

            // 로컬 이미지 → placeholder
            let fileName = (src as NSString).lastPathComponent.removingPercentEncoding ?? (src as NSString).lastPathComponent
            result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
            result += """
            <div style="display:inline-flex;align-items:center;gap:6px;padding:8px 12px;border-radius:6px;background:rgba(128,128,128,0.1);border:1px dashed rgba(128,128,128,0.3);color:rgba(128,128,128,0.7);font-size:13px;">\
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">\
            <rect x="3" y="3" width="18" height="18" rx="2"/>\
            <circle cx="8.5" cy="8.5" r="1.5"/>\
            <path d="M21 15l-5-5L5 21"/>\
            </svg>\
            \(fileName)</div>
            """
            lastEnd = fullRange.location + fullRange.length
        }

        if lastEnd < nsHTML.length {
            result += nsHTML.substring(from: lastEnd)
        }

        return result
    }

    public static func markdownImageSnippet(imageURL: URL, docDir: URL) -> String {
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

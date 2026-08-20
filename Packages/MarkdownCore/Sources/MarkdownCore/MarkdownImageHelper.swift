import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum MarkdownImageHelper {
    /// me-asset:// 스킴으로 서빙 가능한 이미지 확장자 → MIME 매핑.
    /// rewriteLocalImages와 LocalImageSchemeHandler가 **반드시 공유**해야 한다.
    /// (재작성 대상과 서빙 대상이 어긋나면 해당 이미지가 조용히 깨진다)
    public static let schemeImageMIMETypes: [String: String] = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "jfif": "image/jpeg",
        "gif": "image/gif",
        "svg": "image/svg+xml",
        "webp": "image/webp",
        "bmp": "image/bmp",
        "tiff": "image/tiff",
        "tif": "image/tiff",
        "heic": "image/heic",
        "heif": "image/heif",
        "avif": "image/avif",
        "ico": "image/x-icon"
    ]

    public static func encodeImagePath(_ path: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        // "&"를 인코딩하지 않으면 HTML 속성 안에서 "&copy" 등이 문자 참조로 해석된다
        allowed.remove(charactersIn: "()&")
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

            // 파일 읽기 → base64 임베딩 시도
            let newSrc: String
            if FileManager.default.fileExists(atPath: imageURL.path),
               let data = try? Data(contentsOf: imageURL) {
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
                newSrc = "data:\(mime);base64,\(data.base64EncodedString())"
            } else {
                // 샌드박스로 파일 읽기 실패 → 절대 file:// URL로 변환 (WKWebView가 직접 로드)
                newSrc = imageURL.absoluteString
            }

            result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
            let beforeSrc = nsHTML.substring(with: match.range(at: 1))
            let afterSrc = nsHTML.substring(with: match.range(at: 3))
            result += "<img \(beforeSrc)src=\"\(newSrc)\"\(afterSrc)>"
            lastEnd = fullRange.location + fullRange.length
        }

        // 마지막 match 이후 나머지
        if lastEnd < nsHTML.length {
            result += nsHTML.substring(from: lastEnd)
        }

        return result
    }

    // HTML 내 로컬 이미지 src를 me-asset:// 커스텀 스킴으로 재작성.
    // base64 인라인(embedLocalImages) 대비 HTML 크기가 대폭 줄고,
    // LocalImageSchemeHandler가 필요한 시점에만 파일을 읽어 서빙한다.
    //
    // file:// 폴백은 두지 않는다 — loadHTMLString으로 로드된 페이지에서는
    // WebKit이 file:// 서브리소스를 CSP와 무관하게 차단하므로 절대 렌더링되지 않는다.
    // 대신 해석 실패한 이미지는 경로를 노출하는 placeholder로 치환하고 개수를 반환한다.
    // - Returns: 재작성된 HTML과 해석 실패한 이미지 수(권한 요청 트리거 판단용)
    public static func rewriteLocalImages(in html: String, documentURL: URL) -> (html: String, unresolvedCount: Int) {
        let docDir = documentURL.deletingLastPathComponent()
        let pattern = #"<img\s+([^>]*?)src="([^"]+)"([^>]*?)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return (html, 0) }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))
        guard !matches.isEmpty else { return (html, 0) }

        // 원본에서 조각별로 조립 (인덱스 어긋남 방지)
        var result = ""
        var lastEnd = 0
        var unresolvedCount = 0

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
                imageURL = docDir.appendingPathComponent(decoded).standardized
            }

            let newSrc: String
            var sizeAttrs = ""
            if FileManager.default.isReadableFile(atPath: imageURL.path) {
                if schemeImageMIMETypes[imageURL.pathExtension.lowercased()] != nil {
                    // 핸들러가 서빙 가능 → 커스텀 스킴으로 참조 (파일 내용은 읽지 않음)
                    // 절대경로가 "/"로 시작하므로 결과는 me-asset:///Users/... 형태
                    newSrc = "me-asset://" + encodeImagePath(imageURL.path)
                    // 레이지 로드 전에도 높이가 확정되도록 픽셀 크기를 주입 (헤더만 읽음).
                    // 원본 태그에 width/height가 있으면 존중해 건드리지 않는다.
                    let hasSizeAttr = (nsHTML.substring(with: match.range(at: 1))
                                       + nsHTML.substring(with: match.range(at: 3)))
                        .range(of: #"(?i)\b(width|height)\s*="#, options: .regularExpression) != nil
                    if !hasSizeAttr, let size = pixelSize(of: imageURL) {
                        sizeAttrs = " width=\"\(size.width)\" height=\"\(size.height)\""
                    }
                } else if let data = try? Data(contentsOf: imageURL) {
                    // 핸들러 화이트리스트 밖의 확장자 → 기존 base64 인라인으로 폴백.
                    // (스킴으로 넘기면 핸들러가 거부해 이미지가 깨지므로 렌더링 회귀 방지용)
                    // MIME은 확장자 기반으로 결정한다 — png 하드코딩은 실제 포맷과 어긋난다.
                    // 이 분기는 확장자가 schemeImageMIMETypes에 없을 때만 도달하므로
                    // 맵 조회만으로는 항상 nil이다 → UTType으로 실제 MIME을 유도한다(jp2/psd 등).
                    let ext = imageURL.pathExtension.lowercased()
                    let mime = schemeImageMIMETypes[ext]
                        ?? UTType(filenameExtension: ext)?.preferredMIMEType
                        ?? "image/png"
                    newSrc = "data:\(mime);base64,\(data.base64EncodedString())"
                } else {
                    // 읽기 가능 판정 후 실제 읽기 실패 → 해석 불가
                    result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
                    result += unresolvedPlaceholder(for: imageURL)
                    unresolvedCount += 1
                    lastEnd = fullRange.location + fullRange.length
                    continue
                }
            } else {
                // 파일이 없거나 샌드박스로 접근 불가 → placeholder + 개수 집계
                result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
                result += unresolvedPlaceholder(for: imageURL)
                unresolvedCount += 1
                lastEnd = fullRange.location + fullRange.length
                continue
            }

            result += nsHTML.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
            let beforeSrc = nsHTML.substring(with: match.range(at: 1))
            let afterSrc = nsHTML.substring(with: match.range(at: 3))
            // 원본 태그에 이미 loading 속성이 있으면 중복 주입하지 않는다 (뒤 속성이 무시되는 것과 별개로 마크업 오염 방지)
            let hasLoadingAttr = (beforeSrc + afterSrc).range(of: #"(?i)\bloading\s*="#, options: .regularExpression) != nil
            let extraAttrs = hasLoadingAttr ? "" : " loading=\"lazy\" decoding=\"async\""
            result += "<img \(beforeSrc)src=\"\(newSrc)\"\(extraAttrs)\(sizeAttrs)\(afterSrc)>"
            lastEnd = fullRange.location + fullRange.length
        }

        // 마지막 match 이후 나머지
        if lastEnd < nsHTML.length {
            result += nsHTML.substring(from: lastEnd)
        }

        return (result, unresolvedCount)
    }

    // 픽셀 크기 캐시: path → (수정시각, 파일크기, 픽셀크기)
    // 프리뷰는 편집할 때마다 갱신되는데 그때마다 이미지 수십 장의 헤더를 다시 여는 것을 막는다.
    // 파일이 교체되면 mtime/size가 달라져 자동으로 무효화된다.
    //
    // 스레드 계약: rewriteLocalImages는 메인 스레드에서만 호출된다(프리뷰 갱신 경로).
    // 다른 스레드에서 호출하려면 이 캐시에 동기화를 추가해야 한다.
    private struct ImageSizeCacheEntry {
        let modified: Date?
        let fileSize: Int?
        let size: (width: Int, height: Int)
    }
    private static var pixelSizeCache: [String: ImageSizeCacheEntry] = [:]

    /// 이미지의 픽셀 크기를 헤더만 읽어 얻는다.
    /// 전체 디코드를 하지 않으므로(kCGImageSourceShouldCache=false) 비용이 매우 낮다.
    /// 레이지 로딩 이미지에 width/height를 부여해 로드 전에도 레이아웃 높이를 확정하기 위한 용도 —
    /// 이게 없으면 이미지가 하나씩 로드될 때마다 scrollHeight가 변해 퍼센트 동기화가 흔들리고 팝인이 생긴다.
    private static func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        let path = url.path
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let modified = attrs?[.modificationDate] as? Date
        let fileSize = attrs?[.size] as? Int

        if let cached = pixelSizeCache[path],
           cached.modified == modified,
           cached.fileSize == fileSize {
            return cached.size
        }

        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, options as CFDictionary) as? [CFString: Any],
              let rawWidth = props[kCGImagePropertyPixelWidth] as? Int,
              let rawHeight = props[kCGImagePropertyPixelHeight] as? Int,
              rawWidth > 0, rawHeight > 0 else { return nil }

        // EXIF orientation 5~8은 90/270도 회전이라 표시 크기가 전치된다.
        // 반영하지 않으면 회전된 사진마다 주입 크기가 뒤바뀌어 로드 시 큰 리플로우가 발생하고
        // width/height 주입의 목적(레이아웃 고정)이 무효화된다.
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        let isTransposed = (5...8).contains(orientation)
        let size = isTransposed ? (width: rawHeight, height: rawWidth) : (width: rawWidth, height: rawHeight)

        pixelSizeCache[path] = ImageSizeCacheEntry(modified: modified, fileSize: fileSize, size: size)
        return size
    }

    /// HTML 속성/텍스트에 안전하게 넣기 위한 이스케이프
    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// 해석 실패한 이미지용 placeholder.
    /// 사용자가 경로 오류를 스스로 진단할 수 있도록 파일명과 시도한 전체 경로를 함께 보여준다.
    private static func unresolvedPlaceholder(for imageURL: URL) -> String {
        // URL.path / lastPathComponent는 이미 퍼센트 디코딩된 값이다.
        // 여기서 removingPercentEncoding을 다시 걸면 리터럴 "%20"을 포함한
        // 실제 파일명이 공백으로 왜곡되므로 재적용하지 않는다.
        let fileName = escapeHTML(imageURL.lastPathComponent)
        let fullPath = escapeHTML(imageURL.path)
        // 인라인 이미지가 문단을 깨지 않도록 span으로 감싼다 (display는 inline-flex 유지)
        return """
        <span style="display:inline-flex;align-items:flex-start;gap:6px;padding:8px 12px;border-radius:6px;background:rgba(128,128,128,0.1);border:1px dashed rgba(128,128,128,0.3);color:rgba(128,128,128,0.75);font-size:13px;max-width:100%;">\
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;margin-top:2px;">\
        <rect x="3" y="3" width="18" height="18" rx="2"/>\
        <circle cx="8.5" cy="8.5" r="1.5"/>\
        <path d="M21 15l-5-5L5 21"/>\
        </svg>\
        <span style="word-break:break-all;"><strong>\(fileName)</strong><br>\
        <span style="font-size:11px;opacity:0.8;">이미지를 찾을 수 없음: \(fullPath)</span></span></span>
        """
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

import Foundation

/// 프리뷰가 CDN 대신 사용하는 번들 내 웹 리소스 접근 지점.
/// (CDN 콜드 로드가 초기 렌더의 대부분을 차지해 번들 서빙으로 대체)
public enum BundledWebResources {
    /// 서빙을 허용하는 파일명 화이트리스트.
    /// 여기 없는 이름은 번들에 실제로 존재하더라도 서빙하지 않는다.
    public static let allowedFileNames: Set<String> = [
        "highlight.min.js",
        "katex.min.js",
        "auto-render.min.js",
        "mermaid.min.js",
        "pako.min.js",
        // 폰트가 번들에 없어 현재 프리뷰는 이 파일을 쓰지 않는다.
        // (상대경로 url(fonts/...) 참조가 전부 실패하므로 CDN에서 논블로킹으로 로드한다)
        "katex.min.css",
        "atom-one-dark.min.css",
        "atom-one-light.min.css"
    ]

    /// 확장자 → MIME 매핑
    public static let mimeTypes: [String: String] = [
        "js": "application/javascript",
        "css": "text/css",
        "woff": "font/woff",
        "woff2": "font/woff2",
        "ttf": "font/ttf",
        "otf": "font/otf"
    ]

    /// 파일명으로 번들 리소스 URL을 조회한다.
    /// 경로 탈출을 막기 위해 "/" 또는 ".."가 포함된 이름과
    /// 화이트리스트 밖의 이름은 거부한다(nil 반환).
    public static func url(forFileName name: String) -> URL? {
        guard !name.isEmpty,
              !name.contains("/"),
              !name.contains(".."),
              allowedFileNames.contains(name) else { return nil }

        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        return Bundle.module.url(forResource: base, withExtension: ext)
    }

    /// 해당 리소스가 실제로 번들에 존재하는지 확인한다.
    /// 호출부(PreviewView)는 이 결과가 true인 리소스만 CDN에서 번들로 교체한다.
    public static func isAvailable(_ name: String) -> Bool {
        url(forFileName: name) != nil
    }
}

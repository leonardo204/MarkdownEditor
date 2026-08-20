import Foundation
import WebKit
import MarkdownCore

// 프리뷰 리소스를 온디맨드로 서빙하는 커스텀 URL 스킴 핸들러
//
// 두 개의 라우트를 처리한다:
//  1. me-asset:///absolute/path  → 로컬 이미지 (base64 인라인 대신 참조 → HTML 크기 축소 + 캐시 활용)
//  2. me-asset://bundle/<파일명>  → 번들에 포함된 JS/CSS (CDN 콜드 로드 제거)
final class LocalImageSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "me-asset"

    /// 번들 리소스 라우트를 나타내는 host
    private static let bundleHost = "bundle"

    // 이미지 서빙 허용 확장자 → MIME 매핑. MarkdownImageHelper와 공유하여
    // 재작성 대상과 서빙 대상이 어긋나지 않도록 한다 (화이트리스트 외 요청은 거부).
    private static var imageMIMETypes: [String: String] { MarkdownImageHelper.schemeImageMIMETypes }

    // 진행 중인 task 추적 — stop된 task에 콜백을 호출하면 WebKit이 NSException을 던진다.
    // 메인 큐에서만 접근한다.
    private var activeTasks = Set<ObjectIdentifier>()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskID = ObjectIdentifier(urlSchemeTask)
        activeTasks.insert(taskID)

        guard let url = urlSchemeTask.request.url, !url.path.isEmpty else {
            DebugLogger.shared.log("[me-asset] 잘못된 URL: \(urlSchemeTask.request.url?.absoluteString ?? "nil")")
            finish(task: urlSchemeTask, id: taskID, error: URLError(.badURL))
            return
        }

        if url.host?.lowercased() == Self.bundleHost {
            serveBundledResource(url: url, task: urlSchemeTask, id: taskID)
        } else {
            serveLocalImage(url: url, task: urlSchemeTask, id: taskID)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        activeTasks.remove(ObjectIdentifier(urlSchemeTask))
    }

    // MARK: - 라우트: 로컬 이미지

    private func serveLocalImage(url: URL, task: WKURLSchemeTask, id: ObjectIdentifier) {
        // url.path는 퍼센트 디코딩된 절대 경로
        let path = url.path
        let ext = (path as NSString).pathExtension.lowercased()
        guard let mimeType = Self.imageMIMETypes[ext] else {
            DebugLogger.shared.log("[me-asset] 지원하지 않는 확장자 '\(ext)': \(path)")
            finish(task: task, id: id, error: URLError(.unsupportedURL))
            return
        }

        respond(task: task, id: id, url: url, filePath: path, mimeType: mimeType, textEncoding: nil)
    }

    // MARK: - 라우트: 번들 웹 리소스

    private func serveBundledResource(url: URL, task: WKURLSchemeTask, id: ObjectIdentifier) {
        // me-asset://bundle/highlight.min.js → path == "/highlight.min.js"
        // 앞의 "/"를 제거한 뒤 반드시 단일 파일명이어야 한다.
        let name = String(url.path.dropFirst())

        // 경로 탈출 차단: 하위 경로("/" 포함)나 상위 참조("..")는 거부한다.
        // (번들에 fonts 하위 디렉토리가 없으므로 1단계 하위 경로도 허용하지 않는다)
        guard !name.isEmpty, !name.contains("/"), !name.contains("..") else {
            DebugLogger.shared.log("[me-asset] 번들 경로 탈출 시도 거부: \(url.path)")
            finish(task: task, id: id, error: URLError(.unsupportedURL))
            return
        }

        // 화이트리스트 + 실제 번들 존재 여부는 BundledWebResources가 함께 검증한다
        guard let fileURL = BundledWebResources.url(forFileName: name) else {
            DebugLogger.shared.log("[me-asset] 번들 리소스 없음/미허용: \(name)")
            finish(task: task, id: id, error: URLError(.fileDoesNotExist))
            return
        }

        let ext = (name as NSString).pathExtension.lowercased()
        guard let mimeType = BundledWebResources.mimeTypes[ext] else {
            DebugLogger.shared.log("[me-asset] 번들 리소스 MIME 미정의: \(name)")
            finish(task: task, id: id, error: URLError(.unsupportedURL))
            return
        }

        // JS/CSS는 인코딩을 명시하지 않으면 WebKit이 추측해 비ASCII가 깨질 수 있다
        let textEncoding = (ext == "js" || ext == "css") ? "utf-8" : nil
        respond(task: task, id: id, url: url, filePath: fileURL.path, mimeType: mimeType, textEncoding: textEncoding)
    }

    // MARK: - 공통 응답

    private func respond(task: WKURLSchemeTask,
                         id: ObjectIdentifier,
                         url: URL,
                         filePath: String,
                         mimeType: String,
                         textEncoding: String?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let data = FileManager.default.contents(atPath: filePath)

            DispatchQueue.main.async {
                guard self.activeTasks.contains(id) else { return }

                guard let data else {
                    DebugLogger.shared.log("[me-asset] 파일 읽기 실패 (없거나 권한 없음): \(filePath)")
                    self.finish(task: task, id: id, error: URLError(.fileDoesNotExist))
                    return
                }

                let response = URLResponse(
                    url: url,
                    mimeType: mimeType,
                    expectedContentLength: data.count,
                    textEncodingName: textEncoding
                )

                task.didReceive(response)
                guard self.activeTasks.contains(id) else { return }
                task.didReceive(data)
                guard self.activeTasks.contains(id) else { return }
                task.didFinish()
                self.activeTasks.remove(id)
            }
        }
    }

    private func finish(task: WKURLSchemeTask, id: ObjectIdentifier, error: Error) {
        guard activeTasks.contains(id) else { return }
        activeTasks.remove(id)
        task.didFailWithError(error)
    }
}

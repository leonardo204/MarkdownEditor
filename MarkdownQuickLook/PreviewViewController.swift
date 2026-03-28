//
//  PreviewViewController.swift
//  MarkdownQuickLook
//
//  Created by zerolive on 3/6/26.
//

import Cocoa
import Quartz
import WebKit
import MarkdownCore

class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!
    private static let appGroupID = "group.com.zerolive.MarkdownEditor"
    private static let sizeWidthKey = "quickLookWidth"
    private static let sizeHeightKey = "quickLookHeight"
    private static let defaultSize = NSSize(width: 800, height: 600)

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 저장된 사이즈 복원 또는 기본값 사용
        let savedSize = Self.loadSavedSize()
        preferredContentSize = savedSize

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        view.addSubview(webView)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        // 현재 뷰 사이즈 저장
        let size = view.frame.size
        if size.width > 100 && size.height > 100 {
            Self.saveSize(size)
        }
    }

    private static func loadSavedSize() -> NSSize {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return defaultSize }
        let w = defaults.double(forKey: sizeWidthKey)
        let h = defaults.double(forKey: sizeHeightKey)
        if w > 100 && h > 100 {
            return NSSize(width: w, height: h)
        }
        return defaultSize
    }

    private static func saveSize(_ size: NSSize) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(size.width, forKey: sizeWidthKey)
        defaults.set(size.height, forKey: sizeHeightKey)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        // QL 시스템 제공 보안 스코프 활성화
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let markdown = try String(contentsOf: url, encoding: .utf8)

        // Detect theme from view appearance
        let isDark: Bool = {
            let appearance = self.view.effectiveAppearance
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }()
        let theme: PreviewTheme = isDark ? .dark : .light

        // Check premium status and preview toggle via App Group
        let groupDefaults = UserDefaults(suiteName: "group.com.zerolive.MarkdownEditor")
        let isPremium = groupDefaults?.bool(forKey: "isPremium") ?? false
        let showPreviewPane = groupDefaults?.object(forKey: "showPreviewPane") as? Bool ?? true

        let html: String
        if isPremium && showPreviewPane {
            // Premium + Preview ON: Full MarkdownCore rendering
            let processor = MarkdownProcessor()
            var content = processor.convertToHTML(markdown)
            // QL extension 샌드박스 제약: 로컬 이미지 접근 불가 → placeholder 표시
            content = MarkdownImageHelper.replaceLocalImagesWithPlaceholder(in: content)
            let template = HTMLTemplate()
            html = template.wrapHTML(
                content: content,
                theme: theme,
                useLocalResources: false
            )
        } else {
            // Banner + raw markdown 표시
            let escapedMarkdown = markdown
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")

            let fileName = url.lastPathComponent
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")

            let bgColor = isDark ? "#1e1e1e" : "#ffffff"
            let textColor = isDark ? "#d4d4d4" : "#1e1e1e"
            let bannerBg = isDark ? "#2d2d30" : "#f0f0f0"

            // 배너 메시지 결정
            let bannerMessage: String
            if !isPremium {
                // 미구매자
                bannerMessage = """
                    Markdown Editor Premium을 구매하시면 Mermaid, KaTeX, 코드 하이라이팅이 포함된 풀 미리보기를 사용할 수 있습니다.<br>
                    <span style="font-size: 11px; opacity: 0.7;">(앱 실행 → 설정 → Premium 탭에서 구매)</span>
                    <div style="margin-top: 8px; font-size: 11px; opacity: 0.6;">Purchase Premium in Markdown Editor (Settings → Premium) to unlock full preview with Mermaid, KaTeX, and code highlighting.</div>
                """
            } else {
                // 프리미엄 구매자 + Preview OFF
                bannerMessage = """
                    미리보기가 꺼져 있습니다. 설정에서 Preview를 켜면 렌더링된 미리보기를 볼 수 있습니다.<br>
                    <span style="font-size: 11px; opacity: 0.7;">(앱 실행 → Editor 헤더의 Preview 토글 또는 설정 → General)</span>
                    <div style="margin-top: 8px; font-size: 11px; opacity: 0.6;">Preview is disabled. Enable it in Markdown Editor (Editor header Preview toggle or Settings → General) to see rendered preview.</div>
                """
            }

            html = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <style>
                body {
                    background: \(bgColor);
                    color: \(textColor);
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    padding: 20px;
                    margin: 0;
                }
                .banner {
                    background: \(bannerBg);
                    border-radius: 8px;
                    padding: 16px;
                    margin-bottom: 20px;
                    text-align: center;
                    font-size: 13px;
                }
                .banner strong { display: block; margin-bottom: 4px; }
                pre {
                    white-space: pre-wrap;
                    word-wrap: break-word;
                    font-family: 'SF Mono', Menlo, monospace;
                    font-size: 13px;
                    line-height: 1.5;
                }
                .filename {
                    font-size: 11px;
                    color: gray;
                    margin-bottom: 12px;
                }
            </style>
            </head>
            <body>
                <div class="banner">
                    \(bannerMessage)
                </div>
                <div class="filename">\(fileName)</div>
                <pre>\(escapedMarkdown)</pre>
            </body>
            </html>
            """
        }

        await MainActor.run {
            webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
        }
    }
}

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

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        view.addSubview(webView)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let markdown = try String(contentsOf: url, encoding: .utf8)

        // Detect theme from view appearance
        let isDark: Bool = {
            let appearance = self.view.effectiveAppearance
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }()
        let theme: PreviewTheme = isDark ? .dark : .light

        // Check premium status via App Group
        let isPremium = UserDefaults(suiteName: "group.com.zerolive.MarkdownEditor")?.bool(forKey: "isPremium") ?? false

        let html: String
        if isPremium {
            // Full MarkdownCore rendering
            let processor = MarkdownProcessor()
            let content = processor.convertToHTML(markdown)
            let template = HTMLTemplate()
            html = template.wrapHTML(
                content: content,
                theme: theme,
                useLocalResources: false
            )
        } else {
            // Basic preview with upgrade banner
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
                    Markdown Editor Premium을 구매하시면 Mermaid, KaTeX, 코드 하이라이팅이 포함된 풀 미리보기를 사용할 수 있습니다.<br>
                    <span style="font-size: 11px; opacity: 0.7;">(앱 실행 → 설정 → Premium 탭에서 구매)</span>
                    <div style="margin-top: 8px; font-size: 11px; opacity: 0.6;">Purchase Premium in Markdown Editor (Settings → Premium) to unlock full preview with Mermaid, KaTeX, and code highlighting.</div>
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

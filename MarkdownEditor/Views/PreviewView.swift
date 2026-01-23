import SwiftUI
import WebKit

// WKWebView를 래핑한 Markdown 미리보기 뷰
// HTML 렌더링, Mermaid 다이어그램, 수식 지원

struct PreviewView: NSViewRepresentable {
    var htmlContent: String
    var theme: PreviewTheme
    var scrollSyncManager: ScrollSyncManager?

    // HTML 변경 감지를 위한 키
    private var htmlKey: String {
        "\(htmlContent.hashValue)_\(theme.rawValue)"
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // 로컬 파일 접근 허용
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // JavaScript 활성화
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // 스크롤 이벤트를 Swift로 전달하기 위한 스크립트 메시지 핸들러
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "scrollHandler")
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // 배경 투명 설정
        webView.setValue(false, forKey: "drawsBackground")

        // 스크롤 동기화 매니저에 등록
        scrollSyncManager?.previewWebView = webView
        context.coordinator.scrollSyncManager = scrollSyncManager

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // 스크롤 동기화 매니저 업데이트
        scrollSyncManager?.previewWebView = webView
        context.coordinator.scrollSyncManager = scrollSyncManager

        // HTML이 변경된 경우에만 다시 로드
        // 편집으로 인한 업데이트 시에는 스크롤 복원하지 않음
        // (에디터 스크롤 시에만 ScrollSyncManager가 동기화 처리)
        let currentKey = htmlKey
        if context.coordinator.lastHtmlKey != currentKey {
            context.coordinator.lastHtmlKey = currentKey

            let fullHTML = wrapHTML(content: htmlContent, theme: theme)
            webView.loadHTMLString(fullHTML, baseURL: Bundle.main.resourceURL)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func wrapHTML(content: String, theme: PreviewTheme) -> String {
        let themeClass = theme == .dark ? "dark" : "light"
        let mermaidTheme = theme.mermaidTheme

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline' data: blob: https: http:; img-src 'self' data: blob: https: http:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:;">
            <style>
                \(getCSS(for: theme))
            </style>
            <!-- Highlight.js for code highlighting -->
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/\(theme == .dark ? "atom-one-dark" : "atom-one-light").min.css">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>

            <!-- KaTeX for math -->
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"></script>

            <!-- Mermaid for diagrams (v11.3+ supports markdown strings for line breaks) -->
            <script src="https://cdn.jsdelivr.net/npm/mermaid@11.3/dist/mermaid.min.js"></script>

            <!-- Pako for PlantUML compression -->
            <script src="https://cdn.jsdelivr.net/npm/pako@2.1.0/dist/pako.min.js"></script>
        </head>
        <body class="\(themeClass)">
            <div class="markdown-body">
                \(content)
            </div>
            <script>
                // 모든 렌더링은 DOMContentLoaded 후에 수행
                document.addEventListener('DOMContentLoaded', async function() {
                    // 코드 하이라이팅
                    if (typeof hljs !== 'undefined') {
                        document.querySelectorAll('pre code').forEach((block) => {
                            hljs.highlightElement(block);
                        });
                    }

                    // Mermaid 다이어그램 렌더링
                    if (typeof mermaid !== 'undefined') {
                        try {
                            mermaid.initialize({
                                startOnLoad: false,
                                theme: '\(mermaidTheme)',
                                securityLevel: 'loose',
                                flowchart: {
                                    htmlLabels: true,
                                    useMaxWidth: true
                                }
                            });
                            await mermaid.run({
                                querySelector: '.mermaid'
                            });
                        } catch (e) {
                            // Mermaid 렌더링 오류 무시
                        }
                    }

                    // KaTeX 수식 렌더링
                    if (typeof renderMathInElement !== 'undefined') {
                        renderMathInElement(document.body, {
                            delimiters: [
                                {left: '$$', right: '$$', display: true},
                                {left: '$', right: '$', display: false}
                            ],
                            throwOnError: false
                        });
                    }

                    // PlantUML 다이어그램 처리 (Kroki 서비스 사용 - 한글 지원)
                    document.querySelectorAll('.plantuml').forEach(async (element) => {
                        const code = element.getAttribute('data-code');
                        if (code) {
                            try {
                                // Kroki 서비스용 인코딩 (URL-safe base64)
                                const encoded = krokiEncode(code);
                                const img = document.createElement('img');
                                img.src = 'https://kroki.io/plantuml/svg/' + encoded;
                                img.alt = 'PlantUML Diagram';
                                img.style.maxWidth = '100%';
                                img.onerror = function() {
                                    element.innerHTML = '<div class="diagram-error">PlantUML 렌더링 실패</div>';
                                };
                                element.innerHTML = '';
                                element.appendChild(img);
                            } catch (e) {
                                element.innerHTML = '<div class="diagram-error">PlantUML 렌더링 오류: ' + e.message + '</div>';
                            }
                        }
                    });

                });

                // Kroki 인코딩 함수 (URL-safe base64 of deflated content)
                function krokiEncode(text) {
                    if (typeof pako !== 'undefined') {
                        const data = new TextEncoder().encode(text);
                        const compressed = pako.deflate(data, { level: 9 });
                        // URL-safe base64 인코딩
                        const base64 = btoa(String.fromCharCode.apply(null, compressed));
                        return base64.replace(/[+]/g, '-').replace(/[/]/g, '_');
                    }
                    return btoa(text);
                }

                // 스크롤 동기화를 위한 스크롤 이벤트 핸들러
                let scrollPending = false;
                let lastScrollPercent = -1;
                window.addEventListener('scroll', function() {
                    if (scrollPending) return;
                    scrollPending = true;
                    requestAnimationFrame(function() {
                        var height = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
                        var scrollableHeight = height - window.innerHeight;
                        if (scrollableHeight > 0) {
                            var scrollPercent = window.scrollY / scrollableHeight;
                            // 변화가 있을 때만 전송
                            if (Math.abs(scrollPercent - lastScrollPercent) > 0.001) {
                                lastScrollPercent = scrollPercent;
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.scrollHandler) {
                                    window.webkit.messageHandlers.scrollHandler.postMessage(scrollPercent);
                                }
                            }
                        }
                        scrollPending = false;
                    });
                }, { passive: true });
            </script>
        </body>
        </html>
        """
    }

    private func getCSS(for theme: PreviewTheme) -> String {
        // 내장 CSS (리소스 파일을 로드할 수 없는 경우를 위한 폴백)
        if theme == .dark {
            return darkThemeCSS
        } else {
            return lightThemeCSS
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: PreviewView
        var scrollSyncManager: ScrollSyncManager?
        var lastHtmlKey: String = ""

        init(_ parent: PreviewView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated {

                // 앵커 링크 처리 (fragment가 있으면 내부 링크로 처리)
                if let fragment = url.fragment, !fragment.isEmpty {
                    // URL 디코딩 및 이스케이프 처리
                    let decodedFragment = fragment.removingPercentEncoding ?? fragment
                    let escapedFragment = decodedFragment
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "'", with: "\\'")

                    // JavaScript로 앵커로 스크롤
                    let js = """
                    (function() {
                        var fragment = '\(escapedFragment)';
                        var target = document.getElementById(fragment);
                        if (!target) {
                            // ID로 못 찾으면 name 속성으로 시도
                            target = document.querySelector('[name="' + fragment + '"]');
                        }
                        if (!target) {
                            // 헤딩 텍스트로 검색 시도
                            var headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
                            for (var i = 0; i < headings.length; i++) {
                                var h = headings[i];
                                if (h.id === fragment || h.textContent.trim().toLowerCase().replace(/\\s+/g, '-') === fragment.toLowerCase()) {
                                    target = h;
                                    break;
                                }
                            }
                        }
                        if (target) {
                            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                        }
                    })();
                    """
                    webView.evaluateJavaScript(js, completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }

                // 외부 링크는 기본 브라우저에서 열기
                if url.scheme == "http" || url.scheme == "https" {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // 페이지 로드 완료 후 에디터 커서 위치에 맞춰 프리뷰 동기화
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let syncManager = scrollSyncManager, syncManager.isEnabled else { return }

            // 에디터의 현재 커서 라인 기준으로 프리뷰 동기화 (더 정확한 위치)
            let percent = syncManager.getEditorCursorLinePercent()

            // 약간의 딜레이 후 스크롤 (렌더링 완료 대기)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let js = """
                (function() {
                    var h = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) - window.innerHeight;
                    if (h > 0) window.scrollTo(0, h * \(percent));
                })();
                """
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        // JavaScript에서 스크롤 이벤트 수신
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scrollHandler",
               let scrollPercent = message.body as? Double {
                scrollSyncManager?.previewDidScroll(scrollPercent: scrollPercent)
            }
        }
    }
}

// MARK: - 내장 CSS
private let darkThemeCSS = """
:root {
    --bg-color: #1e1e1e;
    --text-color: #d4d4d4;
    --heading-color: #569cd6;
    --link-color: #4fc1ff;
    --code-bg: #2d2d2d;
    --code-text: #ce9178;
    --blockquote-border: #569cd6;
    --blockquote-bg: #252526;
    --table-border: #3c3c3c;
    --table-header-bg: #2d2d2d;
    --hr-color: #3c3c3c;
}

body.dark {
    background-color: var(--bg-color);
    color: var(--text-color);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    font-size: 16px;
    line-height: 1.6;
    padding: 20px;
    margin: 0;
}

.markdown-body { max-width: 100%; margin: 0 auto; }

h1, h2, h3, h4, h5, h6 {
    color: var(--heading-color);
    margin-top: 24px;
    margin-bottom: 16px;
    font-weight: 600;
}

h1 { font-size: 2em; border-bottom: 1px solid var(--hr-color); padding-bottom: 0.3em; }
h2 { font-size: 1.5em; border-bottom: 1px solid var(--hr-color); padding-bottom: 0.3em; }
h3 { font-size: 1.25em; }

a { color: var(--link-color); text-decoration: none; }
a:hover { text-decoration: underline; }

strong { font-weight: 600; color: #dcdcaa; }
em { font-style: italic; color: #c586c0; }
del { text-decoration: line-through; color: #808080; }

code {
    background-color: var(--code-bg);
    color: var(--code-text);
    padding: 0.2em 0.4em;
    border-radius: 3px;
    font-family: 'SF Mono', Consolas, monospace;
    font-size: 85%;
}

pre {
    background-color: var(--code-bg);
    border-radius: 6px;
    padding: 16px;
    overflow: auto;
}

pre code { background: transparent; padding: 0; font-size: 100%; }

blockquote {
    border-left: 4px solid var(--blockquote-border);
    background-color: var(--blockquote-bg);
    padding: 12px 20px;
    margin: 0 0 16px 0;
    color: #9cdcfe;
}

table { border-collapse: collapse; width: 100%; margin-bottom: 16px; }
th, td { border: 1px solid var(--table-border); padding: 8px 12px; text-align: left; }
th { background-color: var(--table-header-bg); font-weight: 600; }

hr { border: none; border-top: 1px solid var(--hr-color); margin: 24px 0; }

img { max-width: 100%; height: auto; border-radius: 4px; }

mark { background-color: #806d00; color: #ffffff; padding: 0.1em 0.3em; border-radius: 2px; }

.mermaid { background-color: #2d2d2d; padding: 16px; border-radius: 6px; margin-bottom: 16px; text-align: center; }
.plantuml { background-color: #2d2d2d; padding: 16px; border-radius: 6px; margin-bottom: 16px; text-align: center; }
.diagram-error { background-color: #5a1d1d; color: #f48771; padding: 12px; border-radius: 6px; }

.math-block { text-align: center; margin: 16px 0; overflow-x: auto; }

.footnote { font-size: 0.875em; color: #808080; border-top: 1px solid var(--hr-color); padding-top: 16px; margin-top: 32px; }

/* 체크박스 리스트 스타일 */
li:has(input[type="checkbox"]) { list-style-type: none; margin-left: -1.2em; }
li input[type="checkbox"] { margin-right: 8px; }

/* 순서 있는 리스트 */
ol { list-style-type: decimal; }
ol li { list-style-type: decimal; }
"""

private let lightThemeCSS = """
:root {
    --bg-color: #ffffff;
    --text-color: #24292e;
    --heading-color: #0366d6;
    --link-color: #0366d6;
    --code-bg: #f6f8fa;
    --code-text: #d73a49;
    --blockquote-border: #0366d6;
    --blockquote-bg: #f6f8fa;
    --table-border: #e1e4e8;
    --table-header-bg: #f6f8fa;
    --hr-color: #e1e4e8;
}

body.light {
    background-color: var(--bg-color);
    color: var(--text-color);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    font-size: 16px;
    line-height: 1.6;
    padding: 20px;
    margin: 0;
}

.markdown-body { max-width: 100%; margin: 0 auto; }

h1, h2, h3, h4, h5, h6 {
    color: var(--heading-color);
    margin-top: 24px;
    margin-bottom: 16px;
    font-weight: 600;
}

h1 { font-size: 2em; border-bottom: 1px solid var(--hr-color); padding-bottom: 0.3em; }
h2 { font-size: 1.5em; border-bottom: 1px solid var(--hr-color); padding-bottom: 0.3em; }
h3 { font-size: 1.25em; }

a { color: var(--link-color); text-decoration: none; }
a:hover { text-decoration: underline; }

strong { font-weight: 600; color: #22863a; }
em { font-style: italic; color: #6f42c1; }
del { text-decoration: line-through; color: #6a737d; }

code {
    background-color: var(--code-bg);
    color: var(--code-text);
    padding: 0.2em 0.4em;
    border-radius: 3px;
    font-family: 'SF Mono', Consolas, monospace;
    font-size: 85%;
}

pre {
    background-color: var(--code-bg);
    border-radius: 6px;
    padding: 16px;
    overflow: auto;
}

pre code { background: transparent; padding: 0; font-size: 100%; color: #24292e; }

blockquote {
    border-left: 4px solid var(--blockquote-border);
    background-color: var(--blockquote-bg);
    padding: 12px 20px;
    margin: 0 0 16px 0;
    color: #586069;
}

table { border-collapse: collapse; width: 100%; margin-bottom: 16px; }
th, td { border: 1px solid var(--table-border); padding: 8px 12px; text-align: left; }
th { background-color: var(--table-header-bg); font-weight: 600; }

hr { border: none; border-top: 1px solid var(--hr-color); margin: 24px 0; }

img { max-width: 100%; height: auto; border-radius: 4px; }

mark { background-color: #fff3cd; color: #24292e; padding: 0.1em 0.3em; border-radius: 2px; }

.mermaid { background-color: #f6f8fa; padding: 16px; border-radius: 6px; margin-bottom: 16px; text-align: center; }
.plantuml { background-color: #f6f8fa; padding: 16px; border-radius: 6px; margin-bottom: 16px; text-align: center; }
.diagram-error { background-color: #ffeef0; color: #d73a49; padding: 12px; border-radius: 6px; border: 1px solid #f97583; }

.math-block { text-align: center; margin: 16px 0; overflow-x: auto; }

.footnote { font-size: 0.875em; color: #6a737d; border-top: 1px solid var(--hr-color); padding-top: 16px; margin-top: 32px; }

/* 체크박스 리스트 스타일 */
li:has(input[type="checkbox"]) { list-style-type: none; margin-left: -1.2em; }
li input[type="checkbox"] { margin-right: 8px; }

/* 순서 있는 리스트 */
ol { list-style-type: decimal; }
ol li { list-style-type: decimal; }
"""

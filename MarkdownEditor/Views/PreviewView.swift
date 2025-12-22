import SwiftUI
import WebKit

// WKWebView를 래핑한 Markdown 미리보기 뷰
// HTML 렌더링, Mermaid 다이어그램, 수식 지원

struct PreviewView: NSViewRepresentable {
    var htmlContent: String
    var theme: PreviewTheme

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // 로컬 파일 접근 허용
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // JavaScript 활성화
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // 배경 투명 설정
        webView.setValue(false, forKey: "drawsBackground")

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let fullHTML = wrapHTML(content: htmlContent, theme: theme)
        webView.loadHTMLString(fullHTML, baseURL: Bundle.main.resourceURL)
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

            <!-- Mermaid for diagrams -->
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
            <script>
                mermaid.initialize({
                    startOnLoad: true,
                    theme: '\(mermaidTheme)',
                    securityLevel: 'loose'
                });
            </script>
        </head>
        <body class="\(themeClass)">
            <div class="markdown-body">
                \(content)
            </div>
            <script>
                // 코드 하이라이팅
                document.addEventListener('DOMContentLoaded', function() {
                    document.querySelectorAll('pre code').forEach((block) => {
                        hljs.highlightElement(block);
                    });

                    // KaTeX 수식 렌더링
                    renderMathInElement(document.body, {
                        delimiters: [
                            {left: '$$', right: '$$', display: true},
                            {left: '$', right: '$', display: false}
                        ],
                        throwOnError: false
                    });

                    // PlantUML 다이어그램 처리
                    document.querySelectorAll('.plantuml').forEach(async (element) => {
                        const code = element.getAttribute('data-code');
                        if (code) {
                            try {
                                const encoded = plantumlEncode(code.replace(/&#10;/g, '\\n'));
                                const img = document.createElement('img');
                                img.src = 'https://www.plantuml.com/plantuml/svg/' + encoded;
                                img.alt = 'PlantUML Diagram';
                                img.style.maxWidth = '100%';
                                element.innerHTML = '';
                                element.appendChild(img);
                            } catch (e) {
                                element.innerHTML = '<div class="diagram-error">PlantUML 렌더링 오류: ' + e.message + '</div>';
                            }
                        }
                    });
                });

                // PlantUML 인코딩 함수
                function plantumlEncode(text) {
                    const encoded = unescape(encodeURIComponent(text));
                    const compressed = deflate(encoded);
                    return encode64(compressed);
                }

                function encode64(data) {
                    let r = "";
                    for (let i = 0; i < data.length; i += 3) {
                        if (i + 2 == data.length) {
                            r += append3bytes(data.charCodeAt(i), data.charCodeAt(i + 1), 0);
                        } else if (i + 1 == data.length) {
                            r += append3bytes(data.charCodeAt(i), 0, 0);
                        } else {
                            r += append3bytes(data.charCodeAt(i), data.charCodeAt(i + 1), data.charCodeAt(i + 2));
                        }
                    }
                    return r;
                }

                function append3bytes(b1, b2, b3) {
                    const c1 = b1 >> 2;
                    const c2 = ((b1 & 0x3) << 4) | (b2 >> 4);
                    const c3 = ((b2 & 0xF) << 2) | (b3 >> 6);
                    const c4 = b3 & 0x3F;
                    let r = "";
                    r += encode6bit(c1 & 0x3F);
                    r += encode6bit(c2 & 0x3F);
                    r += encode6bit(c3 & 0x3F);
                    r += encode6bit(c4 & 0x3F);
                    return r;
                }

                function encode6bit(b) {
                    if (b < 10) return String.fromCharCode(48 + b);
                    b -= 10;
                    if (b < 26) return String.fromCharCode(65 + b);
                    b -= 26;
                    if (b < 26) return String.fromCharCode(97 + b);
                    b -= 26;
                    if (b == 0) return '-';
                    if (b == 1) return '_';
                    return '?';
                }

                function deflate(s) {
                    // 간단한 Raw deflate (PlantUML 텍스트 인코딩용)
                    // 실제로는 pako 등의 라이브러리 사용 권장
                    return s; // 간소화된 버전
                }
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
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: PreviewView

        init(_ parent: PreviewView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 외부 링크는 기본 브라우저에서 열기
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
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
"""

import Foundation

public struct HTMLTemplate {
    public init() {}

    /// Generate full HTML document wrapping markdown-converted HTML content
    public func wrapHTML(content: String, theme: PreviewTheme, useLocalResources: Bool = false, resourceBaseURL: URL? = nil) -> String {
        let themeClass = theme == .dark ? "dark" : "light"
        let mermaidTheme = theme.mermaidTheme

        let resourceRefs: String
        if useLocalResources, let baseURL = resourceBaseURL {
            resourceRefs = localResourceRefs(baseURL: baseURL, theme: theme)
        } else {
            resourceRefs = cdnResourceRefs(theme: theme)
        }

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
            \(resourceRefs)
        </head>
        <body class="\(themeClass)">
            <div class="markdown-body">
                \(content)
            </div>
            \(renderingScript(mermaidTheme: mermaidTheme))
        </body>
        </html>
        """
    }

    private func cdnResourceRefs(theme: PreviewTheme) -> String {
        let hlTheme = theme == .dark ? "atom-one-dark" : "atom-one-light"
        return """
            <!-- Highlight.js -->
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/\(hlTheme).min.css">
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
            <!-- KaTeX -->
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"></script>
            <!-- Mermaid -->
            <script src="https://cdn.jsdelivr.net/npm/mermaid@11.3/dist/mermaid.min.js"></script>
            <!-- Pako for PlantUML -->
            <script src="https://cdn.jsdelivr.net/npm/pako@2.1.0/dist/pako.min.js"></script>
        """
    }

    private func localResourceRefs(baseURL: URL, theme: PreviewTheme) -> String {
        let hlTheme = theme == .dark ? "atom-one-dark" : "atom-one-light"

        // Bundle.module에서 리소스 URL 가져오기
        let hlCSS = Bundle.module.url(forResource: hlTheme + ".min", withExtension: "css")?.absoluteString ?? "\(hlTheme).min.css"
        let hlJS = Bundle.module.url(forResource: "highlight.min", withExtension: "js")?.absoluteString ?? "highlight.min.js"
        let katexCSS = Bundle.module.url(forResource: "katex.min", withExtension: "css")?.absoluteString ?? "katex.min.css"
        let katexJS = Bundle.module.url(forResource: "katex.min", withExtension: "js")?.absoluteString ?? "katex.min.js"
        let autoRenderJS = Bundle.module.url(forResource: "auto-render.min", withExtension: "js")?.absoluteString ?? "auto-render.min.js"
        let mermaidJS = Bundle.module.url(forResource: "mermaid.min", withExtension: "js")?.absoluteString ?? "mermaid.min.js"
        let pakoJS = Bundle.module.url(forResource: "pako.min", withExtension: "js")?.absoluteString ?? "pako.min.js"

        return """
            <!-- Highlight.js (local) -->
            <link rel="stylesheet" href="\(hlCSS)">
            <script src="\(hlJS)"></script>
            <!-- KaTeX (local) -->
            <link rel="stylesheet" href="\(katexCSS)">
            <script src="\(katexJS)"></script>
            <script src="\(autoRenderJS)"></script>
            <!-- Mermaid (local) -->
            <script src="\(mermaidJS)"></script>
            <!-- Pako (local) -->
            <script src="\(pakoJS)"></script>
        """
    }

    private func renderingScript(mermaidTheme: String) -> String {
        return """
            <script>
                document.addEventListener('DOMContentLoaded', async function() {
                    if (typeof hljs !== 'undefined') {
                        document.querySelectorAll('pre code').forEach((block) => {
                            hljs.highlightElement(block);
                        });
                    }
                    if (typeof mermaid !== 'undefined') {
                        try {
                            mermaid.initialize({
                                startOnLoad: false,
                                theme: '\(mermaidTheme)',
                                securityLevel: 'loose',
                                flowchart: { htmlLabels: true, useMaxWidth: true }
                            });
                            await mermaid.run({ querySelector: '.mermaid' });
                        } catch (e) {}
                    }
                    if (typeof renderMathInElement !== 'undefined') {
                        renderMathInElement(document.body, {
                            delimiters: [
                                {left: '$$', right: '$$', display: true},
                                {left: '$', right: '$', display: false}
                            ],
                            throwOnError: false
                        });
                    }
                    document.querySelectorAll('.plantuml').forEach(async (element) => {
                        const code = element.getAttribute('data-code');
                        if (code) {
                            try {
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
                function krokiEncode(text) {
                    if (typeof pako !== 'undefined') {
                        const data = new TextEncoder().encode(text);
                        const compressed = pako.deflate(data, { level: 9 });
                        const base64 = btoa(String.fromCharCode.apply(null, compressed));
                        return base64.replace(/[+]/g, '-').replace(/[/]/g, '_');
                    }
                    return btoa(text);
                }
            </script>
        """
    }

    public func getCSS(for theme: PreviewTheme) -> String {
        if theme == .dark {
            return darkThemeCSS
        } else {
            return lightThemeCSS
        }
    }
}

let darkThemeCSS: String = """
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

li:has(input[type="checkbox"]) { list-style-type: none; margin-left: -1.2em; }
li input[type="checkbox"] { margin-right: 8px; }

ol { list-style-type: decimal; }
ol li { list-style-type: decimal; }
"""

let lightThemeCSS: String = """
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

li:has(input[type="checkbox"]) { list-style-type: none; margin-left: -1.2em; }
li input[type="checkbox"] { margin-right: 8px; }

ol { list-style-type: decimal; }
ol li { list-style-type: decimal; }
"""

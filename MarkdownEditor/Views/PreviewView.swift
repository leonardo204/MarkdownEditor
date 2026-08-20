import SwiftUI
import WebKit
import MarkdownCore

// WKWebView를 래핑한 Markdown 미리보기 뷰
// HTML 렌더링, Mermaid 다이어그램, 수식 지원

struct PreviewView: NSViewRepresentable {
    var htmlContent: String
    var theme: PreviewTheme
    var scrollSyncManager: ScrollSyncManager?
    var findReplaceManager: FindReplaceManager?
    var documentURL: URL?
    @AppStorage("imageMaxWidth") private var imageMaxWidth: Double = 680
    @AppStorage("imageRenderMode") private var imageRenderMode: String = "optimized"

    // 스타일 관련 변경 감지 키 (htmlContent는 문자열 자체를 비교 — hashValue는 매 틱 O(n))
    private var styleKey: String {
        "\(theme.rawValue)_\(imageRenderMode)_\(Int(imageMaxWidth))"
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // 로컬 파일 접근 허용
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // JavaScript 활성화
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // 스크롤/링크 이벤트를 Swift로 전달하기 위한 스크립트 메시지 핸들러
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "scrollHandler")
        userContentController.add(context.coordinator, name: "linkHandler")
        userContentController.add(context.coordinator, name: "focusHandler")
        configuration.userContentController = userContentController

        // 로컬 이미지 온디맨드 서빙 (me-asset:// 스킴)
        configuration.setURLSchemeHandler(LocalImageSchemeHandler(), forURLScheme: LocalImageSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // 배경 투명 설정
        webView.setValue(false, forKey: "drawsBackground")

        // 스크롤 동기화 매니저에 등록
        scrollSyncManager?.previewWebView = webView
        context.coordinator.scrollSyncManager = scrollSyncManager

        // 찾기 매니저에 프리뷰 웹뷰 등록
        findReplaceManager?.previewWebView = webView
        context.coordinator.findReplaceManager = findReplaceManager

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // 스크롤 동기화 매니저 업데이트
        scrollSyncManager?.previewWebView = webView
        context.coordinator.scrollSyncManager = scrollSyncManager

        // 찾기 매니저 업데이트
        findReplaceManager?.previewWebView = webView
        context.coordinator.findReplaceManager = findReplaceManager

        // HTML이 변경된 경우에만 다시 로드
        // 편집으로 인한 업데이트 시에는 스크롤 복원하지 않음
        // (에디터 스크롤 시에만 ScrollSyncManager가 동기화 처리)
        // htmlContent는 대개 동일 스토리지를 공유하므로 == 가 포인터 비교로 끝난다(O(1)).
        // hashValue는 매 틱 전체 문자열을 훑으므로 쓰지 않는다.
        let currentStyleKey = styleKey
        if context.coordinator.lastStyleKey != currentStyleKey
            || context.coordinator.lastHtmlContent != htmlContent {
            context.coordinator.lastStyleKey = currentStyleKey
            context.coordinator.lastHtmlContent = htmlContent

            let fullHTML = wrapHTML(content: htmlContent, theme: theme)

            let baseURL = documentURL?.deletingLastPathComponent() ?? Bundle.main.resourceURL
            webView.loadHTMLString(fullHTML, baseURL: baseURL)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 번들에 존재가 확인된 리소스만 me-asset://bundle/로 서빙하고, 없으면 CDN을 유지한다.
    private func resourceURL(bundled name: String, cdn: String) -> String {
        BundledWebResources.isAvailable(name) ? "me-asset://bundle/\(name)" : cdn
    }

    private func wrapHTML(content: String, theme: PreviewTheme) -> String {
        let themeClass = theme == .dark ? "dark" : "light"
        let mermaidTheme = theme.mermaidTheme

        // CDN 콜드 로드가 초기 렌더 시간의 대부분을 차지하므로 번들 리소스로 대체한다.
        let hlThemeName = theme == .dark ? "atom-one-dark.min.css" : "atom-one-light.min.css"
        let hlThemeURL = resourceURL(
            bundled: hlThemeName,
            cdn: "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/\(hlThemeName)"
        )
        let hlJSURL = resourceURL(
            bundled: "highlight.min.js",
            cdn: "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"
        )
        let katexJSURL = resourceURL(
            bundled: "katex.min.js",
            cdn: "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"
        )
        let autoRenderJSURL = resourceURL(
            bundled: "auto-render.min.js",
            cdn: "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"
        )
        let mermaidJSURL = resourceURL(
            bundled: "mermaid.min.js",
            cdn: "https://cdn.jsdelivr.net/npm/mermaid@11.3/dist/mermaid.min.js"
        )
        let pakoJSURL = resourceURL(
            bundled: "pako.min.js",
            cdn: "https://cdn.jsdelivr.net/npm/pako@2.1.0/dist/pako.min.js"
        )
        // KaTeX CSS는 상대경로 url(fonts/...)로 폰트를 참조하는데 번들에 폰트가 없다.
        // 번들에서 로드하면 폰트 요청이 me-asset://bundle/fonts/...로 와서 전부 실패하므로 CDN을 유지한다.
        let katexCSSURL = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta http-equiv="Content-Security-Policy" content="default-src 'self' 'unsafe-inline' data: blob: me-asset: https: http:; img-src 'self' data: blob: me-asset: https: http:; script-src 'self' 'unsafe-inline' 'unsafe-eval' me-asset: https:; style-src 'self' 'unsafe-inline' me-asset: https:; frame-src https: http:; object-src 'none';">
            <style>
                \(getCSS(for: theme))
                \(imageRenderMode == "optimized" ? "img { max-width: \(Int(imageMaxWidth))px !important; } img.img-wide { max-width: 100% !important; width: 100% !important; }" : "img { max-width: 100% !important; }")
                /* width/height 속성으로 레이아웃 높이를 예약하되, max-width로 축소될 때
                   종횡비가 깨지지 않도록 높이를 자동 계산시킨다.
                   속성이 주입된 이미지에만 적용해 사용자가 raw HTML로 지정한 height는 존중한다. */
                img[width][height] { height: auto !important; }
                /* 찾기 하이라이트 */
                mark.me-find { background-color: rgba(255, 235, 59, 0.5); color: inherit; border-radius: 2px; padding: 0; }
                mark.me-find.me-find-current { background-color: rgba(255, 145, 0, 0.95); color: #000; }
            </style>
            <!-- Highlight.js for code highlighting -->
            <link rel="stylesheet" href="\(hlThemeURL)">
            <script defer src="\(hlJSURL)"></script>

            <!-- KaTeX for math (CSS는 폰트 의존으로 CDN 유지 + 렌더 블로킹 제거) -->
            <link rel="stylesheet" href="\(katexCSSURL)" media="print" onload="this.media='all'">
            <script defer src="\(katexJSURL)"></script>
            <script defer src="\(autoRenderJSURL)"></script>

            <!-- Mermaid for diagrams (v11.3+ supports markdown strings for line breaks) -->
            <script defer src="\(mermaidJSURL)"></script>

            <!-- Pako for PlantUML compression -->
            <script defer src="\(pakoJSURL)"></script>
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
                            // 렌더링은 계속하되, 원인은 남긴다 (Web Inspector에서 확인)
                            console.error('[Mermaid] 렌더링 실패:', e && e.message ? e.message : e);
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

                    // optimized 모드: 원본 너비가 설정 max-width의 2배 초과 이미지는 전체 너비로 표시
                    var imgMaxW = \(Int(imageMaxWidth));
                    document.querySelectorAll('img').forEach(function(img) {
                        function checkWide() {
                            if (img.naturalWidth > imgMaxW * 2) {
                                img.classList.add('img-wide');
                            }
                        }
                        if (img.complete) checkWide();
                        else img.addEventListener('load', checkWide);
                    });

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

                // 링크 클릭 인터셉트 (loadHTMLString에서 file:// 네비게이션이 delegate에 전달되지 않는 문제 우회)
                document.addEventListener('click', function(e) {
                    var a = e.target.closest('a[href]');
                    if (!a) return;
                    var href = a.getAttribute('href');
                    if (!href || href.startsWith('#') || href.startsWith('javascript:')) return;
                    e.preventDefault();
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.linkHandler) {
                        window.webkit.messageHandlers.linkHandler.postMessage(href);
                    }
                });

                // 프리뷰의 실제 사용자 입력 시각을 추적한다.
                // 프로그램적 scrollTo와 이미지 리플로우는 사용자 입력을 동반하지 않으므로
                // 이 시각을 기준으로 걸러내면 rAF 이벤트 병합과 무관하게 정확히 구분된다.
                var meLastUserInput = 0;
                ['wheel','mousedown','touchstart','touchmove','keydown'].forEach(function(t){
                    window.addEventListener(t, function(){ meLastUserInput = Date.now(); },
                                            { passive: true, capture: true });
                });

                // 스크롤 동기화를 위한 스크롤 이벤트 핸들러
                let scrollPending = false;
                let lastScrollPercent = -1;
                window.addEventListener('scroll', function() {
                    if (scrollPending) return;
                    scrollPending = true;
                    requestAnimationFrame(function() {
                        // 사용자 입력 없이 발생한 스크롤 = 프로그램적 스크롤 또는 리플로우
                        // → 에디터를 건드리지 않는다.
                        // (휠을 굴리는 동안 입력 시각이 계속 갱신되므로 관성 구간도 정상 동기화된다)
                        if (Date.now() - meLastUserInput > 700) { scrollPending = false; return; }

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

                // 프리뷰에서 사용자 상호작용 발생 시 Swift에 알림 (검색 대상 자동 선택용)
                function meNotifyFocus() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.focusHandler) {
                        window.webkit.messageHandlers.focusHandler.postMessage('preview');
                    }
                }
                document.addEventListener('mousedown', meNotifyFocus, true);
                document.addEventListener('focusin', meNotifyFocus, true);

                // 프리뷰 내 텍스트 검색/하이라이트
                (function() {
                    var matches = [];
                    var currentIndex = -1;

                    function clearHighlights() {
                        var marks = document.querySelectorAll('mark.me-find');
                        for (var i = 0; i < marks.length; i++) {
                            var m = marks[i];
                            var parent = m.parentNode;
                            if (!parent) continue;
                            while (m.firstChild) parent.insertBefore(m.firstChild, m);
                            parent.removeChild(m);
                            parent.normalize();
                        }
                        matches = [];
                        currentIndex = -1;
                    }

                    function status() {
                        return { count: matches.length, current: currentIndex >= 0 ? currentIndex + 1 : 0 };
                    }

                    function applyCurrent(scroll) {
                        for (var i = 0; i < matches.length; i++) {
                            if (i === currentIndex) matches[i].classList.add('me-find-current');
                            else matches[i].classList.remove('me-find-current');
                        }
                        if (scroll && currentIndex >= 0 && matches[currentIndex]) {
                            matches[currentIndex].scrollIntoView({ block: 'center', behavior: 'smooth' });
                        }
                    }

                    function find(query, caseSensitive) {
                        clearHighlights();
                        if (!query) return status();

                        var root = document.querySelector('.markdown-body') || document.body;
                        var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
                            acceptNode: function(node) {
                                if (!node.nodeValue || node.nodeValue.length === 0) return NodeFilter.FILTER_REJECT;
                                var p = node.parentNode;
                                while (p && p !== root) {
                                    var tag = p.nodeName;
                                    if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'MARK' || tag === 'TEXTAREA') return NodeFilter.FILTER_REJECT;
                                    p = p.parentNode;
                                }
                                return NodeFilter.FILTER_ACCEPT;
                            }
                        });

                        var textNodes = [];
                        var node;
                        while (node = walker.nextNode()) textNodes.push(node);

                        var qlen = query.length;
                        var needle = caseSensitive ? query : query.toLowerCase();

                        for (var t = 0; t < textNodes.length; t++) {
                            var textNode = textNodes[t];
                            var text = textNode.nodeValue;
                            var hay = caseSensitive ? text : text.toLowerCase();
                            var idx = hay.indexOf(needle);
                            if (idx === -1) continue;

                            var frag = document.createDocumentFragment();
                            var last = 0;
                            while (idx !== -1) {
                                if (idx > last) frag.appendChild(document.createTextNode(text.substring(last, idx)));
                                var mark = document.createElement('mark');
                                mark.className = 'me-find';
                                mark.appendChild(document.createTextNode(text.substring(idx, idx + qlen)));
                                frag.appendChild(mark);
                                last = idx + qlen;
                                idx = hay.indexOf(needle, last);
                            }
                            if (last < text.length) frag.appendChild(document.createTextNode(text.substring(last)));
                            if (textNode.parentNode) textNode.parentNode.replaceChild(frag, textNode);
                        }

                        matches = Array.prototype.slice.call(document.querySelectorAll('mark.me-find'));
                        currentIndex = matches.length ? 0 : -1;
                        applyCurrent(true);
                        return status();
                    }

                    function goto(index) {
                        if (!matches.length) return status();
                        var n = matches.length;
                        currentIndex = ((index % n) + n) % n;
                        applyCurrent(true);
                        return status();
                    }

                    window.meFind = {
                        find: find,
                        clear: clearHighlights,
                        next: function() { return goto(currentIndex + 1); },
                        prev: function() { return goto(currentIndex - 1); },
                        current: status
                    };
                })();
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
        var findReplaceManager: FindReplaceManager?
        var lastStyleKey: String = ""
        var lastHtmlContent: String? = nil

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
            // 프리뷰 검색이 활성화되어 있으면 재로드 후 하이라이트 재적용 (렌더링 완료 대기)
            if let findManager = findReplaceManager, findManager.isVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    findManager.reapplyPreviewSearchIfNeeded()
                }
            }

            guard let syncManager = scrollSyncManager, syncManager.isEnabled else { return }

            // 로드 직후 리소스 리플로우가 사용자 스크롤로 오인되지 않도록 정착 창을 연다
            syncManager.beginLoadSettling()

            // 에디터의 현재 커서 라인 기준으로 프리뷰 동기화 (더 정확한 위치)
            let percent = syncManager.getEditorCursorLinePercent()

            // 약간의 딜레이 후 스크롤 (렌더링 완료 대기)
            // 반드시 syncManager를 경유해야 한다 — 직접 scrollTo하면 그 에코가 사용자 스크롤로
            // 오인되어 파일 오픈 직후 에디터가 엉뚱한 위치로 끌려간다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                syncManager.scrollPreviewToPercent(percent, in: webView)
            }
        }

        // JavaScript에서 스크롤/링크 이벤트 수신
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scrollHandler" {
                // 페이로드는 Double이지만 객체 형태도 안전하게 받는다
                let scrollPercent: Double?
                if let value = message.body as? Double {
                    scrollPercent = value
                } else if let dict = message.body as? [String: Any] {
                    scrollPercent = dict["percent"] as? Double
                } else {
                    scrollPercent = nil
                }
                if let scrollPercent {
                    scrollSyncManager?.previewDidScroll(scrollPercent: scrollPercent)
                }
            } else if message.name == "linkHandler",
                      let href = message.body as? String {
                handleLinkClick(href, in: message.webView)
            } else if message.name == "focusHandler" {
                // 프리뷰에서 사용자 상호작용 발생 → 검색 대상 자동 선택용
                findReplaceManager?.markPreviewActive()
            }
        }

        private func handleLinkClick(_ href: String, in webView: WKWebView?) {
            // 외부 링크
            if href.hasPrefix("http://") || href.hasPrefix("https://") {
                if let url = URL(string: href) {
                    NSWorkspace.shared.open(url)
                }
                return
            }

            // 상대 경로 → 절대 file:// URL로 해석
            let resolvedURL: URL
            if href.hasPrefix("file://") {
                guard let url = URL(string: href) else { return }
                resolvedURL = url
            } else if let docURL = parent.documentURL {
                let docDir = docURL.deletingLastPathComponent()
                resolvedURL = docDir.appendingPathComponent(href).standardized
            } else {
                return
            }

            let ext = resolvedURL.pathExtension.lowercased()
            if ext == "md" || ext == "markdown" || ext == "txt" {
                _ = DirectoryBookmarkManager.shared.startAccessing(directoryOf: resolvedURL)
                TabService.shared.openDocument(url: resolvedURL)
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

/**
 * MarkChartEditor 랜딩 Worker — md-editor.zerolive.co.kr
 *
 * 경로
 *   /                  한국어 랜딩
 *   /en                영어 랜딩
 *   /privacy           개인정보처리방침 (한국어)
 *   /en/privacy        개인정보처리방침 (영어)
 *   /robots.txt        크롤러 안내 (검색 엔진 + AI 크롤러 허용)
 *   /sitemap.xml       사이트맵
 *   /llms.txt          AI 에이전트용 요약 (llmstxt.org 관례)
 *   그 외              정적 파일(ASSETS: /assets/*)
 *
 * 앱은 Mac App Store에서 배포한다. 이 worker는 소개와 정책 문서만 맡는다.
 */
import { renderLanding, renderPrivacy, SITE, APP_STORE_URL, REPO_URL, APP_NAME, APP_VERSION, CONTACT_EMAIL } from "./render";

interface Env {
	ASSETS: Fetcher;
}

const LAST_MOD = "2026-09-04";

async function route(request: Request, env: Env): Promise<Response> {
	const url = new URL(request.url);
	// 끝의 슬래시를 떼어 같은 문서가 두 주소로 잡히지 않게 한다(루트는 예외).
	const path = url.pathname.length > 1 ? url.pathname.replace(/\/+$/, "") : "/";

	if (path !== url.pathname && path !== "") {
		url.pathname = path;
		return Response.redirect(url.toString(), 301);
	}

	switch (path) {
		case "/":
		case "/index.html":
			return html(renderLanding("ko"));
		case "/en":
		case "/en/index.html":
			return html(renderLanding("en"));
		case "/privacy":
		case "/privacy.html":
			return html(renderPrivacy("ko"));
		case "/en/privacy":
			return html(renderPrivacy("en"));
		case "/robots.txt":
			return text(robots());
		case "/sitemap.xml":
			return new Response(sitemap(), {
				headers: { "Content-Type": "application/xml;charset=UTF-8", "Cache-Control": "public, max-age=3600" },
			});
		case "/llms.txt":
			return text(llms());
	}

	// 정적 파일. 없으면 안내 페이지를 돌려준다.
	const asset = await env.ASSETS.fetch(request);
	if (asset.status === 404) {
		return html(renderLanding("ko"), { status: 404 });
	}
	return asset;
}

function html(body: string, opts: { status?: number } = {}): Response {
	return new Response(body, {
		status: opts.status ?? 200,
		headers: {
			"Content-Type": "text/html;charset=UTF-8",
			"Cache-Control": "public, max-age=300",
		},
	});
}

function text(body: string): Response {
	return new Response(body, {
		headers: { "Content-Type": "text/plain;charset=UTF-8", "Cache-Control": "public, max-age=3600" },
	});
}

/**
 * 검색 엔진과 AI 크롤러를 모두 받는다.
 * 이 사이트는 앱을 알리는 것이 목적이라 학습·인용 크롤러도 막지 않는다.
 */
function robots(): string {
	const aiBots = [
		"GPTBot",
		"OAI-SearchBot",
		"ChatGPT-User",
		"ClaudeBot",
		"Claude-User",
		"Claude-SearchBot",
		"anthropic-ai",
		"PerplexityBot",
		"Perplexity-User",
		"Google-Extended",
		"Googlebot",
		"Bingbot",
		"Applebot",
		"Applebot-Extended",
		"DuckDuckBot",
		"Yeti",
		"Daumoa",
		"CCBot",
		"meta-externalagent",
		"Amazonbot",
		"cohere-ai",
	];
	const blocks = ["User-agent: *\nAllow: /", ...aiBots.map((b) => `User-agent: ${b}\nAllow: /`)];
	return `${blocks.join("\n\n")}\n\nSitemap: ${SITE}/sitemap.xml\n`;
}

function sitemap(): string {
	const pages: { loc: string; pri: string; ko: string; en: string }[] = [
		{ loc: SITE + "/", pri: "1.0", ko: SITE + "/", en: SITE + "/en" },
		{ loc: SITE + "/en", pri: "0.9", ko: SITE + "/", en: SITE + "/en" },
		{ loc: SITE + "/privacy", pri: "0.4", ko: SITE + "/privacy", en: SITE + "/en/privacy" },
		{ loc: SITE + "/en/privacy", pri: "0.3", ko: SITE + "/privacy", en: SITE + "/en/privacy" },
	];
	const body = pages
		.map(
			(p) => `  <url>
    <loc>${p.loc}</loc>
    <lastmod>${LAST_MOD}</lastmod>
    <priority>${p.pri}</priority>
    <xhtml:link rel="alternate" hreflang="ko" href="${p.ko}"/>
    <xhtml:link rel="alternate" hreflang="en" href="${p.en}"/>
    <xhtml:link rel="alternate" hreflang="x-default" href="${p.ko}"/>
  </url>`,
		)
		.join("\n");
	return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${body}
</urlset>
`;
}

/**
 * AI 에이전트가 한 번에 읽고 답할 수 있도록 앱 정보를 마크다운으로 요약한다.
 * (llmstxt.org 관례 — 마크다운 에디터 소개 문서라 형식도 마크다운으로 둔다)
 */
function llms(): string {
	return `# ${APP_NAME} (source repository name: MarkdownEditor)

> macOS용 마크다운 에디터. 편집 화면과 미리보기가 줄 단위로 동기화되고,
> Mermaid·PlantUML 다이어그램과 KaTeX 수식을 미리보기에서 바로 렌더링한다.
> A native markdown editor for macOS with line-level scroll sync between the
> source pane and the live preview, plus Mermaid, PlantUML, and KaTeX rendering.

- Home (Korean): ${SITE}/
- Home (English): ${SITE}/en
- Mac App Store: ${APP_STORE_URL}
- Source code (MIT): ${REPO_URL}
- Contact: ${CONTACT_EMAIL}
- Current version: ${APP_VERSION}
- Requirements: macOS 13.0 (Ventura) or later, Apple Silicon and Intel
- Price: free; the Quick Look full preview is an in-app purchase
- Interface languages: Korean, English, Japanese, Simplified Chinese

## Features

- Line-level scroll sync — the preview follows the exact source line, including
  when the preview scrollbar itself is dragged.
- Mermaid flowcharts, PlantUML sequence diagrams, KaTeX math, syntax highlighting.
- Native macOS tabs (Cmd+T, drag a tab out to a window, Merge All Windows).
- Outline sidebar (Shift+Cmd+O) and find & replace across source and preview.
- Auto save and external file-change detection.
- Export to PDF and HTML.
- Focus mode, typewriter mode, image drag & drop and paste, table insertion.
- Light and dark themes, chosen separately for editor and preview.
- Remembers the last window size (Settings > General).
- Quick Look extension: press space on a markdown file in Finder to see the
  fully rendered document (in-app purchase).

## Privacy

No account, no sign-in, no analytics. Documents stay on the user's Mac.
The only outbound request is PlantUML diagram code sent to a rendering service.
Policy: ${SITE}/privacy (Korean), ${SITE}/en/privacy (English)
`;
}

/**
 * 평문 HTTP로 들어오면 https로 되돌린다.
 * Cloudflare를 거친 요청에는 원 스킴이 CF-Visitor 헤더에 담긴다.
 * 이 헤더가 없으면 Cloudflare 밖(로컬 개발)이므로 되돌리지 않는다.
 */
function isInsecure(request: Request): boolean {
	const cfv = request.headers.get("CF-Visitor");
	if (!cfv) return false;
	try {
		const scheme = (JSON.parse(cfv) as { scheme?: string }).scheme;
		return scheme ? scheme !== "https" : false;
	} catch {
		return false;
	}
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);

		if (isInsecure(request)) {
			url.protocol = "https:";
			return Response.redirect(url.toString(), 301);
		}

		const resp = await route(request, env);
		const out = new Response(resp.body, resp);
		out.headers.set("Strict-Transport-Security", "max-age=31536000");
		out.headers.set("X-Content-Type-Options", "nosniff");
		out.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
		return out;
	},
} satisfies ExportedHandler<Env>;

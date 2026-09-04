/**
 * 페이지 조립. 검색 엔진과 AI 크롤러가 읽기 쉽도록
 * 의미 있는 태그, hreflang, 구조화 데이터(JSON-LD)를 함께 담는다.
 */
import { CSS } from "./styles";
import { COPY, type Copy, type Lang } from "./content";

export const SITE = "https://md-editor.zerolive.co.kr";
export const APP_STORE_URL = "https://apps.apple.com/app/id6756916654";
export const REPO_URL = "https://github.com/leonardo204/MarkdownEditor";
export const CONTACT_EMAIL = "zerolive7@gmail.com";
export const APP_NAME = "MarkChartEditor";
export const APP_VERSION = "1.5.9";

/** 언어별 경로. 한국어가 기본이고 영어는 /en 아래에 둔다. */
function paths(lang: Lang) {
	return {
		home: lang === "ko" ? "/" : "/en",
		privacy: lang === "ko" ? "/privacy" : "/en/privacy",
		other: lang === "ko" ? "/en" : "/",
	};
}

function esc(s: string): string {
	return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

interface ShellOpts {
	lang: Lang;
	title: string;
	desc: string;
	canonical: string;
	altKo: string;
	altEn: string;
	keywords?: string;
	jsonLd?: unknown[];
	body: string;
}

function appStoreBadge(c: Copy): string {
	return `<a href="${APP_STORE_URL}" target="_blank" rel="noopener" class="appstore-badge" aria-label="${esc(c.badgeAria)}">
  <svg width="168" height="50" viewBox="0 0 160 48" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
    <rect width="160" height="48" rx="9" fill="#000"/>
    <path d="M27.9 24.6c0-3.1 2.5-4.6 2.7-4.7-1.5-2.1-3.7-2.4-4.5-2.5-1.9-.2-3.8 1.1-4.7 1.1-1 0-2.5-1.1-4.1-1.1-2.1 0-4.1 1.2-5.1 3.1-2.2 3.8-.6 9.4 1.5 12.5 1.1 1.5 2.3 3.2 4 3.1 1.6-.1 2.2-1 4.2-1s2.5 1 4.2 1c1.7 0 2.9-1.5 4-3 1.3-1.7 1.8-3.4 1.8-3.5-.1 0-3.5-1.3-3.5-5.3zm-3.1-9.7c.9-1.1 1.5-2.6 1.3-4.2-1.3.1-2.9.9-3.8 2-.8 1-1.5 2.5-1.3 4 1.4.1 2.9-.7 3.8-1.8z" fill="#fff"/>
    <text x="49" y="20" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="9" fill="#fff" letter-spacing=".3">${esc(c.badgeSmall)}</text>
    <text x="49" y="36" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="17" font-weight="600" fill="#fff" letter-spacing="-.3">${esc(c.badgeBig)}</text>
  </svg>
</a>`;
}

function shell(o: ShellOpts): string {
	const c = COPY[o.lang];
	const p = paths(o.lang);
	const ld = (o.jsonLd ?? [])
		.map((x) => `<script type="application/ld+json">${JSON.stringify(x)}</script>`)
		.join("\n");

	return `<!DOCTYPE html>
<html lang="${c.htmlLang}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(o.title)}</title>
<meta name="description" content="${esc(o.desc)}">
${o.keywords ? `<meta name="keywords" content="${esc(o.keywords)}">` : ""}
<meta name="author" content="zerolive">
<meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1">
<link rel="canonical" href="${o.canonical}">
<link rel="alternate" hreflang="ko" href="${o.altKo}">
<link rel="alternate" hreflang="en" href="${o.altEn}">
<link rel="alternate" hreflang="x-default" href="${o.altKo}">
<meta property="og:site_name" content="${APP_NAME}">
<meta property="og:title" content="${esc(o.title)}">
<meta property="og:description" content="${esc(o.desc)}">
<meta property="og:url" content="${o.canonical}">
<meta property="og:type" content="website">
<meta property="og:locale" content="${o.lang === "ko" ? "ko_KR" : "en_US"}">
<meta property="og:image" content="${SITE}/assets/shot-main.jpg">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(o.title)}">
<meta name="twitter:description" content="${esc(o.desc)}">
<meta name="twitter:image" content="${SITE}/assets/shot-main.jpg">
<link rel="icon" href="/assets/icon.png">
<link rel="apple-touch-icon" href="/assets/icon.png">
<link rel="preconnect" href="https://cdn.jsdelivr.net">
<link href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css" rel="stylesheet">
<style>${CSS}</style>
${ld}
</head>
<body>

<nav class="nav">
  <div class="nav-inner">
    <a href="${p.home}" class="nav-logo">
      <img src="/assets/icon.png" alt="" width="30" height="30">
      <span>${APP_NAME}</span>
    </a>
    <div class="nav-links">
      <a href="${p.home}#features">${esc(c.navFeatures)}</a>
      <a href="${p.home}#screens">${esc(c.navScreens)}</a>
      <a href="${p.home}#quicklook">${esc(c.navQuickLook)}</a>
      <a href="${p.home}#faq">${esc(c.navFaq)}</a>
      <a href="${p.privacy}">${esc(c.navPrivacy)}</a>
    </div>
    <a class="lang" href="${p.other}" hreflang="${o.lang === "ko" ? "en" : "ko"}">${esc(c.langSwitchLabel)}</a>
  </div>
</nav>

${o.body}

<footer>
  <div class="container">
    <span>© 2026 ${APP_NAME} · ${esc(c.footerNote)}</span>
    <span>
      <a href="${p.privacy}">${esc(c.footerPrivacy)}</a> &nbsp;·&nbsp;
      <a href="${REPO_URL}" target="_blank" rel="noopener">${esc(c.footerSource)}</a> &nbsp;·&nbsp;
      <a href="mailto:${CONTACT_EMAIL}">${esc(c.footerContact)}</a>
    </span>
  </div>
</footer>

</body>
</html>`;
}

/** 앱 자체를 설명하는 구조화 데이터. 검색 결과의 앱 카드와 AI 답변의 근거가 된다. */
function appJsonLd(lang: Lang): unknown {
	const c = COPY[lang];
	return {
		"@context": "https://schema.org",
		"@type": "SoftwareApplication",
		name: APP_NAME,
		alternateName: ["MarkdownEditor", "Markdown Editor for Mac"],
		applicationCategory: "DeveloperApplication",
		applicationSubCategory: "Markdown Editor",
		operatingSystem: "macOS 13.0 or later",
		softwareVersion: APP_VERSION,
		url: SITE + (lang === "ko" ? "/" : "/en"),
		downloadUrl: APP_STORE_URL,
		installUrl: APP_STORE_URL,
		image: SITE + "/assets/icon.png",
		screenshot: [
			SITE + "/assets/shot-main.jpg",
			SITE + "/assets/shot-diagram.jpg",
			SITE + "/assets/shot-tabs.jpg",
		],
		description: c.desc,
		inLanguage: ["ko", "en", "ja", "zh-Hans"],
		featureList: c.features.map((f) => f.title),
		offers: {
			"@type": "Offer",
			price: "0",
			priceCurrency: "USD",
			availability: "https://schema.org/InStock",
			url: APP_STORE_URL,
		},
		author: { "@type": "Person", name: "YONGSUB LEE", email: CONTACT_EMAIL },
		license: "https://opensource.org/licenses/MIT",
		sameAs: [APP_STORE_URL, REPO_URL],
	};
}

function faqJsonLd(lang: Lang): unknown {
	const c = COPY[lang];
	return {
		"@context": "https://schema.org",
		"@type": "FAQPage",
		inLanguage: c.htmlLang,
		mainEntity: c.faqs.map((f) => ({
			"@type": "Question",
			name: f.q,
			acceptedAnswer: { "@type": "Answer", text: f.a },
		})),
	};
}

export function renderLanding(lang: Lang): string {
	const c = COPY[lang];
	const p = paths(lang);

	const body = `
<header class="hero">
  <div class="container">
    <div class="section-badge">${esc(c.heroBadge)}</div>
    <h1 class="section-title">${c.heroTitle}</h1>
    <p class="section-sub">${esc(c.heroSub)}</p>
    ${appStoreBadge(c)}
    <div class="hero-meta">${esc(c.heroMeta)}</div>
    <div class="hero-shot">
      <img src="/assets/shot-main.jpg" width="1760" height="1220"
           alt="${esc(c.heroShotAlt)}" fetchpriority="high">
    </div>
  </div>
</header>

<section id="features" class="section">
  <div class="container">
    <div class="text-center">
      <div class="section-badge">${esc(c.featBadge)}</div>
      <h2 class="section-title">${esc(c.featTitle)}</h2>
      <p class="section-sub mx-auto">${esc(c.featSub)}</p>
    </div>
    <div class="features-grid">
      ${c.features
				.map(
					(f) => `<article class="feature">
        <div class="ic" aria-hidden="true">${f.ic}</div>
        <h3>${esc(f.title)}</h3>
        <p>${esc(f.body)}</p>
      </article>`,
				)
				.join("\n      ")}
    </div>
  </div>
</section>

<section id="screens" class="section alt">
  <div class="container">
    <div class="text-center">
      <div class="section-badge">${esc(c.shotBadge)}</div>
      <h2 class="section-title">${esc(c.shotTitle)}</h2>
      <p class="section-sub mx-auto">${esc(c.shotSub)}</p>
    </div>
    <div class="shots">
      ${c.shots
				.map(
					(s) => `<figure class="shot">
        <img src="${s.src}" loading="lazy" width="1760" height="1220" alt="${esc(s.alt)}">
        <figcaption class="cap"><h3>${esc(s.title)}</h3><p>${esc(s.body)}</p></figcaption>
      </figure>`,
				)
				.join("\n      ")}
    </div>
    <div class="chips">
      ${c.chips.map((t) => `<span class="chip">${t}</span>`).join("\n      ")}
    </div>
  </div>
</section>

<section id="quicklook" class="section">
  <div class="container">
    <div class="text-center">
      <div class="section-badge">${esc(c.qlBadge)}</div>
      <h2 class="section-title">${esc(c.qlTitle)}</h2>
    </div>
    <div class="split">
      <div class="panel">
        <h3>${esc(c.qlPanelTitle)}</h3>
        <p>${esc(c.qlPanelBody)}</p>
        <ul>${c.qlList.map((t) => `<li>${esc(t)}</li>`).join("")}</ul>
      </div>
      <div class="panel">
        <h3>${esc(c.langPanelTitle)}</h3>
        <p>${esc(c.langPanelBody)}</p>
        <ul>${c.langList.map((t) => `<li>${esc(t)}</li>`).join("")}</ul>
      </div>
    </div>
  </div>
</section>

<section id="privacy" class="section alt">
  <div class="container text-center">
    <div class="section-badge">${esc(c.privBadge)}</div>
    <h2 class="section-title">${esc(c.privTitle)}</h2>
    <p class="section-sub mx-auto">${esc(c.privSub)}</p>
    <p style="margin-top:20px"><a href="${p.privacy}">${esc(c.privLink)}</a></p>
  </div>
</section>

<section id="faq" class="section">
  <div class="container">
    <div class="text-center">
      <div class="section-badge">${esc(c.faqBadge)}</div>
      <h2 class="section-title">${esc(c.faqTitle)}</h2>
    </div>
    <div class="faq">
      ${c.faqs
				.map(
					(f) => `<details>
        <summary>${esc(f.q)}</summary>
        <p>${esc(f.a)}</p>
      </details>`,
				)
				.join("\n      ")}
    </div>
  </div>
</section>

<section class="cta">
  <div class="container">
    <h2 class="section-title">${esc(c.ctaTitle)}</h2>
    <p class="section-sub mx-auto" style="margin-bottom:26px">${esc(c.ctaSub)}</p>
    ${appStoreBadge(c)}
    <div class="hero-meta">${esc(c.heroMeta)}</div>
  </div>
</section>
`;

	return shell({
		lang,
		title: c.title,
		desc: c.desc,
		keywords: c.keywords,
		canonical: SITE + p.home,
		altKo: SITE + "/",
		altEn: SITE + "/en",
		jsonLd: [appJsonLd(lang), faqJsonLd(lang)],
		body,
	});
}

export function renderPrivacy(lang: Lang): string {
	const c = COPY[lang];
	const p = paths(lang);
	const body = `
<main class="doc">
  <h1>${esc(c.privacyTitle)}</h1>
  <p class="updated">${esc(c.privacyUpdated)}</p>
  ${c.privacyBody}
</main>`;

	return shell({
		lang,
		title: `${esc(c.privacyTitle)} — ${APP_NAME}`,
		desc: c.privacyDesc,
		canonical: SITE + p.privacy,
		altKo: SITE + "/privacy",
		altEn: SITE + "/en/privacy",
		body,
	});
}

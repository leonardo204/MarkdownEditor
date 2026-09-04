/**
 * 랜딩·개인정보처리방침 문구. 한국어가 기본이고 영어 페이지는 /en 에 둔다.
 * 문구를 고칠 때는 두 언어를 같이 고쳐 내용이 어긋나지 않게 한다.
 */

export type Lang = "ko" | "en";

export interface Feature {
	ic: string;
	title: string;
	body: string;
}
export interface Shot {
	src: string;
	alt: string;
	title: string;
	body: string;
}
export interface Faq {
	q: string;
	a: string;
}

export interface Copy {
	htmlLang: string;
	title: string;
	desc: string;
	keywords: string;
	navFeatures: string;
	navScreens: string;
	navQuickLook: string;
	navPrivacy: string;
	navFaq: string;
	langSwitchLabel: string;
	heroBadge: string;
	heroTitle: string;
	heroSub: string;
	badgeAria: string;
	badgeSmall: string;
	badgeBig: string;
	heroMeta: string;
	heroShotAlt: string;

	featBadge: string;
	featTitle: string;
	featSub: string;
	features: Feature[];

	shotBadge: string;
	shotTitle: string;
	shotSub: string;
	shots: Shot[];

	moreBadge: string;
	moreTitle: string;
	moreSub: string;
	chips: string[];

	qlBadge: string;
	qlTitle: string;
	qlSub: string;
	qlPanelTitle: string;
	qlPanelBody: string;
	qlList: string[];
	langPanelTitle: string;
	langPanelBody: string;
	langList: string[];

	privBadge: string;
	privTitle: string;
	privSub: string;
	privLink: string;

	faqBadge: string;
	faqTitle: string;
	faqs: Faq[];

	ctaTitle: string;
	ctaSub: string;

	footerNote: string;
	footerPrivacy: string;
	footerContact: string;
	footerSource: string;

	privacyTitle: string;
	privacyDesc: string;
	privacyUpdated: string;
	privacyBody: string;
}

const APP = "MarkChartEditor";

export const KO: Copy = {
	htmlLang: "ko",
	title: `${APP} — 맥용 마크다운 에디터, 실시간 미리보기와 스크롤 동기화`,
	desc: "macOS용 마크다운 에디터입니다. 쓰는 줄을 미리보기가 그대로 따라가고, Mermaid·PlantUML 다이어그램과 KaTeX 수식을 바로 보여줍니다. PDF·HTML 내보내기, 네이티브 탭, Quick Look 미리보기까지. macOS 13 이상, Mac App Store에서 무료로 받습니다.",
	keywords: "맥 마크다운 에디터, macOS 마크다운, 마크다운 편집기, Mermaid 미리보기, PlantUML, KaTeX 수식, 마크다운 PDF 변환, Quick Look 마크다운, markdown editor mac",
	navFeatures: "기능",
	navScreens: "화면",
	navQuickLook: "Quick Look",
	navPrivacy: "개인정보",
	navFaq: "자주 묻는 질문",
	langSwitchLabel: "English",
	heroBadge: "macOS 13 이상 · Mac App Store",
	heroTitle: `쓰는 줄을 <span class="accent">미리보기가 그대로</span> 따라옵니다`,
	heroSub:
		"맥에서 쓰는 마크다운 에디터입니다. 왼쪽에서 글을 쓰면 오른쪽 미리보기가 같은 줄에 머무릅니다. Mermaid와 PlantUML 다이어그램, 수식, 코드 색상 표시도 쓰는 즉시 그려집니다.",
	badgeAria: `App Store에서 ${APP} 받기`,
	badgeSmall: "Download on the",
	badgeBig: "App Store",
	heroMeta: "무료 · macOS 13(Ventura) 이상 · Apple Silicon과 Intel 모두 지원",
	heroShotAlt:
		"MarkChartEditor 화면: 왼쪽 어두운 편집 화면과 오른쪽 밝은 미리보기에 제목, 체크리스트, Swift 코드 블록이 나란히 보이는 모습",

	featBadge: "core features",
	featTitle: "글 쓰는 흐름을 끊지 않습니다",
	featSub: "마크다운을 쓰다가 결과를 확인하려고 멈추는 일이 없도록 만들었습니다.",
	features: [
		{
			ic: "≡",
			title: "줄 단위 스크롤 동기화",
			body: "보고 있는 줄을 미리보기가 그대로 따라갑니다. 휠과 트랙패드는 물론 스크롤 막대를 잡고 빠르게 끌어도 양쪽이 어긋나지 않습니다.",
		},
		{
			ic: "◇",
			title: "다이어그램과 수식",
			body: "Mermaid 순서도, PlantUML 시퀀스 다이어그램, KaTeX 수식, 코드 색상 표시를 미리보기에서 바로 확인합니다. 따로 도구를 열 필요가 없습니다.",
		},
		{
			ic: "⌘",
			title: "맥 그대로의 탭",
			body: "Safari나 Finder에서 쓰던 그 탭입니다. Cmd+T로 새 탭, 탭을 끌어내면 새 창, Window > Merge All Windows로 다시 하나로 모읍니다.",
		},
		{
			ic: "⌕",
			title: "아웃라인과 찾기·바꾸기",
			body: "제목 목록에서 원하는 곳으로 바로 이동합니다(Shift+Cmd+O). 찾기는 편집 화면과 미리보기 양쪽에서 되고, 결과를 표시해 줍니다.",
		},
		{
			ic: "↺",
			title: "자동 저장과 변경 감지",
			body: "쓰던 글은 잠시 멈추면 알아서 저장됩니다. 다른 프로그램이 같은 파일을 고치면 알려주고, 다시 불러올지 물어봅니다.",
		},
		{
			ic: "↧",
			title: "PDF와 HTML로 내보내기",
			body: "미리보기에서 보던 모양 그대로 PDF나 HTML 파일로 저장합니다. 다이어그램과 수식도 함께 담깁니다.",
		},
	],

	shotBadge: "screens",
	shotTitle: "실제로 이렇게 보입니다",
	shotSub: "어두운 화면과 밝은 화면을 편집 화면과 미리보기에서 따로 고를 수 있습니다.",
	shots: [
		{
			src: "/assets/shot-diagram.jpg",
			alt: "왼쪽 편집 화면의 Mermaid·PlantUML 코드가 오른쪽 미리보기에서 순서도와 시퀀스 다이어그램으로 그려진 모습",
			title: "쓰면 바로 그림이 됩니다",
			body: "코드 블록에 mermaid나 plantuml이라고 적으면 미리보기에서 그림으로 바뀝니다. 한글 라벨도 그대로 나옵니다.",
		},
		{
			src: "/assets/shot-tabs.jpg",
			alt: "문서 세 개를 탭으로 열어 둔 창에서 KaTeX 수식과 숫자 표가 미리보기에 그려진 모습",
			title: "여러 문서를 나란히",
			body: "탭으로 모아 두고 오가며 봅니다. KaTeX 수식과 표도 미리보기에서 그대로 그려집니다.",
		},
	],

	moreBadge: "also inside",
	moreTitle: "이런 것도 들어 있습니다",
	moreSub: "",
	chips: [
		"<b>집중 모드</b> 지금 문단만 또렷하게",
		"<b>타자기 모드</b> 커서를 화면 가운데 고정",
		"<b>이미지</b> 끌어놓기·붙여넣기",
		"<b>표 만들기</b> 칸 수를 눌러서 삽입",
		"<b>서식 단축키</b> ⌘B ⌘I ⌘K ⌘E",
		"<b>탭 이동</b> ⌘1 ~ ⌘9",
		"<b>줄 번호</b> 켜고 끄기",
		"<b>글꼴과 크기</b> 직접 지정",
	],

	qlBadge: "quick look · 4 languages",
	qlTitle: "Finder에서도, 내 언어로도",
	qlSub: "",
	qlPanelTitle: "스페이스바로 바로 보기",
	qlPanelBody:
		"Finder에서 마크다운 파일을 고르고 스페이스바를 누르면 앱을 열지 않아도 완성된 문서로 보입니다. 인앱 구입 항목입니다.",
	qlList: [
		"Mermaid·PlantUML 다이어그램 그대로",
		"KaTeX 수식과 코드 색상 표시",
		"표, 체크리스트, 이미지까지 그대로",
	],
	langPanelTitle: "4개 언어를 지원합니다",
	langPanelBody:
		"메뉴부터 설정 화면, 알림창까지 모두 번역했습니다. 설정 > General에서 고르고, 기본값은 시스템 언어를 따릅니다.",
	langList: ["한국어", "English", "日本語", "简体中文"],

	privBadge: "privacy",
	privTitle: "쓴 글은 내 맥에만 남습니다",
	privSub:
		"계정도 로그인도 없습니다. 문서를 서버로 올리지 않고, 사용 기록을 모으지도 않습니다. PlantUML 그림을 그릴 때만 그 다이어그램 코드가 렌더링 서버로 갑니다.",
	privLink: "개인정보처리방침 읽기",

	faqBadge: "faq",
	faqTitle: "자주 묻는 질문",
	faqs: [
		{
			q: "무료인가요?",
			a: "앱은 무료입니다. Finder에서 스페이스바로 여는 Quick Look 전체 미리보기만 인앱 구입 항목입니다.",
		},
		{
			q: "어떤 macOS가 필요한가요?",
			a: "macOS 13(Ventura) 이상이면 됩니다. Apple Silicon(M1·M2·M3)과 Intel Mac 모두 동작합니다.",
		},
		{
			q: "Mermaid와 PlantUML을 지원하나요?",
			a: "네. 코드 블록 언어를 mermaid 또는 plantuml로 적으면 미리보기에서 그림으로 그려집니다. KaTeX 수식과 코드 색상 표시도 함께 지원합니다.",
		},
		{
			q: "쓴 문서가 서버로 전송되나요?",
			a: "아니요. 문서는 Mac에만 저장됩니다. 계정과 로그인이 없고 사용 기록도 모으지 않습니다. 예외는 PlantUML 다이어그램 하나로, 그림을 그릴 때 그 코드만 렌더링 서버로 갑니다.",
		},
		{
			q: "한국어 말고 다른 언어로도 쓸 수 있나요?",
			a: "한국어, English, 日本語, 简体中文을 지원합니다. 설정 > General에서 고르고, 기본은 시스템 언어를 따릅니다. 언어를 바꾼 뒤에는 앱을 다시 켜면 적용됩니다.",
		},
		{
			q: "마크다운 파일의 기본 앱으로 지정할 수 있나요?",
			a: "네. Finder에서 .md 파일을 우클릭해 정보 가져오기를 열고, 다음으로 열기에서 이 앱을 고른 뒤 모두 변경을 누르면 됩니다.",
		},
		{
			q: "PDF로 저장할 수 있나요?",
			a: "파일 메뉴의 PDF로 내보내기를 쓰면 미리보기에서 보던 모양 그대로 저장됩니다. HTML로 내보내기도 있습니다.",
		},
		{
			q: "App Store 이름이 왜 MarkChartEditor인가요?",
			a: "Mac App Store 등록명이 MarkChartEditor입니다. 소스 저장소 이름은 MarkdownEditor로, 같은 앱입니다.",
		},
	],

	ctaTitle: "지금 받아서 써보세요",
	ctaSub: "Mac App Store에서 무료로 내려받습니다.",

	footerNote: "개인 개발 프로젝트 · MIT 라이선스",
	footerPrivacy: "개인정보처리방침",
	footerContact: "문의",
	footerSource: "소스 코드",

	privacyTitle: "개인정보처리방침",
	privacyDesc: "MarkChartEditor는 개인정보를 수집하지 않습니다. 문서는 사용자의 Mac에만 저장됩니다.",
	privacyUpdated: "최종 수정일: 2025년 12월 23일",
	privacyBody: `
<h2>한 줄 요약</h2>
<p>이 앱은 어떤 개인정보도 모으지 않습니다. 계정과 로그인이 없고, 쓴 문서는 사용자의 Mac에만 저장됩니다.</p>

<h2>모으지 않는 것</h2>
<ul>
<li>사용자 계정을 만들지 않고 로그인을 요구하지 않습니다</li>
<li>문서 내용을 서버로 보내지 않습니다</li>
<li>사용 기록을 분석하거나 추적하지 않습니다</li>
<li>광고를 표시하지 않습니다</li>
</ul>

<h2>문서 저장 위치</h2>
<p>앱에서 쓰고 고친 마크다운 문서는 모두 사용자의 기기에만 저장됩니다. 개발자나 제3자에게 전달되지 않습니다.</p>

<h2>네트워크를 쓰는 경우</h2>
<p>다음 두 가지뿐입니다.</p>
<ul>
<li><b>PlantUML 다이어그램</b> — 그림을 그리기 위해 다이어그램 코드가 렌더링 서버로 전송됩니다. 개인정보는 담기지 않습니다.</li>
<li><b>인앱 구입</b> — Quick Look 미리보기를 살 때 Apple의 StoreKit을 거칩니다. 결제 정보는 Apple이 처리하며 개발자는 카드 정보를 받지 않습니다.</li>
</ul>
<p>그 밖에는 완전히 오프라인으로 동작합니다.</p>

<h2>제3자 제공</h2>
<p>모으는 개인정보가 없으므로 제3자에게 넘기는 정보도 없습니다.</p>

<h2>아동의 개인정보</h2>
<p>어떤 사용자로부터도 개인정보를 모으지 않으므로 아동의 개인정보 또한 모으지 않습니다.</p>

<h2>방침이 바뀔 때</h2>
<p>내용이 바뀌면 이 페이지에 새 내용과 수정일을 올립니다.</p>

<h2>문의</h2>
<p>궁금한 점은 <a href="mailto:zerolive7@gmail.com">zerolive7@gmail.com</a>으로 보내주세요.</p>
`,
};

export const EN: Copy = {
	htmlLang: "en",
	title: `${APP} — Markdown Editor for Mac with Live Preview and Scroll Sync`,
	desc: "A native macOS markdown editor. The preview follows the exact line you are writing, and Mermaid, PlantUML, and KaTeX render as you type. Export to PDF and HTML, native tabs, Quick Look preview. macOS 13 or later, free on the Mac App Store.",
	keywords:
		"markdown editor mac, macOS markdown editor, mermaid preview, plantuml mac, katex, markdown to pdf, quick look markdown, live preview markdown editor",
	navFeatures: "Features",
	navScreens: "Screens",
	navQuickLook: "Quick Look",
	navPrivacy: "Privacy",
	navFaq: "FAQ",
	langSwitchLabel: "한국어",
	heroBadge: "macOS 13+ · Mac App Store",
	heroTitle: `The preview follows <span class="accent">the exact line</span> you write`,
	heroSub:
		"A markdown editor built for the Mac. Write on the left and the preview stays on the same line on the right. Mermaid and PlantUML diagrams, math, and syntax highlighting render as you type.",
	badgeAria: `Download ${APP} on the App Store`,
	badgeSmall: "Download on the",
	badgeBig: "App Store",
	heroMeta: "Free · macOS 13 (Ventura) or later · Apple Silicon and Intel",
	heroShotAlt:
		"MarkChartEditor window with the dark editor on the left and a light live preview on the right showing headings, a checklist, and a Swift code block",

	featBadge: "core features",
	featTitle: "Nothing interrupts the writing",
	featSub: "Built so you never have to stop writing just to check how it looks.",
	features: [
		{
			ic: "≡",
			title: "Line-level scroll sync",
			body: "The preview tracks the line you are looking at. Wheel, trackpad, and dragging the scrollbar itself all stay in step — no drift between the two panes.",
		},
		{
			ic: "◇",
			title: "Diagrams and math",
			body: "Mermaid flowcharts, PlantUML sequence diagrams, KaTeX math, and syntax highlighting render directly in the preview. No extra tool to open.",
		},
		{
			ic: "⌘",
			title: "Real macOS tabs",
			body: "The same tabs you know from Safari and Finder. Cmd+T for a new tab, drag a tab out for a new window, Window > Merge All Windows to bring them back.",
		},
		{
			ic: "⌕",
			title: "Outline, find and replace",
			body: "Jump anywhere from the heading list (Shift+Cmd+O). Search runs in both the source and the rendered preview, with matches highlighted.",
		},
		{
			ic: "↺",
			title: "Auto save and change detection",
			body: "Your file saves itself moments after you pause. If another app edits the same file, you are told and asked whether to reload it.",
		},
		{
			ic: "↧",
			title: "Export to PDF and HTML",
			body: "Save exactly what you see in the preview as a PDF or an HTML file, diagrams and math included.",
		},
	],

	shotBadge: "screens",
	shotTitle: "Here is what it looks like",
	shotSub: "Light and dark themes can be chosen separately for the editor and the preview.",
	shots: [
		{
			src: "/assets/shot-diagram.jpg",
			alt: "Mermaid and PlantUML source on the left rendered as flowcharts and sequence diagrams in the preview on the right",
			title: "Type it, see it drawn",
			body: "Mark a code block as mermaid or plantuml and the preview turns it into a diagram, non-Latin labels included.",
		},
		{
			src: "/assets/shot-tabs.jpg",
			alt: "One window with three documents open as tabs, the preview showing KaTeX formulas and a numeric table",
			title: "Several documents side by side",
			body: "Keep them in tabs and switch as you go. KaTeX formulas and tables render in the preview too.",
		},
	],

	moreBadge: "also inside",
	moreTitle: "Also in the box",
	moreSub: "",
	chips: [
		"<b>Focus mode</b> current paragraph only",
		"<b>Typewriter mode</b> cursor stays centred",
		"<b>Images</b> drag, drop, paste",
		"<b>Tables</b> pick the grid size",
		"<b>Formatting keys</b> ⌘B ⌘I ⌘K ⌘E",
		"<b>Tab switching</b> ⌘1 – ⌘9",
		"<b>Line numbers</b> on or off",
		"<b>Font and size</b> your choice",
	],

	qlBadge: "quick look · 4 languages",
	qlTitle: "In Finder too, and in your language",
	qlSub: "",
	qlPanelTitle: "Press space in Finder",
	qlPanelBody:
		"Select a markdown file in Finder, press the space bar, and the fully rendered document appears without opening the app. Available as an in-app purchase.",
	qlList: [
		"Mermaid and PlantUML diagrams intact",
		"KaTeX math and syntax highlighting",
		"Tables, checklists, and images as rendered",
	],
	langPanelTitle: "Four languages",
	langPanelBody:
		"Menus, settings, and alerts are all translated. Pick one in Settings > General; the default follows your system language.",
	langList: ["한국어", "English", "日本語", "简体中文"],

	privBadge: "privacy",
	privTitle: "What you write stays on your Mac",
	privSub:
		"No account, no sign-in. Documents are never uploaded and no usage data is collected. The one exception is PlantUML: rendering a diagram sends that diagram code to a rendering service.",
	privLink: "Read the privacy policy",

	faqBadge: "faq",
	faqTitle: "Frequently asked questions",
	faqs: [
		{
			q: "Is it free?",
			a: "The app is free. Only the Quick Look full preview — pressing space on a markdown file in Finder — is an in-app purchase.",
		},
		{
			q: "Which macOS do I need?",
			a: "macOS 13 (Ventura) or later. It runs on both Apple Silicon (M1/M2/M3) and Intel Macs.",
		},
		{
			q: "Does it support Mermaid and PlantUML?",
			a: "Yes. Mark a code block as mermaid or plantuml and the preview renders it as a diagram. KaTeX math and syntax highlighting are supported as well.",
		},
		{
			q: "Are my documents uploaded anywhere?",
			a: "No. Files stay on your Mac. There is no account, no sign-in, and no analytics. The single exception is PlantUML, where the diagram code is sent to a rendering service to produce the image.",
		},
		{
			q: "Can I use it in a language other than Korean?",
			a: "It ships in Korean, English, Japanese, and Simplified Chinese. Choose one in Settings > General; the default follows your system language. Relaunch the app to apply the change.",
		},
		{
			q: "Can I make it the default app for .md files?",
			a: "Yes. In Finder, right-click a .md file, choose Get Info, pick this app under Open with, then click Change All.",
		},
		{
			q: "Can I save as PDF?",
			a: "Use File > Export as PDF and you get exactly what the preview shows. Export as HTML is available too.",
		},
		{
			q: "Why is it called MarkChartEditor on the App Store?",
			a: "MarkChartEditor is the registered Mac App Store name. The source repository is named MarkdownEditor — same app.",
		},
	],

	ctaTitle: "Get it and start writing",
	ctaSub: "Free on the Mac App Store.",

	footerNote: "An indie project · MIT licensed",
	footerPrivacy: "Privacy Policy",
	footerContact: "Contact",
	footerSource: "Source code",

	privacyTitle: "Privacy Policy",
	privacyDesc: "MarkChartEditor collects no personal data. Your documents stay on your Mac.",
	privacyUpdated: "Last updated: 23 December 2025",
	privacyBody: `
<h2>In one line</h2>
<p>This app collects no personal data. There is no account and no sign-in, and everything you write stays on your own Mac.</p>

<h2>What is not collected</h2>
<ul>
<li>No user accounts and no sign-in</li>
<li>Document contents are never sent to a server</li>
<li>No analytics and no tracking</li>
<li>No advertising</li>
</ul>

<h2>Where documents are stored</h2>
<p>Every markdown file you write or edit is stored on your device only. Nothing is passed to the developer or to any third party.</p>

<h2>When the network is used</h2>
<p>Only in these two cases.</p>
<ul>
<li><b>PlantUML diagrams</b> — the diagram code is sent to a rendering service to produce the image. It carries no personal data.</li>
<li><b>In-app purchase</b> — buying the Quick Look preview goes through Apple's StoreKit. Apple handles payment; the developer never receives card details.</li>
</ul>
<p>Otherwise the app works entirely offline.</p>

<h2>Third parties</h2>
<p>Since no personal data is collected, none is shared.</p>

<h2>Children</h2>
<p>No personal data is collected from any user, and therefore none from children.</p>

<h2>Changes to this policy</h2>
<p>If anything changes, the updated text and its date are posted on this page.</p>

<h2>Contact</h2>
<p>Questions are welcome at <a href="mailto:zerolive7@gmail.com">zerolive7@gmail.com</a>.</p>
`,
};

export const COPY: Record<Lang, Copy> = { ko: KO, en: EN };

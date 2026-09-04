/**
 * 랜딩·정책 페이지 공통 스타일.
 * 다른 zerolive 앱 랜딩(golf, wander)과 같은 결 — 흰 바탕, 한 가지 강조색, 이모지 최소.
 * 강조색은 앱 아이콘의 파랑에서 가져왔다.
 */
export const CSS = `
:root{
  --blue:#4A8CF7;--blue-dark:#2C63C4;--blue-light:#8FBBFF;--blue-bg:#EDF4FF;
  --dark:#141C26;--mid:#586475;--light:#8A94A3;
  --surface:#F8FAFD;--border:#E4EAF2;--white:#fff;
  --ink-code:#1B2430;
  --radius:14px;--radius-lg:22px;--radius-xl:30px;
  --shadow:0 2px 16px rgba(20,28,38,.05);
  --shadow-lg:0 10px 38px rgba(74,140,247,.16);
  --font:'Pretendard Variable',Pretendard,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
  --mono:'SF Mono',ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
}
*{margin:0;padding:0;box-sizing:border-box}
html{scroll-behavior:smooth}
body{font-family:var(--font);color:var(--dark);background:var(--white);line-height:1.65;
  -webkit-font-smoothing:antialiased;word-break:keep-all}
img{max-width:100%;display:block}
a{color:var(--blue-dark);text-decoration:none}
a:hover{text-decoration:underline}

/* ── 상단 바 */
.nav{position:fixed;top:0;left:0;right:0;z-index:100;background:rgba(255,255,255,.85);
  backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);border-bottom:1px solid rgba(228,234,242,.7)}
.nav-inner{max-width:1080px;margin:0 auto;padding:0 24px;height:64px;display:flex;
  align-items:center;justify-content:space-between;gap:16px}
.nav-logo{display:flex;align-items:center;gap:10px;color:var(--dark);font-weight:700;font-size:16px;
  letter-spacing:-.3px;text-decoration:none;white-space:nowrap}
.nav-logo img{width:30px;height:30px;border-radius:7px}
.nav-links{display:flex;align-items:center;gap:22px}
.nav-links a{color:var(--mid);font-size:14px;font-weight:600;text-decoration:none}
.nav-links a:hover{color:var(--blue-dark)}
.lang{font-size:13px;font-weight:700;color:var(--light);border:1px solid var(--border);
  border-radius:999px;padding:5px 12px;text-decoration:none}
.lang:hover{color:var(--blue-dark);border-color:var(--blue-light);text-decoration:none}

.container{max-width:1080px;margin:0 auto;padding:0 24px}
.text-center{text-align:center}
.mx-auto{margin-left:auto;margin-right:auto}

/* ── 섹션 공통 */
.section{padding:88px 0}
.section.alt{background:var(--surface);border-top:1px solid var(--border);border-bottom:1px solid var(--border)}
.section-badge{display:inline-block;font-size:12px;font-weight:800;letter-spacing:1.2px;
  text-transform:uppercase;color:var(--blue-dark);background:var(--blue-bg);
  border-radius:999px;padding:6px 14px;margin-bottom:18px}
.section-title{font-size:clamp(25px,3.6vw,38px);font-weight:800;letter-spacing:-1.1px;line-height:1.3;
  margin-bottom:16px}
.section-sub{font-size:clamp(15px,1.7vw,17.5px);color:var(--mid);max-width:660px}
.section-sub.mx-auto{margin-left:auto;margin-right:auto}
.accent{color:var(--blue)}

/* ── 히어로 */
.hero{padding:132px 0 72px;text-align:center;
  background:radial-gradient(120% 90% at 50% -10%,var(--blue-bg) 0%,#fff 62%)}
.hero .section-title{max-width:820px;margin-left:auto;margin-right:auto}
.hero .section-sub{margin:0 auto 30px}
.appstore-badge{display:inline-block;transition:transform .2s}
.appstore-badge:hover{transform:translateY(-2px);text-decoration:none}
.hero-meta{margin-top:14px;font-size:13.5px;color:var(--light)}
.hero-shot{margin-top:48px;border-radius:var(--radius-lg);overflow:hidden;
  border:1px solid var(--border);box-shadow:var(--shadow-lg)}

/* ── 기능 카드 */
.features-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin-top:44px}
.feature{background:var(--white);border:1px solid var(--border);border-radius:var(--radius-lg);
  padding:28px 26px;box-shadow:var(--shadow);transition:transform .28s,box-shadow .28s}
.feature:hover{transform:translateY(-5px);box-shadow:var(--shadow-lg)}
.feature .ic{width:40px;height:40px;border-radius:11px;background:var(--blue-bg);color:var(--blue-dark);
  display:grid;place-items:center;font-size:18px;font-weight:800;margin-bottom:15px;font-family:var(--mono)}
.feature h3{font-size:17.5px;font-weight:800;letter-spacing:-.4px;margin-bottom:8px}
.feature p{font-size:14.5px;color:var(--mid)}

/* ── 화면 소개 */
.shots{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-top:44px}
.shot{background:var(--white);border:1px solid var(--border);border-radius:var(--radius-lg);
  overflow:hidden;box-shadow:var(--shadow)}
.shot img{width:100%}
.shot .cap{padding:18px 22px 22px}
.shot .cap h3{font-size:16.5px;font-weight:800;margin-bottom:6px;letter-spacing:-.3px}
.shot .cap p{font-size:14px;color:var(--mid)}

/* ── 나열 칩 */
.chips{display:flex;flex-wrap:wrap;gap:10px;justify-content:center;margin-top:36px}
.chip{background:var(--white);border:1px solid var(--border);border-radius:999px;
  padding:10px 18px;font-size:14px;font-weight:600;color:var(--mid);box-shadow:var(--shadow)}
.chip b{color:var(--dark);font-weight:800}

/* ── 두 칸 강조 */
.split{display:grid;grid-template-columns:1fr 1fr;gap:28px;align-items:center;margin-top:44px}
.split .panel{background:var(--white);border:1px solid var(--border);border-radius:var(--radius-lg);
  padding:30px;box-shadow:var(--shadow)}
.split h3{font-size:20px;font-weight:800;letter-spacing:-.5px;margin-bottom:10px}
.split p{font-size:15px;color:var(--mid)}
.split ul{margin:14px 0 0 18px;color:var(--mid);font-size:14.5px}
.split li{margin-bottom:6px}

/* ── FAQ */
.faq{max-width:760px;margin:40px auto 0}
.faq details{background:var(--white);border:1px solid var(--border);border-radius:var(--radius);
  padding:18px 22px;margin-bottom:12px;box-shadow:var(--shadow)}
.faq summary{font-size:16px;font-weight:700;cursor:pointer;list-style:none;letter-spacing:-.3px}
.faq summary::-webkit-details-marker{display:none}
.faq summary::after{content:"+";float:right;color:var(--blue);font-weight:800}
.faq details[open] summary::after{content:"−"}
.faq p{margin-top:12px;font-size:14.5px;color:var(--mid)}

/* ── 마지막 안내 */
.cta{text-align:center;padding:96px 0;
  background:linear-gradient(160deg,var(--blue-bg),#fff 70%)}

/* ── 본문 문서(개인정보처리방침) */
.doc{max-width:760px;margin:0 auto;padding:120px 24px 80px}
.doc h1{font-size:30px;font-weight:800;letter-spacing:-.9px;margin-bottom:8px}
.doc .updated{color:var(--light);font-size:13.5px;margin-bottom:34px}
.doc h2{font-size:19px;font-weight:800;margin:34px 0 10px;letter-spacing:-.4px}
.doc p{font-size:15px;color:var(--mid);margin-bottom:12px}
.doc ul{margin:0 0 14px 20px;color:var(--mid);font-size:15px}
.doc li{margin-bottom:6px}

/* ── 바닥 */
footer{border-top:1px solid var(--border);padding:34px 0 48px;color:var(--light);font-size:13.5px}
footer .container{display:flex;flex-wrap:wrap;gap:12px 22px;align-items:center;justify-content:space-between}
footer a{color:var(--light);font-weight:600}

@media(max-width:900px){
  .features-grid{grid-template-columns:1fr 1fr}
  .shots,.split{grid-template-columns:1fr}
}
@media(max-width:640px){
  .nav-links{display:none}
  .hero{padding:108px 0 56px}
  .section{padding:64px 0}
  .features-grid{grid-template-columns:1fr}
}
@media(prefers-reduced-motion:reduce){
  *,*::before,*::after{animation:none !important;transition:none !important}
  html{scroll-behavior:auto}
}
`;

# 랜딩 페이지 (md-editor.zerolive.co.kr)

Cloudflare Workers로 올린 앱 소개 페이지입니다. 앱 자체는 Mac App Store에서 배포하고,
이 worker는 소개 페이지와 개인정보처리방침만 맡습니다.

## 경로

| 경로 | 내용 |
|------|------|
| `/` | 한국어 소개 |
| `/en` | 영어 소개 |
| `/privacy`, `/en/privacy` | 개인정보처리방침 |
| `/robots.txt` | 검색 엔진·AI 크롤러 안내 (모두 허용) |
| `/sitemap.xml` | 사이트맵 (hreflang 포함) |
| `/llms.txt` | AI 에이전트용 요약 (llmstxt.org 관례) |
| `/assets/*` | 아이콘과 화면 사진 |

## 파일

- `src/index.ts` — 경로 처리, robots·sitemap·llms.txt 생성
- `src/render.ts` — 페이지 조립, 메타 태그, 구조화 데이터(JSON-LD)
- `src/content.ts` — 한국어·영어 문구. **문구를 고칠 때는 두 언어를 같이 고칩니다.**
- `src/styles.ts` — 공통 스타일

## 개발과 배포

```bash
npm install --include=dev
npm run dev      # http://127.0.0.1:8787
npm run deploy   # md-editor.zerolive.co.kr 로 배포
```

## 화면 사진 갱신

저장소 루트의 원본을 줄여서 씁니다.

```bash
sips -Z 1760 docs/images/screenshot-main.png --out worker/public/assets/shot-main.png
sips -s format jpeg -s formatOptions 78 worker/public/assets/shot-main.png \
     --out worker/public/assets/shot-main.jpg
rm worker/public/assets/shot-main.png
```

## 검색 노출 관련 메모

- 앱 정보는 `SoftwareApplication`, 자주 묻는 질문은 `FAQPage` 구조화 데이터로 함께 내보냅니다.
- 새 버전을 낼 때 `src/render.ts`의 `APP_VERSION`과 `src/index.ts`의 `LAST_MOD`를 함께 올립니다.
- Google Search Console 소유 확인 태그는 아직 넣지 않았습니다. 발급받으면
  `src/render.ts`의 `<head>`에 `<meta name="google-site-verification" ...>`를 한 줄 넣습니다.

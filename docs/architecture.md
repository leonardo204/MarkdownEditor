# 아키텍처

## 프로젝트 구조

```
MarkdownEditor/
├── App/
│   └── MarkdownEditorApp.swift     # AppDelegate, DocumentManager, 메뉴 구성
├── Assets.xcassets/                # 앱 아이콘, AccentColor
├── Models/
│   ├── AppState.swift              # 앱 전역 상태 (테마, 에디터 설정, 아웃라인 설정)
│   ├── DirectoryBookmarkManager.swift # security-scoped bookmark 저장/복원
│   ├── MarkdownDocument.swift      # 마크다운 문서 모델
│   └── TabManager.swift            # 탭 관리
├── Views/
│   ├── ContentView.swift           # EditorPreviewSplitView, OutlineView, StatusBar
│   ├── DocumentContentView.swift   # 루트 SwiftUI 뷰 (에디터+프리뷰 통합)
│   ├── EditorView.swift            # 에디터 뷰
│   ├── SimpleEditorView.swift      # NSTextView 기반 에디터
│   ├── FindReplaceView.swift       # 찾기/바꾸기 (NSPanel + FindReplaceManager)
│   ├── PreviewView.swift           # WKWebView 프리뷰
│   ├── ToolbarView.swift           # 마크다운 서식 툴바
│   ├── TabBarView.swift            # 탭바 UI
│   └── SettingsView.swift          # 설정
├── Services/
│   ├── LocalImageSchemeHandler.swift # me-asset:// 스킴 핸들러 (로컬 이미지 + 번들 웹 리소스)
│   ├── MarkdownProcessor.swift     # swift-markdown AST → HTML 변환
│   └── StoreManager.swift          # StoreKit 2 IAP 관리 (싱글톤)
├── WindowManagement/
│   ├── TabService.swift            # 윈도우/문서 관리 싱글톤
│   └── DocumentWindowController.swift # 윈도우 컨트롤러
├── Resources/
│   ├── preview-light.css           # 라이트 테마 프리뷰 스타일
│   └── preview-dark.css            # 다크 테마 프리뷰 스타일
├── Info.plist
└── MarkdownEditor.entitlements

MarkdownQuickLook/                   # Quick Look Preview Extension
├── PreviewViewController.swift      # QL 미리보기 (Premium/Non-premium 분기)
├── Base.lproj/PreviewViewController.xib
├── Info.plist                       # QLSupportedContentTypes
└── MarkdownQuickLook.entitlements   # Sandbox + App Group

Packages/MarkdownCore/               # 공유 Swift 패키지
├── Package.swift
└── Sources/MarkdownCore/
    ├── MarkdownProcessor.swift      # AST → HTML (앱/Extension 공유)
    ├── MarkdownImageHelper.swift    # 이미지 src 재작성 (me-asset 스킴 / base64 / placeholder)
    ├── BundledWebResources.swift    # 번들 JS/CSS 화이트리스트 (CDN 대체)
    ├── HTMLTemplate.swift           # HTML 래핑 (CDN/로컬 리소스)
    ├── PreviewTheme.swift           # 테마 enum + resourceBundleURL
    └── Resources/                   # JS/CSS 번들 (Mermaid, KaTeX 등)
```

## 핵심 아키텍처

- **생명주기**: 순수 AppKit (NSApplication + AppDelegate) + SwiftUI 뷰
- **파서**: apple/swift-markdown (SPM) AST 기반
- **윈도우 관리**: TabService 싱글톤 + 네이티브 윈도우 탭
- **상태 관리**: AppState (ObservableObject) - 테마, 폰트, 에디터 설정

## 프리뷰 리소스 서빙 (me-asset 스킴)

`LocalImageSchemeHandler`가 `WKURLSchemeHandler`로 두 종류를 서빙한다.

- `me-asset:///절대경로` → 로컬 이미지. `MarkdownImageHelper.rewriteLocalImages`가 `<img src>`를 이 형태로 재작성하고 `loading="lazy" decoding="async"` + 실제 픽셀 크기(`width`/`height`, EXIF 회전 반영)를 주입한다.
- `me-asset://bundle/파일명` → 번들된 JS/CSS. `BundledWebResources` 화이트리스트에 있는 파일만 서빙하며, 경로 구분자·`..`는 거부한다.

설계 근거:

- **base64 인라인을 쓰지 않는다.** 이미지를 data URI로 HTML에 넣으면 문서 크기가 폭증하고(이미지 56장 문서에서 358KB → 3.7MB) WKWebView 이미지 캐시를 타지 못한다.
- **`file://` 폴백은 불가능하다.** `loadHTMLString(_:baseURL:)`으로 로드한 페이지에서 WebKit은 `file://` 서브리소스를 CSP와 무관하게 차단한다. 해석 실패한 이미지는 시도한 경로를 보여주는 placeholder로 치환하고 `unresolvedCount`로 알린다.
- **CDN 대신 번들**: highlight.js·KaTeX·Mermaid·pako는 번들에서 서빙한다(콜드 로드 1.7초 → 0.2초대). `katex.min.css`만 폰트 미번들이라 CDN에 남기고 `media="print" onload` 로 논블로킹 로드한다.

## 스크롤 동기화 & 아웃라인 하이라이트

- `ScrollSyncManager`: 에디터 ↔ 프리뷰 간 퍼센트 기반 스크롤 동기화
- `currentLine` (0-based): 아웃라인 하이라이트의 기준값
- **업데이트 경로 2가지:**
  1. `textViewDidChangeSelection` → 커서 이동 시 (정확)
  2. `scrollViewDidScroll` → 에디터 스크롤 시 화면 상단 기준 (근사)
- **경합 방지 가드:**
  - `lastSelectionTime` (0.3초): 커서 이동 직후 스크롤 기반 덮어쓰기 방지
  - `lastOutlineClickTime` (1.0초): 아웃라인 클릭 → 프리뷰 smooth scroll 동기화 덮어쓰기 방지

### 에코 차단 (양방향)

동기화가 만든 스크롤이 되돌아와 반대편을 다시 밀면 두 패널이 서로를 끌어당긴다. 방향별로 다른 방식을 쓴다.

- **프리뷰 → 에디터**: 페이지 JS가 `wheel`/`mousedown`/`touch`/`keydown`을 추적해, **사용자 입력 700ms 이내의 scroll 이벤트만** 앱으로 보낸다. 프로그램적 스크롤과 이미지 리플로우는 입력이 없으므로 메시지 자체가 발생하지 않는다.
- **에디터 → 프리뷰**: `isProgrammaticEditorScroll` 구간 플래그. `setBoundsOrigin` **직전**에 세우고 다음 런루프 턴에 해제한다.
- **방향 우선순위**: 사용자가 에디터를 스크롤한 뒤 0.5초간은 프리뷰→에디터 동기화를 무시한다.
- **로드 정착 창**: 페이지 로드 후 0.4초간 프리뷰→에디터 동기화를 억제한다(크기 미상 원격 이미지의 초기 리플로우 차단).

> ⚠️ **벽시계 타이머로 에코를 판별하지 말 것.** 이전 구현은 0.15초 타이머를 썼는데, 이미지가 많은 문서에서 WebView 왕복이 그 임계값을 넘으면 에코가 새어 동기화가 0.65Hz까지 떨어졌다.
> ⚠️ **`setBoundsOrigin` 1회는 `boundsDidChange`를 2건 post한다**(가시 창의 copy-on-scroll 경로). 알림 건수를 세는 방식은 창 가시성·AppKit 버전에 따라 깨지므로 구간으로 덮는다.

### 대용량 문서 레이아웃

- 문서 로드 후 `ensureLayout(forCharacterRange:)`를 8,000자 청크로 돌려 **전체 글리프를 미리 생성**한다(첫 화면 표시 이후 진행, 청크마다 런루프 양보, 문서 교체 시 세대 카운터로 중단).
- 이유: 프리뷰 스크롤이 에디터를 임의 위치로 점프시킬 때 미레이아웃 영역의 글리프 생성이 단일 호출로 589ms까지 블로킹했다. 사전 계산 후 0.8ms.
- 프로그램적 스크롤 중에는 `scrollViewDidScroll`의 글리프 조회·라인 계산을 건너뛰고 150ms 디바운스로 1회만 수행한다.
- 스크롤 오프셋(`EditorScrollState`)과 아웃라인 커서 라인(`OutlineState`)은 별도 `ObservableObject`로 분리해, 소유자는 보관만 하고 실제 소비 뷰(라인 번호·아웃라인)만 구독한다. `@State`로 두면 스크롤 틱마다 에디터+프리뷰 전체가 재평가된다.

> ⚠️ **`allowsNonContiguousLayout = true`를 켜지 말 것.** 이 문서(366KB)에서 `documentView` 높이를 실제 190,406pt의 약 1/3(57,570~62,148pt)로 과소 추정해 **스크롤 가능 범위가 잘렸다**. 스크롤 틱도 3.4배 증폭됐다.

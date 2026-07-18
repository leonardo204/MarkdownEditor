# 변경 이력

## v1.5.5 (Build 25)
- fix: Mermaid 라벨의 마크다운 오파싱 수정
  - `"1. 항목"`처럼 블록 마커로 시작하는 라벨이 `Unsupported markdown: list`로 그려지던 문제
  - mermaid 11이 노드·엣지 라벨을 마크다운으로 파싱하는 것이 원인
  - 라벨 선두에 폭 없는 공백(U+200B)을 넣어 블록 판정만 무력화 (표시 문자는 불변)
  - 순서 있는 목록(`1.`/`1)`), 불릿(`-`/`*`/`+`), 제목(`#`), 인용(`>`) 모두 대응
- fix: Mermaid 코드블록 HTML 이스케이프 추가
  - `</div>`·`a <b 5` 같은 텍스트가 HTML 파서에 먼저 먹혀 다이어그램 전체가 Parse error로 죽던 문제
  - `&`·`<`·`>`만 이스케이프 — mermaid가 innerHTML을 entityDecode 하므로 원문 그대로 복원, `<br>` 줄바꿈 영향 없음
- fix: Mermaid 렌더링 실패를 삼키던 빈 catch에 console.error 추가
- 본체·Quick Look 두 렌더링 파이프라인에 동일 적용

## v1.5.4 (Build 24)
- feat: 뷰어(프리뷰) 검색 지원
  - 커서/포커스 위치에 따라 에디터(소스) 또는 프리뷰(렌더 결과)에서 검색
  - 프리뷰 검색은 JS 기반 하이라이트 (전체 노랑 + 현재 주황), 카운터, 다음/이전, 대소문자 구분
  - 검색 바에 에디터/미리보기 대상 토글 추가, 프리뷰 검색 시 바꾸기 UI 숨김
  - 편집으로 프리뷰가 재로드돼도 검색 하이라이트 자동 재적용
- feat: 검색 UX 개선
  - TextField를 네이티브 NSSearchField로 교체 — 최근 검색 히스토리 + 초기화 메뉴 내장
  - 재오픈 시 검색어 유지 + 전체 선택, Enter/닫기 시 최근 검색 기록

## v1.5.3 (Build 23)
- feat: 로컬 이미지 렌더링 (App Sandbox 대응)
  - DirectoryBookmarkManager 추가 — security-scoped bookmark 저장/복원으로 디렉토리 접근 관리
  - 상위 디렉토리 북마크 자동 탐색
  - base64 임베딩 실패 시 `file://` URL 폴백
- feat: 프리뷰 링크 내비게이션 — 상대경로 `.md` 링크 클릭 시 앱 내에서 열기
- feat: 스마트 이미지 크기 조정 — optimized 모드에서 원본 너비가 max-width의 2배를 초과하면 자동 전체 너비 표시

## v1.5.2 (Build 22)
- feat: 프리뷰 on/off 토글 기능 추가
  - Editor 헤더에 Preview 토글 스위치 (SF Symbol + 텍스트)
  - 설정 > General에 Preview Pane 토글 추가
  - 프리뷰 off 시 에디터가 전체 너비를 차지
  - 프리뷰 off 시 HTML 렌더링 중단으로 성능 최적화
  - 앱 전역 설정 (UserDefaults 저장)
- fix: 라인 번호 스크롤 동기화 개선
  - SwiftUI ScrollView → NSView 기반 네이티브 렌더링으로 재작성
  - 에디터 스크롤과 라인 번호가 정확히 동기화
  - 보이는 라인만 그려서 대용량 파일 성능 향상
- feat: Quick Look 프리뷰 토글 연동
  - 프리미엄 + Preview ON: 풀 렌더링
  - 프리미엄 + Preview OFF: 안내 배너 + raw 마크다운
  - 미구매: 구매 배너 + raw 마크다운

## v1.5.1 (Build 21)
- fix: App Store Guideline 2.4.5(i) 대응
  - 메인앱/QL extension 양쪽에서 `temporary-exception.files.home-relative-path.read-only` 제거
  - QL extension: `embedLocalImages` 대신 `replaceLocalImagesWithPlaceholder`로 전환
  - QL extension: `startAccessingSecurityScopedResource` 추가

## v1.5.1 (Build 20)
- feat: Quick Look 및 에디터 프리뷰 이미지 렌더링 지원
  - MarkdownImageHelper를 MarkdownCore 공유 패키지로 이동
  - Quick Look extension에 `embedLocalImages` 적용 (base64 인라인)
  - 앱/QL extension에 temporary-exception 읽기 권한 추가 (샌드박스 대응) — Build 21에서 철회

## v1.5.0 (Build 19)
- feat: 이미지 삽입 기능 전면 개선
  - 이미지 파일 드래그 앤 드롭: NSSavePanel 없이 바로 상대경로/`file://` URL 삽입
  - Ctrl+O: NSOpenPanel로 이미지 파일 선택 후 마크다운 삽입
  - Cmd+V: 클립보드 이미지 감지 → NSSavePanel 저장
  - 프리뷰에서 로컬 이미지를 base64 data URI로 인라인 (WKWebView 샌드박스 대응)
  - 문서 외부 이미지는 `file://` 절대 URL, 내부 이미지는 상대경로
  - 다중 이미지 삽입 시 인덱스가 어긋나던 regex 치환 버그 수정
- feat: Quick Look 미리보기 윈도우 크기 기억
  - 닫을 때 뷰 크기를 App Group UserDefaults에 저장, 다음에 열 때 복원
  - 기본 크기 800x600으로 확대
- ui: 이미지 크기 설정 UI 추가
  - 설정에 이미지 렌더 모드(Optimized/Original)와 최대 너비 슬라이더 추가
  - 메뉴에 이미지 삽입 항목 추가 (Ctrl+O)
- fix: 새 윈도우/새 탭 동작을 macOS 표준 단축키에 맞춤
  - Cmd+N은 독립 윈도우(탭 병합 방지), Cmd+T는 기존 윈도우에 탭 추가
  - Dock의 "New Window"와 아이콘 클릭도 독립 윈도우로 생성
- fix: 멀티 윈도우 충돌 방지 — Notification 액션을 keyWindow 기준으로 스코핑
- fix: StoreKit IAP 상품 로드 실패 시 자동 재시도 (최대 5회, 10s→20s→30s) 및 로딩/에러 상태 UI 표시

## v1.4.0 (Build 18)
- feat: Quick Look Preview Extension 추가 (Premium)
  - Finder에서 마크다운 파일 스페이스바로 풀 렌더링 미리보기
  - Mermaid 다이어그램, KaTeX 수식, 코드 하이라이팅 지원
  - 시스템 다크/라이트 테마 자동 적용
  - Non-premium: 원본 텍스트 + 업그레이드 안내 배너
- feat: StoreKit 2 인앱 구입 (비소모품)
  - StoreManager 싱글톤 (구매/복원/트랜잭션 리스너)
  - App Group을 통한 앱-Extension 구매 상태 동기화
- feat: Premium 설정 탭 추가 (첫 번째 탭)
  - 한영 지원, 구매/복원 UI, 구매 완료 축하 애니메이션
- feat: MarkdownCore 로컬 Swift 패키지 추출
  - MarkdownProcessor, HTMLTemplate, PreviewTheme 공유
  - JS/CSS 리소스 번들링 (Mermaid, Highlight.js, KaTeX, Pako)

## v1.3.3 (Build 18)
- feat: 설정 변경 시 에디터에 실시간 반영 (테마, 폰트, 폰트 크기, 라인 번호)
  - AppState에서 UserDefaults.didChangeNotification 구독
- fix: About 탭 연도 표시에 천 단위 구분 기호(,) 표시되는 문제 수정
- fix: 특정 마크다운 콘텐츠 붙여넣기 시 swift-markdown parseBlockDirectives 크래시 수정
- feat: 단축키 안내에 아웃라인 토글(⇧⌘O) 추가

## v1.3.2 (Build 17)
- fix: 아웃라인 클릭 시 하이라이트가 잘못된 항목에 고정되는 버그 수정
  - 원인: 프리뷰 smooth scroll 동기화가 에디터 스크롤을 변경 → `currentLine` 덮어쓰기
  - 해결: `moveCursorToLine` 분리 + `lastOutlineClickTime` 기반 1초 억제 가드

## v1.3.1 (Build 16)
- feat: 아웃라인 클릭 스크롤 대상 설정 및 인덱스 버그 수정

## v1.3.0 (Build 15)
- feat: 대규모 기능 추가 (찾기/바꾸기, 아웃라인, 포커스모드, 내보내기 등)

## v1.2.0 (Build 13)
- fix: 순수 AppKit 생명주기 전환으로 App Store Guideline 4 근본 해결

## v1.2.0 (Build 12)
- fix: App Store Guideline 4 준수 - 윈도우 재오픈 메뉴 및 심사 리스크 수정

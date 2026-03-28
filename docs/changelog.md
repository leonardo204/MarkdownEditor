# 변경 이력

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

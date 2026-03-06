# 변경 이력

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

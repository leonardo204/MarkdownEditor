# Claude Code 개발 가이드

> 공통 규칙(Agent Delegation, 커밋 정책, Context DB 등)은 글로벌 설정(`~/.claude/CLAUDE.md`)을 따릅니다.
> 글로벌 미설치 시: `curl -fsSL https://raw.githubusercontent.com/leonardo204/dotclaude/main/install.sh | bash`

---

## Slim 정책

이 파일은 **100줄 이하**를 유지한다. 새 지침 추가 시:
1. 매 턴 참조 필요 → 이 파일에 1줄 추가
2. 상세/예시/테이블 → docs/claude/*.md에 작성 후 여기서 참조
3. ref-docs 헤더: `# 제목 — 한 줄 설명` (모델이 첫 줄만 보고 필요 여부 판단)

---

## PROJECT

### 개요

**MarkdownEditor** — macOS용 마크다운 에디터 앱 (AppKit 생명주기 + SwiftUI 뷰)

| 항목 | 값 |
|------|-----|
| 기술 스택 | macOS, AppKit + SwiftUI, swift-markdown (SPM), StoreKit 2 |
| 빌드 방법 | `xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor -configuration Release build` |
| 현재 버전 | v1.5.2, Build 22 |
| 아키텍처 | 순수 AppKit 생명주기 + SwiftUI 뷰, TabService 싱글톤, 네이티브 윈도우 탭 |
| 상태 | App Store 출시 |

### 주요 기능

- swift-markdown 기반 마크다운 렌더링 (AST → HTML)
- 프리뷰 on/off 토글 (에디터 헤더 + 설정 > General)
- 찾기/바꾸기, 아웃라인 사이드바, 포커스/타자기 모드
- 자동 저장 (3초 디바운스), 외부 파일 변경 감지
- PDF/HTML 내보내기, 이미지 드래그 앤 드롭/붙여넣기
- 네이티브 윈도우 탭, Cmd+1~9 탭 전환, 서식 단축키 (Cmd+B/I/K/E)
- Quick Look Extension (Premium): Finder에서 마크다운 풀 미리보기
- StoreKit 2 인앱 구입 (비소모품)

### 상세 문서

- [아키텍처](docs/architecture.md) — 프로젝트 구조, 핵심 아키텍처, 스크롤 동기화
- [앱스토어 체크리스트](docs/appstore-checklist.md) — 제출 체크리스트, Validation 오류 해결
- [변경 이력](docs/changelog.md) — 버전별 변경 이력
- [Quick Look + IAP 검토](docs/quicklook-iap-review.md) — Quick Look + IAP 기능 검토
- [Context DB](docs/claude/context-db.md) — SQLite 기반 세션/태스크/결정 저장소
- [Context Monitor](docs/claude/context-monitor.md) — HUD + compaction 감지/복구
- [컨벤션](docs/claude/conventions.md) — 커밋, 주석, 로깅 규칙
- [셋업](docs/claude/setup.md) — 새 환경 초기 설정

---

*최종 업데이트: 2026-03-28*

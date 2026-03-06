# CLAUDE.md - MarkdownEditor

## 프로젝트 개요

macOS용 마크다운 에디터 앱 (AppKit 생명주기 + SwiftUI 뷰)
- 현재 버전: v1.4.0, Build 18
- 파서: apple/swift-markdown (SPM) AST 기반
- 아키텍처: 순수 AppKit 생명주기 + SwiftUI 뷰, TabService 싱글톤, 네이티브 윈도우 탭

## 빌드 및 실행

```bash
# Xcode에서 열기
open MarkdownEditor.xcodeproj

# 빌드 (CLI)
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor -configuration Release build
```

## 주요 기능

- swift-markdown 기반 마크다운 렌더링 (AST → HTML)
- 찾기/바꾸기, 아웃라인 사이드바, 포커스/타자기 모드
- 자동 저장 (3초 디바운스), 외부 파일 변경 감지
- PDF/HTML 내보내기, 이미지 드래그 앤 드롭/붙여넣기
- 네이티브 윈도우 탭, Cmd+1~9 탭 전환, 서식 단축키 (Cmd+B/I/K/E)
- Quick Look Extension (Premium): Finder에서 마크다운 풀 미리보기
- StoreKit 2 인앱 구입 (비소모품)

## 문서

| 문서 | 설명 |
|------|------|
| [docs/architecture.md](docs/architecture.md) | 프로젝트 구조, 핵심 아키텍처, 스크롤 동기화 메커니즘 |
| [docs/appstore-checklist.md](docs/appstore-checklist.md) | 앱스토어 제출 체크리스트, Validation 오류 해결, 유용한 명령어 |
| [docs/changelog.md](docs/changelog.md) | 버전별 변경 이력 |
| [docs/quicklook-iap-review.md](docs/quicklook-iap-review.md) | Quick Look + IAP 기능 검토 |

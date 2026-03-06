# 아키텍처

## 프로젝트 구조

```
MarkdownEditor/
├── App/
│   └── MarkdownEditorApp.swift     # AppDelegate, DocumentManager, 메뉴 구성
├── Assets.xcassets/                # 앱 아이콘, AccentColor
├── Models/
│   ├── AppState.swift              # 앱 전역 상태 (테마, 에디터 설정, 아웃라인 설정)
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
│   └── MarkdownProcessor.swift     # swift-markdown AST → HTML 변환
├── WindowManagement/
│   ├── TabService.swift            # 윈도우/문서 관리 싱글톤
│   └── DocumentWindowController.swift # 윈도우 컨트롤러
├── Resources/
│   ├── preview-light.css           # 라이트 테마 프리뷰 스타일
│   └── preview-dark.css            # 다크 테마 프리뷰 스타일
├── Info.plist
└── MarkdownEditor.entitlements
```

## 핵심 아키텍처

- **생명주기**: 순수 AppKit (NSApplication + AppDelegate) + SwiftUI 뷰
- **파서**: apple/swift-markdown (SPM) AST 기반
- **윈도우 관리**: TabService 싱글톤 + 네이티브 윈도우 탭
- **상태 관리**: AppState (ObservableObject) - 테마, 폰트, 에디터 설정

## 스크롤 동기화 & 아웃라인 하이라이트

- `ScrollSyncManager`: 에디터 ↔ 프리뷰 간 퍼센트 기반 스크롤 동기화
- `currentLine` (0-based): 아웃라인 하이라이트의 기준값
- **업데이트 경로 2가지:**
  1. `textViewDidChangeSelection` → 커서 이동 시 (정확)
  2. `scrollViewDidScroll` → 에디터 스크롤 시 화면 상단 기준 (근사)
- **경합 방지 가드:**
  - `lastSelectionTime` (0.3초): 커서 이동 직후 스크롤 기반 덮어쓰기 방지
  - `lastOutlineClickTime` (1.0초): 아웃라인 클릭 → 프리뷰 smooth scroll 동기화 덮어쓰기 방지

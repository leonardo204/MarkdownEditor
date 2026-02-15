# CLAUDE.md - MarkdownEditor

## 프로젝트 개요

macOS용 마크다운 에디터 앱 (AppKit 생명주기 + SwiftUI 뷰)
- 현재 버전: v1.3.0, Build 15
- 파서: apple/swift-markdown (SPM) AST 기반
- 아키텍처: 순수 AppKit 생명주기 + SwiftUI 뷰, TabService 싱글톤, 네이티브 윈도우 탭

## 빌드 및 실행

```bash
# Xcode에서 열기
open MarkdownEditor.xcodeproj

# 빌드 (CLI)
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor -configuration Release build
```

## 앱스토어 제출 체크리스트

버전 업데이트 및 앱스토어 제출 전 반드시 확인할 항목들:

### 1. 버전 번호 업데이트

- [ ] `CURRENT_PROJECT_VERSION` 증가 (Build Number)
  - 위치: `project.pbxproj` 또는 Xcode > Target > Build Settings > Current Project Version
  - 매 제출마다 이전보다 높은 숫자로 설정

- [ ] `MARKETING_VERSION` 확인 (Version)
  - 위치: `project.pbxproj` 또는 Xcode > Target > General > Version
  - 사용자에게 표시되는 버전 (예: 1.0.1, 1.1.0)

### 2. Info.plist 필수 항목

- [ ] `LSApplicationCategoryType` 설정됨
  - 현재 값: `public.app-category.productivity`
  - 앱스토어 카테고리 지정 필수

- [ ] `ITSAppUsesNonExemptEncryption` 설정됨
  - 현재 값: `false`
  - 수출 규정 준수 질문 생략 (표준 HTTPS만 사용 시)

### 3. 코드 서명 및 권한

- [ ] `CODE_SIGN_ENTITLEMENTS` 연결됨
  - 파일: `MarkdownEditor/MarkdownEditor.entitlements`
  - Debug/Release 모두 설정 필요

- [ ] App Sandbox 활성화됨
  - `com.apple.security.app-sandbox` = true

- [ ] 필요한 권한만 포함
  - 현재: 파일 접근, 북마크, 네트워크 클라이언트

### 4. Asset Catalog 확인

- [ ] `Assets.xcassets` 위치 확인
  - 올바른 위치: `MarkdownEditor/Assets.xcassets` (루트)
  - Resources 폴더 안에 있으면 안 됨

- [ ] `AppIcon.appiconset` 모든 사이즈 포함 및 정확한 크기
  - 16x16, 16x16@2x (32px)
  - 32x32, 32x32@2x (64px)
  - 128x128, 128x128@2x (256px)
  - 256x256, 256x256@2x (512px)
  - 512x512, 512x512@2x (1024px)

- [ ] `AccentColor.colorset` 색상 정의됨 (비어있으면 안 됨)

- [ ] 빌드 설정에 `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_EXTENSIONS = YES`

### 5. Archive 및 Validate

```
1. Product → Clean Build Folder (Cmd+Shift+K)
2. Product → Archive
3. Organizer → Validate App
4. 오류 없으면 → Distribute App
```

### 6. 흔한 Validation 오류

| 오류 | 원인 | 해결 |
|------|------|------|
| CFBundleVersion must be higher | 빌드 번호 미증가 | CURRENT_PROJECT_VERSION 올리기 |
| LSApplicationCategoryType missing | 카테고리 미설정 | Info.plist에 추가 |
| App sandbox not enabled | entitlements 미연결 | CODE_SIGN_ENTITLEMENTS 설정 |
| Missing asset catalog (ITMS-90546) | Assets.xcassets 누락/위치 오류 | 프로젝트 루트에 Assets.xcassets 배치 |
| AppIcon size warning | 아이콘 크기 불일치 | sips로 정확한 크기로 리사이즈 |

## 프로젝트 구조

```
MarkdownEditor/
├── App/
│   └── MarkdownEditorApp.swift     # AppDelegate, DocumentManager, 메뉴 구성
├── Assets.xcassets/                # 앱 아이콘, AccentColor
├── Models/
│   └── TabManager.swift            # 탭 관리
├── Views/
│   ├── ContentView.swift           # EditorPreviewSplitView, OutlineView, StatusBar
│   ├── DocumentContentView.swift   # 루트 SwiftUI 뷰 (에디터+프리뷰 통합)
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
├── Resources/                      # CSS 등 리소스
├── Info.plist
└── MarkdownEditor.entitlements
```

## 주요 기능 (v1.3.0)

- swift-markdown 기반 정확한 마크다운 렌더링
- 찾기/바꾸기 (별도 NSPanel, 매치 하이라이트, 순환 검색)
- 자동 저장 (3초 디바운스)
- 아웃라인 사이드바 (현재 위치 하이라이트, 스크롤 연동)
- 포커스 모드 / 타자기 모드
- PDF/HTML 내보내기
- 이미지 드래그 앤 드롭 / 붙여넣기
- 외부 파일 변경 감지 & 자동 반영
- Cmd+1~9 탭 전환, 서식 단축키 (Cmd+B/I/K/E)
- 최근 파일 목록

## 유용한 명령어

```bash
# 아이콘 크기 확인
sips -g pixelWidth -g pixelHeight icon.png

# 아이콘 리사이즈
sips -z 128 128 icon_128x128.png

# git에서 무시되는 파일 확인
git check-ignore -v filename
```

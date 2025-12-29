# CLAUDE.md - MarkdownEditor

## 프로젝트 개요

macOS용 마크다운 에디터 앱 (SwiftUI)

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

### 3. 코드 서명 및 권한

- [ ] `CODE_SIGN_ENTITLEMENTS` 연결됨
  - 파일: `MarkdownEditor/MarkdownEditor.entitlements`
  - Debug/Release 모두 설정 필요

- [ ] App Sandbox 활성화됨
  - `com.apple.security.app-sandbox` = true

- [ ] 필요한 권한만 포함
  - 현재: 파일 접근, 북마크, 네트워크 클라이언트

### 4. Archive 및 Validate

```
1. Product → Clean Build Folder (Cmd+Shift+K)
2. Product → Archive
3. Organizer → Validate App
4. 오류 없으면 → Distribute App
```

### 5. 흔한 Validation 오류

| 오류 | 원인 | 해결 |
|------|------|------|
| CFBundleVersion must be higher | 빌드 번호 미증가 | CURRENT_PROJECT_VERSION 올리기 |
| LSApplicationCategoryType missing | 카테고리 미설정 | Info.plist에 추가 |
| App sandbox not enabled | entitlements 미연결 | CODE_SIGN_ENTITLEMENTS 설정 |

## 프로젝트 구조

```
MarkdownEditor/
├── App/                 # 앱 진입점
├── Models/              # 데이터 모델
├── Views/               # SwiftUI 뷰
├── Services/            # 마크다운 처리 등
├── Resources/           # 에셋, CSS
├── Info.plist
└── MarkdownEditor.entitlements
```

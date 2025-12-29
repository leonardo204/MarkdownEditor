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
├── App/                 # 앱 진입점
├── Assets.xcassets/     # 앱 아이콘, AccentColor
├── Models/              # 데이터 모델
├── Views/               # SwiftUI 뷰
├── Services/            # 마크다운 처리 등
├── Resources/           # CSS 등 리소스
├── Info.plist
└── MarkdownEditor.entitlements
```

## 유용한 명령어

```bash
# 아이콘 크기 확인
sips -g pixelWidth -g pixelHeight icon.png

# 아이콘 리사이즈
sips -z 128 128 icon_128x128.png

# git에서 무시되는 파일 확인
git check-ignore -v filename
```

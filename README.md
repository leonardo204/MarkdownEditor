# MarkdownEditor

macOS용 마크다운 에디터입니다. 실시간 미리보기와 스크롤 동기화 기능을 제공합니다.

## 주요 기능

- **실시간 미리보기**: 에디터와 프리뷰가 나란히 표시되며, 편집 내용이 즉시 반영됩니다
- **다이어그램 지원**: Mermaid와 PlantUML 다이어그램을 실시간으로 렌더링
- **스크롤 동기화**: 에디터와 프리뷰의 스크롤이 자동으로 동기화됩니다
- **테마 지원**: 에디터와 프리뷰 각각 라이트/다크 테마 선택 가능
- **마크다운 툴바**: 볼드, 이탤릭, 헤더, 링크, 이미지, 코드 블록 등 빠른 입력 지원
- **다중 파일 지원**: 여러 파일을 드래그 앤 드롭으로 한번에 열기
- **중복 파일 감지**: 이미 열린 파일을 다시 열려고 하면 해당 창으로 이동

## 스크린샷

![MarkdownEditor 메인 화면](docs/images/screenshot-main.png)

*Mermaid 플로우차트, PlantUML 시퀀스 다이어그램, 테이블, 체크리스트 등 다양한 마크다운 요소 지원*

## 시스템 요구사항

- macOS 13.0 (Ventura) 이상
- Apple Silicon (M1/M2/M3) 또는 Intel Mac

## 설치

### DMG 다운로드

[Releases](https://github.com/leonardo204/MarkdownEditor/releases) 페이지에서 최신 DMG 파일을 다운로드하세요.

### 설치 방법

1. DMG 파일을 열고 `MarkdownEditor.app`을 `Applications` 폴더로 드래그
2. 처음 실행 시 Gatekeeper 확인 후 "열기" 클릭

## 기본 앱으로 설정

### Finder에서 설정

1. 아무 `.md` 파일을 우클릭
2. "정보 가져오기" 선택
3. "다음으로 열기"에서 MarkdownEditor 선택
4. "모두 변경..." 버튼 클릭

### 터미널에서 설정

```bash
brew install duti
duti -s com.zerolive.MarkdownEditor .md all
duti -s com.zerolive.MarkdownEditor .markdown all
```

## 빌드

### 요구사항

- Xcode 15.0 이상
- macOS 14.0 이상 (빌드 환경)

### 빌드 방법

```bash
# 프로젝트 클론
git clone git@github.com:leonardo204/MarkdownEditor.git
cd MarkdownEditor

# Xcode로 빌드
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor -configuration Release build
```

### DMG 생성 (공증 포함)

```bash
# 사전 요구사항: create-dmg 설치
brew install create-dmg

# Keychain에 notarytool 프로필 저장 (최초 1회)
xcrun notarytool store-credentials "notarytool" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

# 빌드 및 DMG 생성
./scripts/distribute.sh
```

## 라이선스

All rights reserved.

## 문의

zerolive7@gmail.com

# MarkdownEditor

<p align="center">
  <a href="https://apps.apple.com/app/id6756916654"><img src="https://img.shields.io/badge/Mac%20App%20Store-Download-0D96F6?logo=apple&logoColor=white" alt="Mac App Store"></a>
  <img src="https://img.shields.io/badge/macOS-13.0%2B-lightgrey" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

**한국어** | [English](README.en.md) | [日本語](README.ja.md) | [中文](README.zh.md)

macOS용 마크다운 에디터입니다. 실시간 미리보기와 스크롤 동기화를 제공합니다.

> Mac App Store에는 **MarkChartEditor**라는 이름으로 등록되어 있습니다.
> [App Store에서 받기](https://apps.apple.com/app/id6756916654)

## 주요 기능

- **실시간 미리보기**: 에디터와 프리뷰가 나란히 표시되며, 편집 내용이 즉시 반영됩니다
- **스크롤 동기화**: 소스 라인을 기준으로 에디터와 프리뷰가 서로 따라갑니다. 휠, 트랙패드는 물론 스크롤 막대를 잡고 끄는 경우도 동기화됩니다
- **다이어그램과 수식**: Mermaid, PlantUML 다이어그램과 KaTeX 수식, 코드 하이라이팅을 지원합니다
- **네이티브 macOS 탭**: Safari, Finder와 같은 탭 사용감을 제공합니다
  - Cmd+T로 새 탭, Cmd+N으로 새 윈도우
  - 탭을 드래그해 새 윈도우로 분리
  - Window > Merge All Windows로 탭 합치기
- **찾기와 바꾸기**: 에디터와 프리뷰 양쪽에서 검색하고 결과를 하이라이트합니다
- **아웃라인 사이드바**: 헤딩 목록에서 원하는 위치로 바로 이동합니다 (Shift+Cmd+O)
- **집중 모드와 타자기 모드**: 현재 문단만 강조하거나 커서를 화면 중앙에 고정합니다
- **자동 저장과 외부 변경 감지**: 3초 후 자동 저장하고, 다른 프로그램이 파일을 고치면 알려줍니다
- **내보내기**: PDF와 HTML로 저장합니다
- **이미지 삽입**: 드래그 앤 드롭, 붙여넣기, 파일 선택(Ctrl+O)을 지원합니다
- **테마**: 에디터와 프리뷰 각각 라이트/다크를 고를 수 있습니다
- **창 크기 기억**: 마지막에 조절한 창 크기로 다음에 열립니다 (설정 > General에서 켜기)
- **4개 언어 지원**: 한국어, English, 日本語, 简体中文 — 설정 > General에서 고릅니다 (기본은 시스템 언어를 따름)
- **Quick Look 미리보기**(인앱 구입): Finder에서 스페이스바로 마크다운을 그대로 확인합니다

## 스크린샷

![MarkdownEditor 메인 화면](docs/images/screenshot-main.png)

*Mermaid 플로우차트, PlantUML 시퀀스 다이어그램, 테이블, 체크리스트 등 다양한 마크다운 요소 지원*

## 시스템 요구사항

- macOS 13.0 (Ventura) 이상
- Apple Silicon (M1/M2/M3) 또는 Intel Mac

## 설치

### Mac App Store (권장)

[Mac App Store에서 받기](https://apps.apple.com/app/id6756916654)

### 소스에서 빌드

아래 [빌드](#빌드) 항목을 참고하세요.

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
git clone git@github.com:leonardo204/MarkdownEditor.git
cd MarkdownEditor

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

MIT License. 자세한 내용은 [LICENSE](LICENSE) 파일을 확인하세요.

## 문의

zerolive7@gmail.com

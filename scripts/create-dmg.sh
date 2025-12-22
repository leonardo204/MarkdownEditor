#!/bin/bash

# DMG 생성 및 공증 스크립트
# create-dmg를 사용하여 DMG를 생성하고 Apple에 공증을 요청합니다.
#
# 사전 요구사항:
# 1. create-dmg 설치: brew install create-dmg
# 2. Keychain에 notarytool 프로필 저장:
#    xcrun notarytool store-credentials "notarytool" \
#      --apple-id "your-apple-id@example.com" \
#      --team-id "XU8HS9JUTS" \
#      --password "app-specific-password"

set -e

# 프로젝트 루트 디렉토리
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# 설정
APP_NAME="MarkdownEditor"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
BUILD_TIME=$(date +"%Y%m%d_%H%M%S")
DMG_NAME="${APP_NAME}-${VERSION}-${BUILD_TIME}"
FINAL_DMG_PATH="$DIST_DIR/${DMG_NAME}.dmg"
KEYCHAIN_PROFILE="notarytool"

# dist 폴더 생성
mkdir -p "$DIST_DIR"

# 앱 존재 확인
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at $APP_PATH"
    echo "   Run build-release.sh first"
    exit 1
fi

# create-dmg 설치 확인
if ! command -v create-dmg &> /dev/null; then
    echo "❌ create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

echo "📀 Creating DMG for $APP_NAME v$VERSION..."

# 이전 DMG 삭제
rm -f "$DMG_PATH" "$FINAL_DMG_PATH"

# DMG 생성
create-dmg \
    --volname "$APP_NAME" \
    --volicon "$PROJECT_DIR/MarkdownEditor/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 185 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 450 185 \
    --background "$PROJECT_DIR/resources/dmg-background.png" \
    "$DMG_PATH" \
    "$APP_PATH" \
    2>/dev/null || {
        # 배경 이미지가 없는 경우 기본 설정으로 재시도
        create-dmg \
            --volname "$APP_NAME" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "$APP_NAME.app" 150 185 \
            --hide-extension "$APP_NAME.app" \
            --app-drop-link 450 185 \
            "$DMG_PATH" \
            "$APP_PATH"
    }

echo "✅ DMG created at $DMG_PATH"

# DMG 서명
echo "🔏 Signing DMG..."
codesign --sign "Developer ID Application: YONGSUB LEE (XU8HS9JUTS)" \
    --options runtime \
    --timestamp \
    "$DMG_PATH"

echo "✅ DMG signed"

# 공증
echo "📤 Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "✅ Notarization completed"

# Staple
echo "📎 Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "✅ Ticket stapled"

# 최종 DMG 이름 변경
mv "$DMG_PATH" "$FINAL_DMG_PATH"

echo ""
echo "🎉 DMG creation and notarization complete!"
echo "   Output: $FINAL_DMG_PATH"
echo ""

# 검증
echo "🔍 Verifying..."
spctl -a -t open --context context:primary-signature -v "$FINAL_DMG_PATH"
echo ""
echo "✅ All done!"

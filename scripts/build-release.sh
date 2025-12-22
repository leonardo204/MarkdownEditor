#!/bin/bash

# Release 빌드 스크립트
# 앱을 Release 모드로 빌드합니다.

set -e

# 프로젝트 루트 디렉토리
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# 빌드 설정
SCHEME="MarkdownEditor"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"

echo "📦 Building $SCHEME in $CONFIGURATION mode..."

# 이전 빌드 정리
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Archive 빌드
xcodebuild archive \
    -project MarkdownEditor.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="XU8HS9JUTS" \
    CODE_SIGN_STYLE="Manual"

echo "✅ Archive created at $ARCHIVE_PATH"

# Export Options plist 생성
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>XU8HS9JUTS</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
EOF

# Export
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$EXPORT_PATH"

echo "✅ App exported to $EXPORT_PATH"

# 결과 확인
if [ -d "$EXPORT_PATH/$SCHEME.app" ]; then
    echo "🎉 Build successful!"
    echo "   App location: $EXPORT_PATH/$SCHEME.app"
else
    echo "❌ Build failed - app not found"
    exit 1
fi

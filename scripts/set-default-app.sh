#!/bin/bash

# Markdown Editor를 .md 파일의 기본 앱으로 설정하는 스크립트
# 사전 요구사항: duti 설치 (brew install duti)

BUNDLE_ID="com.zerolive.MarkdownEditor"
APP_PATH="/Applications/MarkdownEditor.app"

echo "🔧 Markdown Editor를 기본 앱으로 설정합니다..."

# 앱 설치 확인
if [ ! -d "$APP_PATH" ]; then
    echo "❌ MarkdownEditor.app이 /Applications에 설치되어 있지 않습니다."
    echo "   먼저 앱을 Applications 폴더로 이동해주세요."
    exit 1
fi

# duti 설치 확인
if ! command -v duti &> /dev/null; then
    echo "⚠️  duti가 설치되어 있지 않습니다."
    echo ""
    echo "📋 수동 설정 방법:"
    echo "   1. Finder에서 아무 .md 파일을 우클릭"
    echo "   2. '정보 가져오기' 선택"
    echo "   3. '다음으로 열기' 섹션에서 MarkdownEditor 선택"
    echo "   4. '모두 변경...' 버튼 클릭"
    echo ""
    echo "또는 duti를 설치하세요: brew install duti"
    exit 0
fi

# Launch Services 데이터베이스 등록
echo "📝 Launch Services에 앱 등록 중..."
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "$APP_PATH"

# .md, .markdown 파일 연결
echo "🔗 파일 확장자 연결 중..."
duti -s "$BUNDLE_ID" .md all
duti -s "$BUNDLE_ID" .markdown all

# UTI 연결
duti -s "$BUNDLE_ID" net.daringfireball.markdown all 2>/dev/null || true
duti -s "$BUNDLE_ID" public.plain-text editor 2>/dev/null || true

echo ""
echo "✅ 설정 완료!"
echo "   이제 .md 및 .markdown 파일을 더블클릭하면"
echo "   Markdown Editor로 열립니다."
echo ""

# 확인
echo "🔍 현재 설정 확인:"
echo "   .md 파일: $(duti -x md 2>/dev/null | head -1 || echo '확인 불가')"
echo "   .markdown 파일: $(duti -x markdown 2>/dev/null | head -1 || echo '확인 불가')"

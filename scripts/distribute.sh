#!/bin/bash

# 배포 스크립트
# Release 빌드, 서명, 공증, DMG 생성을 한 번에 수행합니다.

set -e

# 프로젝트 루트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Starting distribution build..."
echo ""

# 1. Release 빌드
echo "Step 1/2: Building release..."
"$SCRIPT_DIR/build-release.sh"
echo ""

# 2. DMG 생성 및 공증
echo "Step 2/2: Creating DMG and notarizing..."
"$SCRIPT_DIR/create-dmg.sh"
echo ""

echo "🎉 Distribution complete!"

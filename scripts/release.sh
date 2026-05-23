#!/usr/bin/env bash
# Albi 로컬 빌드 + GitHub Release 자동 생성/업로드.
#
# 목적: QA 가 GitHub Release 페이지에서 최신 APK / iOS app 을 직접 다운로드.
# CI artifact 가 free tier storage quota 영향을 받아 제거됨 — 본 스크립트가 대체.
#
# Usage:
#   bash scripts/release.sh <tag>                # debug build (default, QA 용)
#   bash scripts/release.sh <tag> --release      # release build (서명 keystore 필요)
#
# 예시:
#   bash scripts/release.sh v0.1.0
#   bash scripts/release.sh v0.1.1 --release
#
# 전제:
# - gh CLI 인증 완료 (gh auth status)
# - flutter PATH 확보 (env 또는 /d/flutter/bin)
# - 현재 main branch + 최신 push 상태 (필수 아님, target 으로 사용됨)
# - iOS 빌드는 macOS 에서만 자동 실행 (Windows/Linux 는 skip)

set -euo pipefail

TAG="${1:-}"
BUILD_MODE_FLAG="${2:---debug}"

if [ -z "$TAG" ]; then
  echo "사용법: bash scripts/release.sh <tag> [--debug|--release]"
  echo "예: bash scripts/release.sh v0.1.0"
  exit 1
fi

# Flutter PATH 보장 — env 또는 /d/flutter/bin
if ! command -v flutter >/dev/null 2>&1; then
  if [ -x "/d/flutter/bin/flutter" ]; then
    export PATH="/d/flutter/bin:$PATH"
  else
    echo "ERROR: flutter 명령을 찾을 수 없음. /d/flutter/bin/flutter 확인" >&2
    exit 1
  fi
fi

# gh CLI 인증 확인
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh CLI 인증 필요. 'gh auth login' 실행" >&2
  exit 1
fi

log() { echo "[$(date +%H:%M:%S)] $*"; }
sep() { echo "================================================================"; }

MODE="${BUILD_MODE_FLAG/--/}"  # --debug → debug, --release → release

sep
log "▶ tag: $TAG / mode: $MODE"

# --- 1. APK 빌드 ---
sep
log "▶ APK 빌드 ($MODE)"
flutter build apk "$BUILD_MODE_FLAG"
APK_PATH="build/app/outputs/flutter-apk/app-${MODE}.apk"
if [ ! -f "$APK_PATH" ]; then
  log "❌ APK 빌드 실패: $APK_PATH 없음"
  exit 1
fi
APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
log "  APK: $APK_PATH ($APK_SIZE)"

# --- 2. (옵션) iOS 빌드 — macOS 에서만 ---
IOS_ZIP=""
if [[ "$(uname)" == "Darwin" ]]; then
  sep
  log "▶ iOS 빌드 (no codesign, $MODE)"
  flutter build ios --no-codesign "$BUILD_MODE_FLAG"
  IOS_APP_DIR="build/ios/iphoneos/Runner.app"
  if [ -d "$IOS_APP_DIR" ]; then
    IOS_ZIP="build/ios/iphoneos/Runner.app.zip"
    (cd build/ios/iphoneos && zip -r Runner.app.zip Runner.app >/dev/null)
    log "  iOS: $IOS_ZIP"
  else
    log "  ⚠ iOS 빌드 결과 없음 — skip"
  fi
else
  log "  (현재 OS macOS 아님 — iOS 빌드 skip. macOS 에서 별도 실행 권장)"
fi

# --- 3. GitHub Release 생성/갱신 ---
sep
log "▶ GitHub Release 생성/갱신: $TAG"

COMMIT_SHORT=$(git rev-parse --short HEAD)
BUILD_DATE=$(date '+%Y-%m-%d %H:%M')
FLUTTER_VER=$(flutter --version | head -1)

NOTES="자동 빌드 — ${MODE} mode

## 빌드 정보
- 빌드 일시: ${BUILD_DATE}
- 빌드 머신: $(uname -s) $(uname -m)
- Flutter: ${FLUTTER_VER}
- Commit: ${COMMIT_SHORT}

## QA 설치 방법 (Android)
1. \`app-${MODE}.apk\` 다운로드
2. Android device 의 설정 → '알 수 없는 출처 설치' 허용
3. APK 파일 실행 → 설치
4. (debug 빌드는 USB 디버깅 / dev 환경 권장)"

# tag 가 이미 있으면 asset 만 갱신
if gh release view "$TAG" >/dev/null 2>&1; then
  log "  ⚠ Release $TAG 이미 존재 — asset 만 갱신 (--clobber)"
  gh release upload "$TAG" "$APK_PATH" --clobber
  [ -n "$IOS_ZIP" ] && gh release upload "$TAG" "$IOS_ZIP" --clobber
else
  ASSETS=("$APK_PATH")
  [ -n "$IOS_ZIP" ] && ASSETS+=("$IOS_ZIP")
  gh release create "$TAG" \
    --title "$TAG" \
    --notes "$NOTES" \
    --target "$(git rev-parse --abbrev-ref HEAD)" \
    "${ASSETS[@]}"
fi

sep
log "✅ Release $TAG 완료"
RELEASE_URL=$(gh release view "$TAG" --json url --jq '.url')
log "  URL: $RELEASE_URL"
log "  QA 공유: 위 URL 의 Assets 섹션에서 APK 다운로드 가능"

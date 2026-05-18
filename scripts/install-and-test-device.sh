#!/usr/bin/env bash
# Albi APK 빌드 + 연결된 Android device 에 install + integration test 실행
#
# Usage:
#   bash scripts/install-and-test-device.sh
#
# 전제:
#   - Android device USB 연결 + USB 디버깅 활성화
#   - `flutter devices` 에 android-arm64 표시
#   - flutter doctor 통과 (Android licenses 수락 완료)

set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  if [ -x "/d/flutter/bin/flutter" ]; then
    export PATH="/d/flutter/bin:$PATH"
  else
    echo "ERROR: flutter not found" >&2
    exit 1
  fi
fi

log() { echo "[$(date +%H:%M:%S)] $*"; }
sep() { echo "================================================================"; }

# 1. Android device 식별
sep
log "▶ Android device 검색"
# raw `flutter devices` 출력: "SM F711N (mobile) • R3CR905KVKV • android-arm64  • Android 15"
DEVICE_ID=$(flutter devices 2>/dev/null \
  | awk -F' • ' '/android-arm64/ && !/emulator/ { gsub(/^ +| +$/, "", $2); print $2; exit }' \
  || echo "")

if [ -z "$DEVICE_ID" ]; then
  log "❌ Android device 미연결. flutter devices 확인."
  exit 1
fi
log "  Device: $DEVICE_ID"

# 2. APK debug build
sep
log "▶ APK debug 빌드"
flutter build apk --debug --target-platform android-arm64

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
if [ ! -f "$APK_PATH" ]; then
  log "❌ APK 빌드 실패: $APK_PATH 없음"
  exit 1
fi
log "  APK: $APK_PATH ($(du -h "$APK_PATH" | cut -f1))"

# 3. Install
sep
log "▶ device 에 install"
flutter install -d "$DEVICE_ID" --debug

# 4. Integration test on device
sep
log "▶ integration_test 실행 on device"
if ! flutter test integration_test/ -d "$DEVICE_ID" 2>&1 | tee /tmp/albi-integration-test.log; then
  log "❌ integration test 실패"
  log "  로그: /tmp/albi-integration-test.log"
  log "  screenshot: test_screenshots/"
  exit 1
fi

sep
log "✅ 모두 통과"
log "  Screenshots: test_screenshots/ 디렉토리 확인"
ls -la test_screenshots/ 2>/dev/null | head -10 || log "  (screenshot 없음)"

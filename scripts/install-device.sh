#!/usr/bin/env bash
# Albi — 연결된 Android device 에 직접 설치 (사용자 테스트용).
# 통합테스트는 돌리지 않는다. 빌드 + 설치만 하고 끝낸다.
#
# Usage:
#   bash scripts/install-device.sh            # release 빌드 설치 (기본, 권장)
#   bash scripts/install-device.sh debug      # debug 빌드 설치 (빌드 빠름, 디버그 배너)
#
# 전제:
#   - Android device USB 연결 + USB 디버깅 허용
#   - `flutter devices` 에 android-arm64 표시
#   - key.properties 없으면 release 는 debug 키로 서명 (사이드로드 OK)

set -euo pipefail

MODE="${1:-release}"   # release | debug

if ! command -v flutter >/dev/null 2>&1; then
  if [ -x "/d/flutter/bin/flutter" ]; then
    export PATH="/d/flutter/bin:$PATH"
  else
    echo "ERROR: flutter not found (PATH 또는 /d/flutter/bin 확인)" >&2
    exit 1
  fi
fi

log() { echo "[$(date +%H:%M:%S)] $*"; }
sep() { echo "================================================================"; }

# 1. Android device 식별 (첫 번째 실물 android-arm64)
sep
log "▶ Android device 검색"
DEVICE_ID=$(flutter devices 2>/dev/null \
  | awk -F' • ' '/android-arm64/ && !/emulator/ { gsub(/^ +| +$/, "", $2); print $2; exit }' \
  || echo "")

if [ -z "$DEVICE_ID" ]; then
  log "❌ Android device 미연결. 'flutter devices' 로 확인하세요."
  exit 1
fi
log "  Device: $DEVICE_ID"

# 2. 빌드 + 설치
sep
if [ "$MODE" = "debug" ]; then
  log "▶ debug 빌드 + 설치"
  flutter install -d "$DEVICE_ID" --debug
else
  log "▶ release 빌드 + 설치 (key.properties 없으면 debug 키 fallback)"
  flutter install -d "$DEVICE_ID" --release
fi

sep
log "✅ 설치 완료 — 기기에서 '알비' 앱 실행"
log ""
log "  사용자 테스트 메모:"
log "  • AI 자동 분석은 Gemini API 키 등록 후 사용 가능"
log "  • 키 없이 'AI로 생성' → 연결 가이드 바텀시트 표시"
log "  • 키 등록: 홈 우상단 🔔 → AI 연결 설정, 또는 더보기 → 설정"
log "  • 키 없이 기록하려면 '직접 입력' 사용"

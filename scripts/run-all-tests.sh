#!/usr/bin/env bash
# Albi 전체 테스트 자동 실행 (LLM 자율 실행용)
#
# Usage:
#   bash scripts/run-all-tests.sh [target]
#
# target:
#   unit       — flutter analyze + unit/widget test (~10s)
#   golden     — golden test (현재 디바이스 frame 기준)
#   integration:windows  — Windows desktop 에서 integration_test 실행
#   integration:android  — 연결된 Android device 에서 integration_test 실행
#   smoke      — 빠른 smoke (analyze + unit, golden 제외)
#   all        — 모두 실행 (default)
#
# Exit code 0 = 모두 pass, !=0 = 실패

set -euo pipefail

# Flutter PATH 보장 — env 또는 D:\flutter\bin
if ! command -v flutter >/dev/null 2>&1; then
  if [ -x "/d/flutter/bin/flutter" ]; then
    export PATH="/d/flutter/bin:$PATH"
  else
    echo "ERROR: flutter 명령을 찾을 수 없음. /d/flutter/bin/flutter 확인" >&2
    exit 1
  fi
fi

TARGET="${1:-all}"
RESULTS=()
EXIT_CODE=0

log() { echo "[$(date +%H:%M:%S)] $*"; }
sep() { echo "================================================================"; }

run_step() {
  local label="$1"; shift
  sep
  log "▶ $label"
  if "$@"; then
    RESULTS+=("✅ $label")
  else
    RESULTS+=("❌ $label")
    EXIT_CODE=1
  fi
}

# --- Steps ---

step_analyze() { flutter analyze; }

step_unit() {
  flutter test --exclude-tags golden
}

step_golden() {
  # Golden 은 디바이스 frame 의존 — UPDATE_GOLDENS=true 로 재생성 권장
  if [ "${UPDATE_GOLDENS:-false}" = "true" ]; then
    log "  (UPDATE_GOLDENS=true — golden 재생성 모드)"
    flutter test --tags golden --update-goldens
  else
    flutter test --tags golden
  fi
}

step_integration_windows() {
  flutter test integration_test/ -d windows
}

step_integration_android() {
  local device
  device=$(flutter devices 2>/dev/null \
    | awk -F' • ' '/android-arm64/ && !/emulator/ { gsub(/^ +| +$/, "", $2); print $2; exit }' \
    || echo "")

  if [ -z "$device" ]; then
    log "  ⚠ Android device 미연결 — skip"
    return 0
  fi
  log "  Android device: $device"
  flutter test integration_test/ -d "$device"
}

# --- Main ---

case "$TARGET" in
  unit)
    run_step "flutter analyze" step_analyze
    run_step "unit/widget tests" step_unit
    ;;
  golden)
    run_step "golden tests" step_golden
    ;;
  integration:windows)
    run_step "integration_test (Windows desktop)" step_integration_windows
    ;;
  integration:android)
    run_step "integration_test (Android device)" step_integration_android
    ;;
  smoke)
    run_step "flutter analyze" step_analyze
    run_step "unit/widget tests" step_unit
    ;;
  all)
    run_step "flutter analyze" step_analyze
    run_step "unit/widget tests" step_unit
    run_step "golden tests" step_golden
    # integration 은 device 환경에 따라 다름 — Android 우선, fallback Windows
    if flutter devices 2>/dev/null | grep -q "android-arm64"; then
      run_step "integration_test (Android)" step_integration_android
    else
      run_step "integration_test (Windows)" step_integration_windows
    fi
    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    echo "Usage: $0 [unit|golden|integration:windows|integration:android|smoke|all]" >&2
    exit 2
    ;;
esac

# --- Summary ---
sep
log "Results:"
for r in "${RESULTS[@]}"; do
  echo "  $r"
done
sep
if [ $EXIT_CODE -eq 0 ]; then
  log "✅ 모든 step pass"
else
  log "❌ 일부 step fail (exit $EXIT_CODE)"
fi
exit $EXIT_CODE

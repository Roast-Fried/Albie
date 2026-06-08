#!/usr/bin/env bash
# Albi — iOS 실행/테스트 (macOS 전용 — iOS 빌드는 Mac + Xcode 필수)
#
# Usage:
#   bash scripts/run-ios.sh                # 연결 기기/부팅된 simulator 에 run
#   bash scripts/run-ios.sh simulator      # iOS Simulator 부팅 후 run (서명 불필요)
#   bash scripts/run-ios.sh build          # --no-codesign 컴파일 검증만
#
# 전제:
#   - macOS + Xcode (App Store) + CocoaPods (`sudo gem install cocoapods`)
#   - Flutter SDK (CI 핀: 3.41.6 stable)
#   - 실기기 실행 시: Xcode 에서 무료 개인 서명(Personal Team) 또는 Apple Developer 계정
#   - 자세한 절차/테스트 체크리스트: docs/ios-test-handoff.md

set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
  echo "❌ iOS 빌드/실행은 macOS + Xcode 에서만 가능합니다 (현재 OS: $(uname))." >&2
  echo "   Windows/Linux 라면 docs/ios-test-handoff.md 의 'CI Release 경로' 를 참고하세요." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ flutter 가 PATH 에 없습니다. https://docs.flutter.dev/get-started/install/macos" >&2
  exit 1
fi

MODE="${1:-run}"
log() { echo "[$(date +%H:%M:%S)] $*"; }
sep() { echo "================================================================"; }

sep
log "▶ flutter pub get"
flutter pub get

case "$MODE" in
  build)
    sep
    log "▶ iOS 컴파일 검증 (--no-codesign, 서명 없이 빌드만)"
    flutter build ios --no-codesign --debug
    sep
    log "✅ iOS 빌드 성공 — 컴파일/플러그인 통합 정상 (실기기 설치는 서명 필요)"
    ;;
  simulator)
    sep
    log "▶ iOS Simulator 부팅"
    open -a Simulator || true
    # 부팅 대기 (이미 떠 있으면 즉시 통과)
    until xcrun simctl list devices booted | grep -q "Booted"; do sleep 2; done
    sep
    log "▶ Simulator 에 실행 (서명 불필요 — 가장 빠른 테스트 경로)"
    flutter run
    ;;
  run | *)
    sep
    log "▶ 연결된 iOS 기기 / Simulator"
    flutter devices
    sep
    log "▶ flutter run (기기 자동 선택)"
    log "  실기기면 Xcode 서명 필요 — 미설정 시: open ios/Runner.xcworkspace 에서"
    log "  Signing & Capabilities → Team = 본인 Apple ID(Personal Team) 설정 후 재시도"
    flutter run
    ;;
esac

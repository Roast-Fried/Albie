# iOS 테스트 핸드오프 가이드

> 이 프로젝트는 Windows 에서 개발돼 iOS 빌드/실행은 **Mac + Xcode 가 있는 테스터**가 맡습니다.
> 코드/설정 정적 분석 + 플러그인 podspec 교차검증 기준 **즉시 크래시·앱스토어 거부 위험 0건**이지만,
> 실제 컴파일·런타임은 본 문서로 Mac 에서 검증해야 합니다.

대상 버전: **0.4.0+4** · 배포 타겟: **iOS 13.0** · Flutter 핀: **3.41.6 stable**

---

## 0. 사전 준비 (테스터 / macOS)

```bash
# 1) Xcode (App Store) 설치 후 1회 실행해 컴포넌트 동의
sudo xcodebuild -license accept
# 2) CocoaPods
sudo gem install cocoapods
# 3) Flutter (3.41.6 stable 권장)
flutter --version
flutter doctor            # iOS toolchain 항목 ✓ 확인
# 4) 프로젝트
git clone https://github.com/RoastFried-RF/Albie.git
cd Albie
git checkout <테스트할 브랜치>   # 0.4.0 변경이 들어간 브랜치
flutter pub get
```

> ⚠️ 현재 0.4.0 변경분이 아직 push 안 됐다면 먼저 해당 브랜치를 push 해야 테스터가 받을 수 있습니다.

---

## 1. 실행 경로 (난이도순)

### 경로 A — iOS Simulator (가장 쉬움, 서명 불필요) ✅ 권장 1순위
실기기·Apple 계정 없이 대부분 기능 테스트 가능.
```bash
bash scripts/run-ios.sh simulator
# 또는 수동:
open -a Simulator
flutter run
```
- ⚠️ Simulator 한계: **카메라/실사진 라이브러리 제한**(음식 사진은 시뮬레이터에 미리 사진 추가 필요), 푸시/알림 권한 다이얼로그는 동작.

### 경로 B — 실 iPhone + 무료 개인 서명 (Apple Developer Program 불필요) ✅ 권장 2순위
무료 Apple ID 로 7일짜리 임시 서명 → 본인 기기에서 실제 동작 확인 (사진/알림/Keychain 전부 실환경).
```bash
open ios/Runner.xcworkspace
# Xcode: Runner 타깃 → Signing & Capabilities
#   - Team = 본인 Apple ID (Personal Team)
#   - Bundle Identifier 충돌 시 끝에 .test 등 추가로 고유화
# 기기 USB 연결 → 신뢰 → Run(▶) 또는:
flutter run            # (bash scripts/run-ios.sh)
```
- 7일 후 서명 만료 → 재실행 필요. 다수 테스터엔 부적합(아래 경로 D).

### 경로 C — CI Release 산출물 (unsigned `Runner.app.zip`)
`v*` 태그 push 시 `release.yml` 이 자동으로 GitHub Release 에 `Runner.app.zip`(unsigned) 업로드.
- 일반 iPhone 직접 설치 **불가** — Xcode/Sideloadly 같은 sideload 도구로 본인 기기에 설치해야 함.
- 컴파일이 macOS CI 에서 통과했음을 보장(빌드 깨짐 감지). 실제 "테스트 배포"엔 경로 B 또는 D 권장.

### 경로 D — TestFlight (다수 테스터 배포, 향후 옵션)
가장 매끄럽지만 **Apple Developer Program($99/년) + App Store Connect** 필요. 현재 미구성.
설정 시 필요한 것:
- Apple Developer 계정 + App ID(`com.roastfried.albi`) 등록
- App Store Connect API Key → GitHub Secrets (`APP_STORE_CONNECT_*`)
- 서명용 distribution cert + provisioning profile (또는 fastlane match)
- `release.yml` 에 TestFlight 업로드 job 추가 (fastlane pilot / `xcrun altool`)

> "일단"은 경로 A/B 로 충분. 외부 테스터가 늘면 경로 D 를 별도로 구성.

---

## 2. 테스트 체크리스트 (이번 0.4.0 신규/변경 중심)

| # | 기능 | 확인 포인트 | iOS 특이 |
|---|------|------------|----------|
| 1 | **앱 버전** | 설정/시스템 정보에 0.4.0 표기 | Info.plist `$(FLUTTER_BUILD_NAME)` 자동 |
| 2 | **온보딩 5페이지** | 환영→파서→AI키→**알림**→시작. 점 인디케이터 5개 | 첫 실행(앱 삭제 후 재설치)에서 노출 |
| 3 | **알림 권한 안내** | 온보딩 "알림 켜기" → iOS 권한 다이얼로그 표시·허용 | 런타임 권한(Info.plist 키 불필요) |
| 4 | **AI 키 연결** | "AI로 생성"(키 없음)→가이드 바텀시트→"키 발급 페이지 열기"→**Safari 열림**→키 복사 후 복귀 시 자동 채움→연결 | url_launcher Safari, Clipboard 접근 시 배너 정상 |
| 5 | **AI 생성 로딩** | 생성 중 단계 카드(입력→술 정보→정리) + 경과초 + 취소 | 순수 Flutter |
| 6 | **음식 사진 AI** | 검토 화면 "사진으로 추가(AI)" → 사진 선택 → 자동 음식 칩 | **사진 권한 다이얼로그**(NSPhotoLibraryUsageDescription) 표시 확인 |
| 7 | **하단 안전영역** | 노치/홈인디케이터 기기에서 모든 화면 하단 버튼·시트(저장/취소) 안 가림 | `MediaQuery.padding.bottom` = 홈인디케이터 inset |
| 8 | **테이스팅/컨디션 시트** | 키보드 닫은 상태로 저장/취소 버튼 가림 없음 | 홈인디케이터 위로 노출 |
| 9 | **다크모드/회전** | 설정 다크모드, 세로 고정(iPad는 회전 허용) | |

---

## 3. 알려진 iOS 주의점 (Codex 교차검증, 비차단)

- **Keychain — Gemini API 키 동기화**: 기본 `FlutterSecureStorage` 접근성은 iCloud Keychain 백업 대상. 사용자가 입력한 개인 API 키가 다른 iOS 기기로 동기화될 수 있음. 또한 iOS 는 앱 삭제해도 Keychain 키가 **남음**(Android 와 다름) → 재설치 시 키가 살아있을 수 있음. 기기 한정으로 막으려면 `KeychainAccessibility.unlocked_this_device` 적용 검토 (미적용 상태).
- **알림 foreground 표시**: `FlutterAppDelegate` 가 `UNUserNotificationCenter.delegate` 를 자동 설정 → 별도 코드 불필요(검증됨). 권한 요청·예약 발사 정상.
- **permission_handler 미사용 의존성**: `pubspec.yaml` 에 선언만 됨(코드 미사용) → iOS pod 불필요 포함. 제거 검토 가능.
- **Impeller**: Android 만 비활성(특정 기기 회피), iOS 는 기본 Impeller(가장 안정).

---

## 4. 빠른 검증 (테스터가 가장 먼저 할 것)

```bash
bash scripts/run-ios.sh build      # 1) 컴파일/플러그인 통합부터 확인
bash scripts/run-ios.sh simulator  # 2) Simulator 로 UI 흐름 확인
# 3) 실기기(경로 B)로 사진/알림/Keychain 실환경 확인
```

문제 발생 시 보고: `flutter doctor -v` 출력 + 빌드/런타임 에러 로그 + 기기 모델/iOS 버전.

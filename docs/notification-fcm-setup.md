# FCM (서버 push) 설정 가이드

본 cycle 의 Phase C2 알림 구현은 **local notification** (device 자체 schedule).
서버 주도 push (FCM/APNs) 이 필요하면 별도 인프라 셋업 필요.

## 현재 구현 범위 (local — 즉시 동작)

- `flutter_local_notifications` 기반.
- 4 시나리오: 주간 요약 / 재방문 reminder / 새벽 음주 follow-up / 건강 신호.
- 사용자 device 의 timezone (Asia/Seoul) 기반 schedule.
- Settings → "알림" 화면에서 type 별 toggle.
- 권한: Android 13+ POST_NOTIFICATIONS / iOS UNUserNotificationCenter.

## FCM 추가 시 필요 작업

서버에서 push 보내려면 (예: 학과 공지 / 친구 음주 초대 등) 다음 인프라 필요:

### 1. Firebase 프로젝트 생성 (사용자 액션)

1. https://console.firebase.google.com → "프로젝트 추가"
2. 프로젝트 이름: `albi-app` (또는 임의)
3. Google Analytics: 선택 (학생 과제 범위는 비활성 권장)

### 2. Android 앱 등록

1. Firebase 프로젝트 → "Android 앱 추가"
2. 패키지 이름: `com.example.albi` (확인 — `android/app/build.gradle.kts` 의 `applicationId`)
3. `google-services.json` 다운로드 → `android/app/` 에 배치
4. `android/build.gradle.kts` 의 `dependencies` 에 `classpath("com.google.gms:google-services:4.4.2")` 추가
5. `android/app/build.gradle.kts` 의 plugin 에 `id("com.google.gms.google-services")` 추가

### 3. iOS 앱 등록

1. Firebase 프로젝트 → "iOS 앱 추가"
2. Bundle ID 확인 (`ios/Runner.xcodeproj` 의 `PRODUCT_BUNDLE_IDENTIFIER`)
3. `GoogleService-Info.plist` 다운로드 → `ios/Runner/` 에 Xcode 로 추가
4. APNs 인증서 또는 Authentication Key 업로드 (Apple Developer Program 필수)

### 4. Flutter 패키지 추가

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.0
```

### 5. 코드 통합

```dart
// main.dart
await Firebase.initializeApp();

// FCM 토큰 가져오기
final token = await FirebaseMessaging.instance.getToken();
// → 서버에 저장 (사용자 식별자와 매핑)

// 포그라운드 메시지 listener
FirebaseMessaging.onMessage.listen((message) {
  NotificationService.instance.showNow(
    title: message.notification?.title ?? '',
    body: message.notification?.body ?? '',
  );
});

// 백그라운드 메시지
FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
```

### 6. 서버 (cloud function 또는 자체 backend)

FCM Admin SDK 로 push 발송:
- Node.js / Python / Go 등.
- Firebase Cloud Functions 무료 tier 가능.
- 학과 서버 / Vercel / Cloud Run 등 자체 호스팅도 가능.

## 비용 / 이슈

- **Firebase**: Spark plan (무료) — push 10만 건/월. 학생 과제 범위 충분.
- **Apple Developer Program**: $99/년 — iOS APNs push 필수. 학생 과제 범위는 Android only 권장.
- **개인정보**: FCM 토큰은 device 식별자 — 사용자 익명 가능 (uid + token 매핑만).

## 권장 (학생 과제 범위)

- Local notification 만으로 충분 (4 시나리오 + 재방문 reminder + 주간 요약 모두 device 처리).
- 서버 주도 push 필요 시점 (예: 친구간 음주 초대 / 동아리 공지) 에 FCM 추가.

## 적용 안 한 이유 (현 cycle)

1. Firebase 프로젝트 설정 — 사용자 액션 (Google 계정 / 콘솔 접근)
2. APNs — Apple Developer $99 비용
3. 학생 과제 범위 안에서 retention 효과 — local 만으로 달성 (Phase C2 plan 명시)

추가 필요 시 본 문서의 1-6 단계 진행 후 새 sprint 로 통합.

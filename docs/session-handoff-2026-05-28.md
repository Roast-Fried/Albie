# 세션 handoff — 2026-05-28

다음 세션이 즉시 이어받을 수 있도록 현재 상태 + 미해결 항목 + 다음 step 정리.

## 현재 상태

### main branch
- HEAD: `72ae739` docs: Phase C2 알림 sprint 결과 명시
- remote main 과 동일 (push 완료, unpushed 0)
- v0.2.2 tag push 완료

### 누적 commits (v0.2.1 → v0.2.2)

1. `d74acc3` ci: artifact upload 우회 (gh API contents 로 remote 직접 commit)
2. `bee0e98` test: seeded data + dialog/sheet capture 인프라
3. `94b6a2a` test: seeded 잔여 4건 보강
4. `6deb9cb` fix: parser 정확도 + 별점/검색 + Node.js 24 강제
5. `f17cdc9` docs: plan v3 + skip 의사결정
6. `b7d9bb2` feat: Phase C2 알림 — local notifications (10 files +733 lines)
7. `6c38ab6` fix: Phase C2 audit 2건 (healthSignal + master 재ON)
8. `72ae739` docs: Phase C2 sprint 결과 + audit finding 4건 보류

## 🚨 미해결 — 다음 세션 즉시 fix 필요

### v0.2.2 CI fail (build-android)

**원인**: `flutter_local_notifications: ^17.2.4` 가 Android core library desugaring 요구. v0.2.2 build 4분 후 fail:
```
Dependency ':flutter_local_notifications' requires core library desugaring
to be enabled for :app.
```

**Fix** (`android/app/build.gradle.kts`):
```kotlin
android {
    compileOptions {
        // flutter_local_notifications 17.x desugaring 요구.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

기존 `compileOptions` block 가 있으면 두 줄 (`isCoreLibraryDesugaringEnabled` + `coreLibraryDesugaring`) 만 추가.

**검증 sequence**:
```bash
cd d:/01.Work/08.rf/albi
# build.gradle.kts 수정 후
/d/flutter/bin/flutter build apk --debug 2>&1 | tail -20   # local 검증
git add android/app/build.gradle.kts
git commit -m "fix: Android core library desugaring (flutter_local_notifications 17.x 요구)"
git push origin main

# v0.2.2 tag 재발화 또는 v0.2.3 신규
gh release delete v0.2.2 --cleanup-tag --yes
gh release create v0.2.2 --target main --title "v0.2.2" --notes "..."
# 또는
git tag v0.2.3 && git push origin v0.2.3
```

### iOS Podfile 도 필요 가능

`ios/Podfile` 의 `platform :ios` 가 `'12.0'` 이상이어야 flutter_local_notifications 호환. 미만 시:
```ruby
platform :ios, '12.0'
```

(현재 Podfile 확인 안 함 — fix 시 점검)

## 작업 영역 잔여 (LOW, 별도 sprint)

Phase C2 알림 Codex audit 4 finding (plan-phase-c-domain-differentiation.md 명시):

- **Finding 1**: 싱글톤 `NotificationService.instance` test 격리 — integration_test 실 시나리오 무해
- **Finding 4**: timezone `Asia/Seoul` 하드코드 — 학생 과제 OK, 해외 사용자 device timezone 자동
- **Finding 6**: iOS `isPermissionGranted` 항상 true — SharedPreferences 캐싱 권장
- **Finding 7**: `AndroidScheduleMode.inexactAllowWhileIdle` Doze delay — `exactAllowWhileIdle` 변경 권장 (USE_EXACT_ALARM Manifest 등록됨)

미커버 시나리오 4건 (plan-ui-issues.md 명시):
- ErrorStateWidget mock error capture
- AI 로딩 / 실패 배너 capture (timing race)
- LogList long-press 삭제 capture
- Stats 1년+ 데이터 variation

## 사용자 환경 액션 (다음 세션 시작 전 권장)

### 🔴 보안 (즉시)
- 노출된 PAT `ghp_EnQ...` revoke → https://github.com/settings/tokens
- 노출된 Gemini API key `AIzaSy...` revoke → https://aistudio.google.com/apikey
- 새 PAT 발급 (필요 시)

### 🟡 도구 (필요 시)
- Codex CLI 재로그인 (refresh token already used):
  ```bash
  codex logout
  codex login
  ```
- 검증: `Agent(opnd-codex:codex-rescue, "ping audit")` 호출 성공해야 fully 재인증.

### 🟢 Optional
- Firebase 콘솔 — FCM 서버 push 필요 시 (docs/notification-fcm-setup.md 6 단계)

## 다음 세션 추천 첫 step

```
1. Read docs/session-handoff-2026-05-28.md (본 파일)
2. android/app/build.gradle.kts 의 core library desugaring 추가
3. flutter build apk --debug 로컬 검증
4. commit + push + v0.2.2 재발화 (또는 v0.2.3)
5. CI 통과 확인
6. (Optional) Codex 재인증 후 audit 호출
```

## 누적 통계

- **Total commits** (v0.1.0 → v0.2.2): ~30
- **PNG capture**: 89+ (home/draft/archive/stats/log/settings/onboarding/theme light+dark/seeded)
- **UI 깨짐 fix**: 13건
- **Codex audit**: 7회 (Sprint 1/fc1dddf/Sprint 4/5commit cum/Sprint 8/C2 Phase + setup verification)
- **Skip 결정**: 8건 (plan 명시)
- **Phase C2 알림**: 4 시나리오 + Settings UI + 저장 hook + FCM 안내

## 알려진 호환성 issue (별도 문서화)

- flutter_local_notifications 17.x → Android desugaring 필수 (위 fix)
- iOS APNs 인증서 부재 → unsigned 빌드만 가능 (Apple Dev $99 필요 — TestFlight 배포 시)
- Pretendard 폰트 4 weight ~6MB → APK 사이즈 영향 (NotoSansKR 10MB 대비 ~40% 절감)
- Node.js 20 deprecation → `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` 환경변수로 선제 호환 (release.yml 적용)

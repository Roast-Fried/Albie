# Phase C — 도메인 차별화 신규 기능 plan

> UI/UX 평가 6 라운드 (`docs/analyze/2026-05-18-*.md`) 의 옵션 C 영역.
> Audit 가 아닌 product strategy 결정 필요 영역 — 사용자 결정 후 implementation.
>
> 우선순위: 사용자 가치 ↔ 구현 effort trade-off 명시.

---

## C1. 표준잔 / 순알코올 계산 + 시각화 (HIGH ROI)

### 가치

- 음주 기록 앱의 핵심 도메인 가치 — 단순 횟수 → 양 정량
- Round 6 Agent Y BAC 계산 부재 finding 의 해결
- Round 6 Codex CX5 Alcohol Quantification Gap 의 product vision 차원

### 데이터 모델

- `DrinkEntry.alcoholPercent` (이미 존재)
- `DrinkEntry.quantityValue` + `quantityUnit` (이미 존재)
- 단위 → ml 변환 매핑 신규:
  - shot = 30ml, glass = 200ml (와인) / 50ml (위스키 — 카테고리별 분기 필요), pint = 500ml, can = 350ml, bottle = 750ml (와인) / 500ml (맥주) / 360ml (소주) 등
  - **결정 필요**: 같은 unit 도 카테고리별 다른 ml — `unitToMl(category, unit)` 함수
- 순알코올 g = `volume_ml × abv% × 0.789` (에탄올 밀도)
- 표준잔 환산 = 순알코올 g / 14 (미국 표준잔 1잔 = 14g) 또는 / 10 (한국 보건부 권장 표준잔 10g)
  - **결정 필요**: 한국 표준 (10g) 채택 권장

### UI 변경

- **draft_review_screen**: 항목 카드 하단에 "이 음주 = 표준잔 X잔 (순알코올 Yg)" inline 표시
- **stats_screen**: 새 카드 "이번 주 표준잔 N / 권장 한도 14잔" + progress bar
- **log_detail**: 같은 표시
- **새 화면**: "건강 신호" → 주간 음주량 추세 + 권장량 비교

### 권장 한도 (한국 보건복지부 기준)

- 남성: 주 14표준잔 이하 (1일 2잔 이하)
- 여성: 주 7표준잔 이하 (1일 1잔 이하)
- 사용자 profile (성별) 부재 — onboarding 추가 필요? privacy trade-off

### Effort

- 데이터 모델 + 함수: S (1-2일)
- UI 표시: M (2-3일)
- 새 화면 (건강 신호): M (2-3일)
- 사용자 profile (성별 선택): S (1일)

**총: M-L (1-2주)**

### 우선순위

**HIGH** — 음주 기록 앱의 핵심 가치. 다른 앱 (DrinkControl 등) 대비 차별화.

---

## C2. 알림 / 리마인더 (flutter_local_notifications)

### 가치

- Round 2 발견: 알림 시스템 전무
- Round 6 Agent Y retention loop 5 gap (Day 3 streak / Day 7 summary / Day 14 at-risk)
- 사용자 재방문율 직접 영향

### 패키지

- `flutter_local_notifications: ^17.x` (필요 OS 권한 별도)
- iOS: `UNUserNotificationCenter` 권한 + Info.plist
- Android: `POST_NOTIFICATIONS` (Android 13+) + AndroidManifest 권한

### 사용 시나리오

1. **Day 1 첫 기록 reward** — 이미 Phase 0 에서 Snackbar 처리됨. 알림 ✗
2. **Day 3 streak indicator** — 3일 연속 시 inline (홈) — 알림 ✗
3. **Day 7 weekly summary** — 매주 일요일 21:00 "이번 주 기록 N건"
4. **Day 14 at-risk reminder** — 3일 이상 미기록 시 "한 동안 기록이 없어요"
5. **음주 후 다음날 추가 기록** — 새벽 음주 기록 → 다음날 오후 "어제 추가로 기록할 것 있나요?"
6. **건강 신호 알림** — 주간 표준잔 초과 시 "이번 주 N잔 마셨어요. 휴식 권장"

### UI 변경

- Settings 에 "알림" section 추가 (각 type on/off toggle)
- onboarding 후반에 알림 권한 요청 (skip 가능)

### Effort

- 패키지 도입 + 초기 설정: S (1일)
- 권한 flow + onboarding 통합: S (1일)
- 시나리오 1-6 구현 (스케줄러): M (2-3일)
- Settings UI: S (1일)

**총: M (1주)**

### 우선순위

**MEDIUM-HIGH** — retention 직결. 다만 OS 권한 거부 시 비활성.

### 진행 결과 (2026-05-28, 5522d0d + 76bd54e)

✅ **완료**:
- 패키지 도입 (`flutter_local_notifications ^17.2.4` + `timezone ^0.9.4` + `permission_handler ^11.3.1`)
- Android perm + iOS 런타임 권한 요청
- NotificationService (4 시나리오: weekly summary / at-risk / late night follow-up / health signal)
- NotificationSettingsViewmodel + Settings UI (master + 4 type toggle)
- saveToDb hook 자동 재스케줄
- master 재ON 시 lastDrankAt 기반 재스케줄 (audit Finding 5 fix)
- healthSignal saveToDb hook 통합 (audit Finding 3 fix)
- FCM 서버 push 안내 문서 (docs/notification-fcm-setup.md)

🟡 **별도 sprint 보류** (Codex audit LOW):
- Finding 1: 싱글톤 NotificationService.instance test 격리 — integration_test 실 시나리오 무해, unit test 만 영향
- Finding 4: timezone Asia/Seoul 하드코드 — 학생 과제 범위 OK, 해외 사용자 device timezone 자동 감지로 별도
- Finding 6: iOS isPermissionGranted 항상 true 반환 — SharedPreferences 캐싱 필요 (마지막 requestPermissions 결과 저장)
- Finding 7: inexactAllowWhileIdle Doze delay — exactAllowWhileIdle 로 변경 권장 (USE_EXACT_ALARM Manifest 이미 등록)

❌ **미구현 시나리오** (plan 의 1-2번):
- Day 1 첫 기록 reward — 이미 Phase 0 의 Snackbar
- Day 3 streak indicator — 홈 inline (알림 X)

onboarding 권한 요청 step 도 별도 — Settings.setMaster 시점에 권한 요청하므로 onboarding 거치지 않아도 정상 동작.

---

## C3. Multi-user / Co-drinking session

### 가치

- Round 5 Codex Stage 1 + Claude Stage 3 nominate
- Albi 도메인 — 술자리는 보통 사회적 (혼술 vs 회식 vs 친구)
- 같은 시간대 친구와 함께 기록 (split bill 같은 패턴)

### 옵션

**Option C3a (낮은 effort)**: tag-based — `DrinkLog.companions: List<String>` 필드
- "함께 마신 사람" 텍스트 (free-form 또는 chip)
- Stats 에 "혼술 vs 회식 vs 친구" 분포
- 다른 사용자 계정 ✗ (single-device 유지)

**Option C3b (중간 effort)**: occasion tag — `DrinkLog.occasion: String` enum
- 혼술 / 회식 / 친구 모임 / 가족 / 데이트 / 기타
- Bullet journal 패턴의 occasion (Round 5 Agent A)

**Option C3c (높은 effort)**: 다중 계정 sync — cloud DB (Firebase/Supabase) 도입
- 전체 아키텍처 변경 — single device → multi device
- Round 6 Agent Y "Cross-device sync 부재" 해결
- 음주 기록 = 민감 정보 — privacy 강력 필요

### 권장

- **Option C3a + C3b 동시** — `companions` 텍스트 + `occasion` enum. 양쪽 stats 분기.
- Option C3c 는 별도 long-term decision (사용자 수 / 가치 검증 후)

### Effort

- C3a + C3b: M (1주, DB 마이그레이션 포함)
- C3c: XL (4주+, cloud sync 인프라)

---

## C4. i18n 영문 진입

### 가치

- Round 1 finding (8) — `flutter_localizations` deps 있으나 미사용
- 한국어 hardcoded ~200+ 문자열
- 글로벌 진출 시 필수, 국내 영어 사용자 (외국인) 보조

### Implementation

1. `flutter gen-l10n` 설정 (l10n.yaml + arb 파일)
2. 모든 한국어 hardcoded 문자열 → `AppLocalizations.of(context).key`
3. ko.arb (default) + en.arb 작성
4. `MaterialApp.localizationsDelegates` 활성화 (이미 wired)
5. Settings 에 언어 선택 UI

### Effort

- 셋업: S (반나절)
- 문자열 추출 + 영문 번역 (200+): L (1-2주)
- 한국어 톤 유지 + 영문 자연스러움: 별도 카피라이팅 비용
- Settings UI: S (반나절)

**총: L (1-2주)**

### 우선순위

**LOW** — 사용자 base 영어권 진출 결정 후. 국내 영어권은 sub-1% 가능성.

---

## C5. (보너스) 라벨 사진 갤러리

### 가치

- Round 5 Agent A (Pinterest illustration 보드)
- Round 6 Agent Y persona (collector / 시음가)
- 술 라벨 사진 모음 — 추억 + 재구매 reference

### Implementation

- `DrinkLog.rawImagePath` (이미 존재)
- 새 화면: "라벨 갤러리" — 시간순 grid 또는 카테고리별 grouping
- 라벨 사진 클릭 → log detail
- 필터: 카테고리 / 별점 / 가격

### Effort

- 새 화면: M (2-3일)

### 우선순위

**LOW** — UX 가치는 있으나 핵심 가치 (기록) 외. C1 / C2 후 진행.

---

## 권장 진행 순서

1. **C1 표준잔 / 순알코올** (M-L, HIGH ROI) — 즉시 진행 권장
2. **C2 알림** (M, retention) — 진행 권장 (OS 권한 결정 필요)
3. **C3 occasion + companions** (M, social context) — 진행 가능
4. **C5 라벨 갤러리** (M, polish) — 여유 시
5. **C3c cloud sync** (XL) — long-term decision
6. **C4 i18n** (L) — 글로벌 진출 결정 후

---

## 결정 필요 사항

- [ ] 한국 표준잔 (10g) 채택? 또는 미국 (14g)?
- [ ] 사용자 성별 onboarding 추가? (권장량 분기 위함)
- [ ] 알림 type 6종 모두 활성? 또는 일부만?
- [ ] occasion enum 6항 (혼술/회식/친구/가족/데이트/기타) 확정?
- [ ] companions free-form vs chip?
- [ ] i18n 진행 여부 (영어권 사용자 base 검증)

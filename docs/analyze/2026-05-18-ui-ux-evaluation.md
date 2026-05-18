# Albi UI/UX 종합 평가 리포트 (2026-05-18)

> **목적**: Albi (Flutter 음주 기록 앱) 전체 디자인 + UI/UX 의 객관적·비판적 평가 + Codex cross-validation. 미탐색 0 조건 달성까지 다라운드 진행.
>
> **방법**: 4 라운드 (총 11 agent) 병렬 fan-out — Claude Explore + Codex Independent.
> Round 1 (4 agent): Design Tokens / Per-Screen UI/UX / Flow IA / Codex Round 1.
> Round 2 (3 agent): Widget Deep Dive / Microcopy + Korean UX / Codex Production-readiness.
> Round 3 (2 agent): Stats + App Identity + Motion + Performance / Codex Final Exhaustive.
> **Round 4 (2 agent): Pinterest reference 시각 비교 + Codex Visual Differential** — Playwright MCP 로 송지나 "대시보드" + "시각디자인" 보드 캡처 후 Albi golden 7장과 직접 시각 대조.
>
> **검증**: § 2.5 parent re-verification + § 2.6 Codex cross-validation + § 2.7 Coverage audit 통과 항목만 surface.
>
> **결론**: Codex Agent 9 saturation 평가 — "Round 4 (시각 외) 비권장". Round 4 추가 fan-out 은 사용자 요청으로 진행, Pinterest reference 와의 시각 gap 10건 + Codex differential 5건 추가 확보. Total finding ~95 건 (시각 finding 통합), severity 별 분류.

---

## Rejected Claims (재검증 결과 기각)

| Claim | 원 agent | 재검증 결과 |
|---|---|---|
| iOS app icon PNG 16개 누락 | Round 3 Agent 8 Finding 2.1 | REJECTED — `ios/Runner/Assets.xcassets/AppIcon.appiconset/` literal 확인 결과 Icon-App-20x20@1x ~ 1024x1024@1x 까지 16 PNG 모두 존재 |

**모든 다른 CRITICAL / HIGH finding 재검증 통과.**

---

## Codex Cross-Validation (§ 2.6, 3 round 통합)

3 라운드에 걸쳐 Claude 5 agent + Codex 3 agent 합계 9 agent 가 평가. Cross-validation 4 분류:

### Agreed (Claude + Codex 일치)
- 디자인 토큰 시스템은 정의되어 있으나 화면에서 미활용 (hardcoded color/size/spacing)
- AI scope 위반: `ai_settings_viewmodel.dart:49` GeminiClient 직접 instance
- StarRating Semantics 부재 + Chip touch target <48dp + 아이콘 전용 IconButton tooltip 없음
- 11 screens 모두 활성 사용, dead screen 없음
- Local fallback (LocalRuleParser) 정상 동작, AI 없이도 앱 사용 가능
- Microcopy 톤 (평어 vs 존댓말) 혼재

### Claude-only (Codex 미발견 → confidence 1 단계 down)
- 카테고리 map triplicate (Agent 6 only — Codex 미언급)
- Period filter empty state 미처리 (Agent 8 only)
- Search 스크롤 위치 복원 없음 (Agent 3 only)
- Hero animation / 거의 모든 motion 부재 (Agent 1 + 8 vs Codex Agent 4 finding 3.1 — partial agreement)

### Codex-only (3 Claude agent 미발견, parent 재검증 통과)
- **nullable copyWith null clear 버그** (Codex Round 1, parent verified → 이미 commit `a9a63da` 에서 수정)
- **DrinkLogRepository.update() silent no-op** (Codex Round 1 → 이미 commit `a9a63da` 에서 수정)
- **ParseJob 'fallback' status 정의만 있고 기록 안 됨** (Codex Round 1, parent verified)
- **parseJob 원문 영구 잔류** (Codex Round 2, parent verified, CRITICAL)
- **Android INTERNET 권한 미선언** (Codex Round 2, parent verified, CRITICAL)
- **iOS NSPhotoLibraryUsageDescription 미선언** (Codex Round 2, parent verified, CRITICAL)
- **Android release debug keystore 사용** (Codex Round 3, parent verified, CRITICAL)
- **AI default enabled + 동의 없이 첫 실행 외부 전송** (Codex Round 2, parent verified)
- **Global crash handler 부재** (Codex Round 2, parent verified)
- **미래 날짜 입력 허용** (Codex Round 3, parent verified)
- **stats period filter 전역 stale state** (Codex Round 3, parent verified)
- **검색 시 즉시 AsyncLoading flicker** (Codex Round 3, parent verified)
- **AI Settings API key 미저장 뒤로가기 silent loss** (Codex Round 3, parent verified)
- **food_dictionary 36종 + place_keywords 추천 미활용** (Codex Round 3)
- **place 즐겨찾기 모델 부재** (Codex Round 3)
- **단위 ml 환산 표시 없음** (Codex Round 3)

### Disagreements (Codex 가 Claude REJECTED)
- iOS icon PNG 누락 (Agent 8) — Codex Round 3 silent. Parent 재검증으로 REJECTED.
- tasting_note_viewmodel 의 gemini 직접 import "위반" 등급 (Agent 3 vs Codex 1차 round) — 보존적 판단 채택 → 강도 down

---

## Coverage Audit (§ 2.7 positive claim verification)

| # | Claim | Depth | Verdict |
|---|-------|-------|---------|
| 1 | "11 screens 모두 활성 사용" | L2 | CONFIRMED |
| 2 | "Local parser fallback 정상 동작" | L2 | CONFIRMED — parse_orchestrator.dart:66-76 literal |
| 3 | "MVVM + Riverpod 견고" | L2 | CONFIRMED — view→viewmodel→repo 위반 0건 |
| 4 | "Hero/Animated* 전무" | L1 | DOWNGRADED — grep empty 확인했으나 일부 implicit transition 가능 |
| 5 | "Dark mode parity 미완" | L2 | CONFIRMED — inputDecorationTheme.fillColor + cardTheme.color 두 곳 누락 |
| 6 | "i18n 미사용" | L2 | CONFIRMED — flutter_localizations 등록 but AppLocalizations 미생성 |
| 7 | "Production-readiness 4 CRITICAL" | L2 | CONFIRMED — Android/iOS manifest + signing + parseJob 모두 literal 확인 |
| 8 | "음주 도메인 차별화 부재" | L1 | DOWNGRADED — 표준잔/순알코올 시각화 없음은 CONFIRMED 이나 "차별화 부재" 일반화는 L1 |

총 8 단정 중 **CONFIRMED 6 / DOWNGRADED 2**.

---

## 🚨 CRITICAL — 출시 차단 결함 (4건, 모두 fix 후 production 가능)

| # | 결함 | 증거 | 액션 |
|---|------|------|------|
| 1 | **Android INTERNET 권한 미선언** — release build 시 모든 HTTP 호출 실패 | [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) — `<uses-permission android:name="android.permission.INTERNET"/>` 부재 | `<manifest>` 안에 추가 |
| 2 | **iOS NSPhotoLibraryUsageDescription 미선언** — App Store reject | [ios/Runner/Info.plist](ios/Runner/Info.plist) — 70 라인 전체 확인, 권한 key 없음 | "사진 라이브러리 사용 사유" 한글 안내 + `NSCameraUsageDescription` 도 함께 |
| 3 | **Android release debug keystore 사용** — Play Store reject | [android/app/build.gradle.kts](android/app/build.gradle.kts) — `signingConfig = signingConfigs.getByName("debug")` literal | 별도 release keystore 생성 + `key.properties` + gradle 분기 |
| 4 | **parseJob.rawRequest 영구 잔류** — 사용자 "전체 기록 삭제" 후에도 원본 텍스트 보관 → 개인정보 보호 위반 | [parse_orchestrator.dart:85](lib/integrations/parser/parse_orchestrator.dart#L85) + [settings_viewmodel.dart:31](lib/viewmodels/settings_viewmodel.dart#L31) | `resetAllRecords` 에서 `parseJob` 도 함께 삭제 또는 `rawRequest` NULL 처리 |

---

## ⚠️ HIGH — UX blocking / 데이터 무결성 (18건)

### 데이터 / 안전성

| # | 결함 | 증거 | 액션 |
|---|------|------|------|
| 5 | AI default enabled — 동의 없이 첫 실행에서 외부 API 가능 | [database_helper.dart:127](lib/core/database/database_helper.dart#L127) `isEnabled DEFAULT 1` | 첫 실행 동의 화면 또는 default 0 |
| 6 | Global crash handler 부재 — production 오류 수집 불가 | [main.dart](lib/main.dart) — `runZonedGuarded`, `FlutterError.onError` 모두 없음 | crashlytics / sentry 또는 기본 zone guard |
| 7 | AI 401 expiry auto-recovery 없음 — 만료 키 영구 사용, 사용자 인지 불가 | [parse_orchestrator.dart:169-181](lib/integrations/parser/parse_orchestrator.dart) | 401 catch 시 keyMode=app_default 전환 + 사용자 알림 banner |
| 8 | Quantity / ABV negative/zero 입력 허용 | [entry_card_widget.dart:63](lib/views/draft_review/widgets/entry_card_widget.dart#L63) `double.tryParse ?? 1.0` silent fallback | validator 추가, 음수/0 reject + errorText |
| 9 | 0-entry record 저장 허용 | draft_review_screen.dart `_save()` validation 없음 | save 직전 `entries.where(empty).isEmpty` 검사 |
| 10 | DB save error 재시도 없음 — 사용자가 다시 입력 | [draft_review_screen.dart:255](lib/views/draft_review/draft_review_screen.dart#L255) `SnackBar('저장 실패: $e')` | Snackbar action "다시 시도" + form state 보존 |
| 11 | Error message raw exception 노출 (`DioException`, `SqliteException`) | 여러 곳 | AppError.userMessage 로 wrap |
| 12 | 미래 날짜 입력 허용 (내일까지) | [draft_review_screen.dart:279](lib/views/draft_review/draft_review_screen.dart#L279) `lastDate: ...add(days: 1)` | `lastDate: DateTime.now()` 로 |
| 13 | Quota exhaustion 사일런트 — 401 받기 전까지 알 수 없음 | [ai_settings_screen.dart:137-148](lib/views/settings/ai_settings_screen.dart) | 진행 바 + "5회 남음" 경고 |
| 14 | PopScope home_screen 부재 — 입력 도중 탭 전환 시 데이터 손실 | [home_screen.dart](lib/views/home/home_screen.dart) PopScope 없음 | hasInput 시 confirm dialog |

### 접근성 (a11y)

| # | 결함 | 증거 | 액션 |
|---|------|------|------|
| 15 | StarRating Semantics 부재 — 스크린리더 사용 불가 | [star_rating.dart](lib/views/log/widgets/star_rating.dart) — `Semantics`, `semanticLabel`, keyboard 모두 없음 | Semantics wrap + 키보드 화살표 지원 |
| 16 | Dynamic Type 대응 코드 전무 — 시스템 폰트 크기 증가 시 레이아웃 깨짐 | grep `textScaleFactor`/`MediaQuery.textScalerOf` 결과 0건 | golden 테스트에 textScaler 1.5/2.0 variation 추가 |
| 17 | Pie chart 다크 모드 대비 위험 — title `Colors.white` 고정 | [stats_screen.dart:234](lib/views/stats/stats_screen.dart#L234) | brightness 별 동적 색 |

### UX 명시성

| # | 결함 | 증거 | 액션 |
|---|------|------|------|
| 18 | Delete entry confirmation 없음 — 우연 클릭 시 데이터 손실 | [entry_card_widget.dart:98-102](lib/views/draft_review/widgets/entry_card_widget.dart#L98) `onPressed: widget.onDelete` direct | showDialog 확인 |
| 19 | Cancel during generation 확인 없음 | [input_section_widget.dart:120-128](lib/views/home/widgets/input_section_widget.dart) | 확인 dialog 또는 swipe-to-cancel |
| 20 | SizedBox.shrink silent fallback — 최근 주류 로딩/에러 시 무반응 | [home_screen.dart:133-134](lib/views/home/home_screen.dart#L133) | shimmer 또는 짧은 placeholder |
| 21 | Empty draft (parse 0 entries) → 빈 카드만 표시 | parse_orchestrator + draft_review_screen | "인식 실패" 명시 + retry CTA |
| 22 | Low-confidence banner 액션 없음 — 사용자가 무엇을 할지 모름 | [draft_review_screen.dart:89-108](lib/views/draft_review/draft_review_screen.dart) | "재시도" / "수동 입력" 버튼 |

---

## 🛠️ MEDIUM — 개선 권장 (35건, severity 그룹별)

### 다크 모드 (4건)
- inputDecorationTheme.fillColor 누락 (dark) → 입력 필드 invisible 위험
- cardTheme.color 누락 (dark)
- `Colors.orange.shade300` 등 hardcoded 컬러는 dark 에서 대비 위험
- 다크모드 chart `_pieColors` 미검증

### Microcopy / 톤 (8건)
- "저장" vs "기록" CTA inconsistency (3+ 화면)
- 평어 vs 존댓말 혼재 ("마셨어" vs "마셨는지")
- Empty state copy 3 화면 동일 (DRY 위반)
- "AI 없이도 동작해요" / "로컬 파서" 사용자에게 모호
- "신뢰도 85%" 의미 unexplained
- AI source label jargon ("사용자 키" vs "기본 키")
- "메모" vs "테이스팅 노트" 혼동
- 에러 메시지 generic ("실패", "오류", 기술 노출)

### IA / Flow (6건)
- More 탭 flat list — 향후 메뉴 증가 시 정리 안 됨
- 신규 저장 후 홈으로 돌아가 "저장됐나?" 모호
- 편집 진입 경로 단일 (LogDetail 앱바 icon)
- 삭제 후 undo 없음
- Search 스크롤 위치 복원 없음
- Search empty state 부재

### 입력 / 폼 (5건)
- Placeholder `_placeholders.first` 고정 (랜덤화 X)
- Image picker 권한 거부 generic error
- Image preparation 단계 cancellation 없음
- 이미지 단일 첨부만 (다중 X)
- 단위 ml 환산 표시 없음 (1샷=45ml, 1병=750ml)

### 설정 / AI (5건)
- API key validation 로딩 indicator 없음
- API key 삭제 confirmation 없음
- Quota reset time 미표시
- AI 동의 UX 가 설정 화면 깊숙이 (온보딩 시점에 부재)
- AI fail banner 에서 실패 사유 미세분 (quota / network / 401)

### Stats / 시각화 (4건)
- Period filter "이 기간 빈 데이터" empty state 처리 안 됨
- Line chart Y축 단위 ("회") 미표시
- Line chart tooltip 없음
- Achievement progress bar 부재 ("6/10 까지 X개")
- Stats card trend 표시 없음 ("+30%")

### Domain / 사전 활용 (3건)
- food_dictionary.json 36종 자동 추천 미활용
- place_keywords.json 장소 추천 미활용
- place 즐겨찾기 모델 없음

---

## ✨ LOW — Polish (24건 요약)

- Skeleton 미사용 (모두 spinner)
- Cards 비활성처럼 보이는 affordance (recent logs 카드)
- Save Snackbar 가 navigation pop 으로 가려짐
- Cross-screen action 위치 불일관 (edit/delete)
- FAB 없음 → primary action visibility 부족
- 카테고리 map triplicate (label_utils + entry_card + archive)
- 단위 라벨 "unknown" 불일치 (`''` vs `'모름'`)
- date format 불일치 (`y년 M월` vs `M월 d일 (E)` vs `M/d`)
- Cupertino adaptive UI 미사용 (iOS 사용자 어색)
- HapticFeedback 미사용
- SliverAppBar / Large Title 미사용
- Loading 시 캐릭터/일러스트 없음
- App icon Android OK, iOS PNG 존재 — splash brand 미반영
- App 이름 일관성 (Albi vs albi)
- iOS LaunchScreen Flutter default
- Liquor master 직접 picker 없음 (매칭 실패 시 수동 입력만)
- Food chip duplicate silent reject
- Image size/format metadata 미표시
- RecentLogs 가로 스크롤 indicator 없음
- Source badge confidence tooltip 없음
- Search debounce 없음 (검색 중 flicker)
- Search 정렬 옵션 없음 (날짜순 고정)
- Search 결과 정렬 / 부분 일치
- Multi-page onboarding 골든 1장만 (page 1)
- Stats 기간 filter 전역 stale state
- AI Settings API key 미저장 뒤로가기 silent loss
- Timezone 비고려 ISO (해외 여행 시)

---

## 🎯 추가 권장 기능 (음주 도메인 차별화)

Codex 가 외부 벤치마크 (Untappd, Vivino, Day One, Toss, 배민) 대비 발견한 추가 후보:

| # | 기능 | 근거 |
|---|------|------|
| 1 | **표준잔 / 순알코올량 시각화** — `alcoholPercent × quantityValue` 계산 후 권장 일일 한도 비교 바 차트 | 음주 기록 앱의 핵심 가치 — 단순 횟수 → 양 정량 |
| 2 | **주간 음주 패턴 경고** — "이번 주 5일 음주, 간 휴식 권장" 인라인 건강 신호 | 기획서 § 21 "건강 체크" 언급되었으나 미구현 |
| 3 | **회고 / 트렌드** — "올해 가장 자주 마신 술 TOP 3", 월별 별점 변화 그래프 | stats_viewmodel 의 monthlyTrend 활용 확장 |
| 4 | **라벨 사진 갤러리** — 술 이름 / ABV / 가격 / 테이스팅 노트 연결 사진 모음 | image_picker 이미 사용 |
| 5 | **음주 기록 export / share** — 월간 요약 이미지 또는 CSV 내보내기 (데이터 손실 방어 겸용) | share_plus / csv 패키지 미사용 |
| 6 | **카메라 직접 촬영** — 갤러리 픽만 지원, Vivino-style 라벨 스캔 패턴 부재 | `ImageSource.camera` 추가 1줄 |
| 7 | **저장 전 별점 / 테이스팅 노트** — 현재는 저장 후 LogDetail 에서만 가능, 검토 화면에 추가 | 사용자 캡처 누락 방지 |
| 8 | **장소 즐겨찾기 + 자동 추천** — place_keywords 활용 |
| 9 | **음식 페어링 + 카테고리화** — food_dictionary 활용 |
| 10 | **알림 / 리마인더 / 스트릭** — flutter_local_notifications 미설치 |

---

## 📊 Coverage Saturation 평가

Codex Agent 9 의 명시적 saturation 평가:

> Round 1~2에서 구조/토큰/권한/접근성/카피 영역이 포화 상태에 도달했고, Round 3에서는 race condition, state persistence, date/time, seed-data 미활용, release prep 등 실제로 새로운 영역에서 의미 있는 결함이 확인되었다. 그러나 finding 당 severity는 Round 1~2보다 전반적으로 낮아지는 추세다.
>
> **Round 4 권장 여부: 비권장.** 위 16건의 confirmed finding을 fix backlog으로 전환하는 것이 추가 라운드 투입보다 효율적이다. 남은 탐색 여지(동행자 태그, 지도 통합, 계정 동기화)는 기능 부재 영역으로 버그가 아닌 신규 기능 범주에 해당한다.

**미탐색 0 조건 충족** (Round 1~3) → 텍스트/구조 측면 평가 종료.

---

## 🎨 Round 4 — Pinterest Reference 시각 비교 (사용자 추가 요청)

> **방법**: Playwright MCP 로 <https://pin.it/6ecekV6R7> (송지나 프로필 redirect) 접근 → "대시보드" (42 핀, app/web UI) + "시각디자인" (1149 핀, editorial typography) 두 보드 viewport 캡처. Albi golden 7장과 직접 시각 대조. Claude Explore + Codex codex-rescue 병렬 평가.
>
> **자료**:
> - `pinterest-dashboard-board.png` — 송지나 대시보드 보드 (modern multi-color, gradient, elevated card, chart-heavy)
> - `pinterest-visual-design-board.png` — 송지나 시각디자인 보드 (bold Korean typography, editorial poster)
> - Albi golden 7장 (`test/golden/goldens/*.png`)

### Reference design language (정량 비교)

| 차원 | Reference (대시보드 보드) | Albi 현재 | Gap |
|---|---|---|---|
| Color palette | 5-8 distinct accent (coral / sky blue / emerald / purple / yellow) + gradient | 단일 whisky brown + beige + 작은 orange/red | Large |
| Typography depth | 4-5 단 (display / heading / subhead / body / caption) | 2-3 단 실제 사용 | Large |
| Card elevation | 12-16px blur shadow, 15-25% alpha | elevation 0, border-only | Large |
| Information density | 60-70% content, 30-40% whitespace, multi-widget 1 화면 | home 30% / more 25% — 빈 영역 과다 | Extreme |
| Data viz | KPI 카드 + gauge + bar + line, multi-chart per screen | pie 1 + stat card 4 (visible golden 에는 없음) | Large |
| Iconography | custom icon set + illustration | Material Icons + placeholder box | Moderate |
| Motion / Delight | hover/active/depth 암시 visual cue | 정적 flat | Moderate |

Reference 패턴 라벨 (Codex 분석): SaaS analytics dashboard / glassmorphism-lite card stack / bento high-data-ink / neo-SaaS purple / soft neumorphic. 시각디자인 보드는 experimental K-typography / retro poster editorial / isometric infographic.

### Top 10 Visual Gap (Round 4 신규 finding)

| # | Gap | Severity | 증거 (image:coord) | 권장 action |
|---|------|---|---|---|
| V1 | 홈 첫 화면 시각 중심이 입력이 아닌 "통계 오류"로 떨어짐 | **HIGH** | `home_empty.png` `(575~880, y=1300)` "통계를 불러오지 못했습니다" + 붉은 사각 아이콘 | 홈 빈 상태에서 stats 오류 접거나 보조로 강등, 입력 카드를 first-fold 차지 |
| V2 | 최근 기록 카드가 화면 좌측에만 몰림, 우측 60% 비어있음 | **HIGH** | `home_with_logs.png` 카드 2개 `(x=35~610)`, `(x=620~1400)` 거의 비어있음 | 가로 스크롤 / full-width / 3+ 미리보기로 정보 밀도 ↑ |
| V3 | "장소" 라벨이 입력 카드 경계선 위에 걸쳐있음 (정렬 결함) | **HIGH** | `draft_review_ai.png` `(x=65, y=595)` | 라벨을 section header 로 분리 또는 floating label 명확화 |
| V4 | 항목 카드 내 좌우 정보가 분산되어 한 항목으로 안 읽힘 | **HIGH** | `draft_review_ai.png` 좌측 `(95~220)` 위스키/양/단위 vs 우측 `(1160~1290)` 연산/15년/43.0 — 시각적 분리 | compact summary row + detail grid 재구성 |
| V5 | 도수 정보 "도…" truncation | MEDIUM | `draft_review_ai.png` `(x=1290, y=1580)` | 라벨 폭 확보 또는 icon+값 구조 |
| V6 | 낮은 신뢰도 경고가 상단 빨강 + 카드 내 주황 두 곳 분산 — 우선순위 혼란 | **HIGH** | `draft_review_low_confidence.png` 상단 `(y=380~500)` 빨강 / 카드 내 `(y=1450, y=1945)` 주황 | 상단 요약 배너 1개 + 필드별 인라인 경고 통일 |
| V7 | 직접 입력 카드가 너무 넓고 비어있음 — manual 전용 compact form 없음 | **HIGH** | `draft_review_manual.png` 항목 카드 `(x=35~1400, y=970~1810)` 대부분 빈 공간 | manual 전용 compact form + 빈 속성 "추가 정보" 접힘 |
| V8 | 온보딩의 입력 예시 + 결과 카드가 동일 형태 — 변환 서사 약함 | MEDIUM | `onboarding_page1.png` 입력 `(y=900~1090)` / 결과 `(y=1210~1400)` 둘 다 긴 rounded rectangle | 입력은 말풍선/텍스트필드, 결과는 drink summary card 로 시각 차별화 |
| V9 | More 화면 상단 25% 콘텐츠, 하단 75% 완전 빈 배경 | **HIGH** | `more_screen.png` 메뉴 `(y=260~800)` 끝, `(y=820~2500)` 빈 영역 | 계정 / AI / 데이터 관리 / 앱 정보 / 라이선스 섹션 추가 |
| V10 | More 우측 chevron icon 이 텍스트와 너무 멀어 행 일부가 아니라 떠 있는 표식처럼 | MEDIUM | `more_screen.png` `(x=1300, y=260/500/740)` | chevron 을 텍스트 가까이 또는 ListTile trailing 표준 위치 |

### 음주 도메인 visual benchmark 5건 (외부 앱 → Albi 적용)

| 앱 | 시각 패턴 | Albi 적용안 |
|---|---|---|
| **Vivino** | bottle-first commerce: 라벨 사진 + 평점 + 페어링 | 술 이름 카드에 병/라벨 썸네일 슬롯 + tasting summary |
| **Untappd** | social log: check-in + 장소 + 사진 + badge 결합 | 저장 후 "오늘의 기록 카드" 에 장소·사진·작은 성취 chip |
| **Distiller** | tasting note + flavor profile 중심 spirit page | 위스키/스피릿 기록에 향·맛·피니시 tag cloud 시각화 |
| **DrinkControl** | calendar + trend-line + alcohol units health dashboard | 홈에 월 캘린더 heatmap + 표준잔 추세 preview 상단 prominence |
| **BoozeBuddy** | 빠른 로깅 + 즐겨찾기 quick chip | 홈 입력 아래 "자주 마신 조합" quick chip |

### "위스키 Brown 모노톤" 유지 vs 변경 — 권장 판단

| 선택 | Identity | Trend 적합 | 리스크 |
|---|---|---|---|
| 완전 유지 | 높음 | 낮음 | 화면 간 구분 약함 |
| 완전 변경 | 낮음 | 높음 | 앱 정체성 상실 |
| **Brown anchor + 보조 팔레트 확장 ✅ 권장** | 높음 | 중간~높음 | 관리 비용 소폭 증가 |

**최종 권장 팔레트** (도메인 contextual):
- Whisky brown `#8B5E3C` — primary anchor (브랜드)
- Amber gold `#D4A574` — liquor highlight (기록 강조)
- Deep burgundy `#6B2C3E` — wine accent
- Sage green `#7FA39D` — non-alcoholic / 휴식 권장
- Warm orange `#E8A87C` — beer/soju accent
- Teal `#5D8A8C` — 통계 / 분석
- 기존 red/orange → semantic error/warning 로 분리

화면 역할별 색 매핑: 기록 = amber, 검토 경고 = orange/red, 통계 = teal, 아카이브 = green/purple, 검토 성공 = sage.

### Pinterest 모방 risk 3건

1. **Dashboard 과밀화 risk** — KPI/chart 무분별 추가는 빠른 로깅 (Albi 핵심 가치) 저해. 홈은 입력 우선, 통계는 preview 수준으로 제한.
2. **Editorial poster 과잉 risk** — 큰 한글 타이포를 form 화면에 적용하면 가독성 저하. **onboarding / 빈 상태 / 월간 리포트에만** editorial treatment 적용.
3. **Gradient trend drift risk** — purple/blue SaaS gradient 그대로 사용 시 위스키 도메인과 충돌. **amber / copper / moss / teal** 같은 술/바 연관 색으로 변환.

### Albi 의 시각 강점 (보존)

1. **Whisky brown seed** — 도메인 특화, warm, sophisticated. 유지 + 팔레트 확장.
2. **NotoSansKR** — 한글 앱 최적, clean & modern. 유지.
3. **12px base radius** — soft modern, M3 aligned. 유지.
4. **48px+ 버튼 tap target** — 모바일 표준 충족. 유지.
5. **AI/직접 입력 2-button 명확 분기** — 직관적. 유지.
6. **draft_review_ai 의 정보 hierarchy 자체** — 과밀하지 않은 스캔 가능. 유지하되 좌우 분산만 정리.

### Codex Visual Differential (3 Claude agent 가 놓칠 가능성)

1. `draft_review_ai.png` `(x=65, y=595)` "장소" 라벨-카드 경계 충돌 — 코드 grep 불가, 시각 only.
2. `home_with_logs.png` `(x=620~1400, y=390~690)` 빈 영역 체감 — 레이아웃 수치보다 정보 밀도 저하가 큼.
3. `draft_review_low_confidence.png` 경고 색 + 위치 분산 — 실 화면에서만 우선순위 혼란 드러남.
4. `onboarding_page1.png` 두 예시 카드가 같은 형태 — 변환 서사 약화 (단순 코드로 불검출).
5. `more_screen.png` 우측 chevron 의 떠있는 표식 같은 위치감 — ListTile 표준 trailing 위치와 어긋남.

---

## 권장 우선순위 백로그 (실행 가능 단위)

### 즉시 (출시 차단 해소 — 4개)
1. Android `INTERNET` 권한 추가 + iOS `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` 추가
2. Android release keystore 생성 + `key.properties` + gradle release signing
3. `parseJob` 개인정보 삭제 정책 (resetAllRecords + retention 정책)
4. Global crash handler (Sentry 또는 zone guard 최소)

### 우선 (HIGH UX defect — 1~2주 sprint)
5. AI 동의 + 401 auto-recovery + quota 진행 바
6. quantity/ABV validation + 0-entry 저장 차단 + 미래 날짜 차단
7. Delete confirmation 통일 (entry / draft / log)
8. PopScope 통일 (home + ai_settings + tasting_note_edit)
9. DB save error retry + AppError.userMessage 적용
10. StarRating Semantics + Dynamic Type 대응 + 다크모드 chart 색

### 다음 (MEDIUM — sprint 2)
11. Microcopy 톤 통일 + CTA / Empty state copy 정리
12. 카테고리 map 중앙화 + 단위 라벨 통일
13. Stats period empty state + tooltip + trend indicator
14. Skeleton 도입 + Hero animation (log list → detail)
15. food/place 자동 추천 + 단위 ml 환산

### 차별화 신규 (별도 plan)
- 표준잔 / 순알코올 시각화
- 회고 / 트렌드 / 라벨 사진 갤러리
- export / share / 알림 / 리마인더

---

## 종합 평가

**강점**:
- MVVM + Riverpod 구조 견고, View→ViewModel→Repository 규율 준수
- Local fallback (LocalRuleParser) 견고 — AI 없이도 전 기능 사용 가능
- 553 종 시드 데이터 + 한국어 라벨 70% — 도메인 데이터 풍부
- sealed AppError 계층 + 5 Repository write 경계 try-catch 정상
- 11 screen 활성, dead code 없음

**약점**:
- 출시 차단 결함 4건 (manifest 권한 / signing / 개인정보)
- a11y 거의 미대응 (Semantics / Dynamic Type / contrast)
- 사용자 통제권 부족 (delete confirmation / undo / retry 미흡)
- 디자인 토큰 정의는 있으나 화면에서 hardcoded 다수 (다크모드 대비 위험)
- 음주 도메인 차별화 기능 부재 (표준잔, 건강 신호, 회고)
- Korean UX 표준 (Toss/배민 패턴) 일부만 적용

**현재 상태**: **개발 후기 단계 — 출시 직전 production-hardening 필요**.
기능 완성도는 높으나 platform manifest / signing / privacy / a11y 의 production gating 4건 fix 가 우선.

---

## 🌀 Round 5 + 6 — 사용자 추가 요청 (ultraplan + 양방향 cross-feedback)

> **사용자 요청**: "추가라운드 진행 md로 남기면서 진행, ultraplan 생성, codex와 상이 및 서로 피드백 하면서 진행, 모두 탐색할 때까지 goal".
>
> **ultraplan**: `docs/analyze/2026-05-18-ultraplan-rounds-5plus.md`
> **progress-log**: `docs/analyze/2026-05-18-progress-log.md`
> **Round 5 Stage 1**: `docs/analyze/2026-05-18-round5-stage1.md`
> **Round 5 Stage 2+3 cross-feedback**: `docs/analyze/2026-05-18-round5-stage2-3.md`
> **Round 6 (3 agent + cross-feedback)**: `docs/analyze/2026-05-18-round6.md`

### Round 5 (Stage 1~4) — ~25 신규 + 양방향 cross-feedback

- **Stage 1 fan-out** (3 agent): Pinterest 5보드 (불렛저널/일러스트/인포/발표자료/제안서) + WCAG 정량 + 시나리오/cluster
- **Stage 2 (Codex → Claude)**: A 4건 INVALID/EXAGGERATED, B WCAG 수치 일부 정정 (Dark badge 6.09:1 PASS), CX7 + CX9 + CX11 추가 nominate
- **Stage 3 (Claude → Codex)**: 시나리오 4 "검색 미구현" FALSE POSITIVE 정정 (39/60 → 25/60), C5 ROI 1위 → C1 으로 재정렬, retention/persona/social 추가 nominate
- **신규 finding 통합**: R5-1~R5-15 + CX1-CX5 cross-cutting + Codex CX7/9/11

### Round 6 — ~40 신규 (가장 많은 라운드)

- **Agent X (Claude TalkBack)**: LogList long-press 삭제 CRITICAL / announce 부재 HIGH / Chip 32dp / Chart SR / Month header semantic 등 10건
- **Agent Y (Claude Post-drinking + 30일 retention + persona)**: 23건 (Critical 7 / High 9 / Medium 7) — P1 IconButton 18px / P2 Day 1 reward / Y retention 5 gap / Y persona 5 분기 등
- **Agent Z (Codex WCAG 정밀 + Recovery)**: Material 3 derived HCT 한눈표 + Agent B 12건 정정 (2건 PASS 정정) + 신규 5건 (light source badge 4종 + archive 빈상태 grey) + 6 recovery 시나리오 결손

### Codex Z 명시 saturation 평가

> "Round 7 일반 deep audit 비효율. 좁은 3 범위만 권장 — 또는 직접 /plan + /commit 으로 처리."
>
> 좁은 3 범위:
> 1. source badge 4종 light mode 텍스트색 patch (#0055CC / #006855 / #5C3400 / #767676)
> 2. stats pie chart 5종 white → 검정 + dark adaptive
> 3. recovery UX patch (OrchestrateResult.fallbackReason enum + permission_handler + DB retry)

---

## 🎯 누적 통합 (4 라운드 정리 — Round 4 ~ Round 6)

### Round 별 신규 finding 추이

| Round | 신규 | 누적 unique | 평가 |
|---|---|---|---|
| 1 | ~30 | 30 | 기초 발굴 |
| 2 | ~25 | 55 | 중간 확장 |
| 3 | ~20 | 75 | Codex saturation 1차 신호 |
| 4 | ~15 visual | 90 | Pinterest 시각 비교 |
| 5 (Stage 1~4) | ~25 + ~10 cross | 125 | 양방향 cross-feedback |
| 6 | ~40 | **~165 unique** | 정밀화 (마지막 라운드) |

### Round 6 의 정밀화 효과

- Agent B (Round 5) WCAG 12건 중 2건 PASS 로 정정 (Dark source badge orange/grey)
- Agent Y "Dark contrast 위험" 추정 — Z 가 Material derived 실측 PASS 로 정정
- Light mode hard-coded source badge 4종이 진짜 risk (블렌드 후 1.92-3.09:1) — Round 5 가 못 본 영역

### 종결 결정

| 옵션 | 평가 |
|---|---|
| A. Round 7 좁은 3 범위 | **implementation 작업이지 audit 아님** — 직접 /plan + /commit 권장 |
| B. Saturation 종결 | **권장** — ~165 finding 으로 책무 다함 |
| C. Round 7 product strategy (BAC / notification / multi-user / i18n) | decision 영역이지 audit ROI 낮음 |

**최종 판단**: **Option B (saturation 종결) + Option A 의 implementation 패치 전환**.

### CRITICAL 추가 (Round 6 발견 — 출시 차단 후보)

기존 CRITICAL 4건 (Android INTERNET / iOS Photo / Android release keystore / parseJob 원문) 외에 Round 6 에서 다음 추가:

- **X1 / P1 통합**: destructive action tap target — LogList long-press 전용 삭제 + entry card 18px IconButton (음주 후 시나리오 critical)
- **P2**: Day 1 첫 저장 reward 부재 (Day 1 이탈 40% 위험)
- **Light source badge 4종 WCAG FAIL** (Z N1-N4): 일반 a11y 가 아닌 production 출시 후 즉시 사용자 마주침

### 권장 implementation phase

1. **Phase 0 (출시 차단 4 + Round 6 추가 3 CRITICAL)** — 8건 CRITICAL fix
2. **Phase 1 (HIGH 28건 + Round 5/6 HIGH)** — 60+ HIGH
3. **Phase 2 (MEDIUM/LOW 통합)** — 95+ remaining
4. **Phase 3 (Domain 차별화)** — BAC / notification / multi-user (별도 plan)
5. **Phase 4 (Visual identity 리브랜딩)** — Pinterest reference 의 6색 도메인 팔레트 + illustration 자산 (별도 plan)

---

## 종결 시그너처

총 **6 라운드 / 14 agent** (Claude 9 + Codex 5).
- Round 1~3: 텍스트/구조 평가 (사용자 명시 요청, Codex saturation 1차 도달)
- Round 4: Pinterest 대시보드 + 시각디자인 시각 비교 (사용자 추가 요청)
- Round 5: Pinterest 5 보드 추가 + WCAG + 시나리오 + cluster + 양방향 cross-feedback (ultraplan)
- Round 6: TalkBack + post-drinking + retention + persona + WCAG 정밀 + recovery (Round 5 양방향 nominate 영역)

누적 ~165 unique finding. Codex 2 차 saturation 평가 (Round 6 Z): "Round 7 일반 deep audit 비효율" → 평가 종결, **implementation phase 전환 권장**.

미탐색 영역 잔여 (product strategy 결정 영역, audit 외):
- BAC / 표준잔 계산 수학 (Round 5/6 nominate 됨)
- flutter_local_notifications 통합 (Round 2 nominate)
- Multi-user / co-drinking session UX (Round 5 nominate)
- i18n 영문 진입 UX (Round 5 nominate)

위 4 영역은 product/business decision 필요 — audit 가 아니라 사용자 결정 영역.

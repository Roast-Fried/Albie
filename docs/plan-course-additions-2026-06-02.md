# ULTRA PLAN — 강의 자료 기반 albi 기능 추가

> 근거: [docs/analyze/2026-06-02-course-materials-analysis.md](analyze/2026-06-02-course-materials-analysis.md) (강의 47파일 전수 + Codex 미탐색 0건 검토)
> 목표: 모바일프로그래밍 과목 채점(기능충실성 + **예외처리** + **UI/UX 완성도·실용성**) 최대화. 강의가 가르치고 고득점 예시가 보여준 기법을 albi 에 반영.
> 원칙: 기존 sqflite/Riverpod/MVVM **유지**(Drift 마이그레이션 X). credential 기능은 `.env` 비면 dormant(기존 로컬 동작 100% 유지), 채우면 활성.

## 0. 구현 대상 (Codex 합의 최종 세트)

| # | 기능 | 난이도 | .env | 채점 기여 |
|---|------|:---:|:---:|------|
| 1 | **AppConfig + `.env` 인프라** (flutter_dotenv + String.fromEnvironment) | S | — | 기반 |
| 2 | **애니메이션** (AnimatedList 기록 추가/삭제, Hero 리스트→상세, 암시적) | S~M | — | UI/UX 완성도 |
| 3 | **음주 캘린더** (table_calendar 월별 시각화) | M | — | 실용성·고득점 예시 |
| 4 | **Named Routes + onGenerateRoute** | M | — | 강의 정합·구조 |
| 5 | **Supabase opt-in 백업/복원 + 이메일 인증** (dormant) | L | ✅ | 실용성·예외처리·고득점 예시 |
| 6 | (fold) **Sync status StreamBuilder** — 5 의 동기화 상태 표시 | S | — | 강의 키워드(StreamBuilder) |

**제외**: Drift 전면전환 · 온디바이스 Gemma · Supabase 실시간/소셜 (Codex bloat 판정).

## 1. 구현 순서 (의존성 기반, 각 step = 1 논리 커밋 + flutter analyze 통과)

```
Step 1  AppConfig + .env 인프라        ← 기반 (Gemini/Supabase 공통)
Step 2  애니메이션                      ← 순수 additive, 저위험, 고체감
Step 3  음주 캘린더                      ← 신규 화면 + more_screen 진입
Step 4  Named Routes + onGenerateRoute  ← 기존 push 9곳 + 신규 화면 등록
Step 5  Supabase 백업/복원 + 인증        ← 최대 규모, 신규 integration/data/UI + SQL
Step 6  Sync status StreamBuilder       ← Step5 UI 에 fold
Phase5  전체 리뷰(Codex 페어) → 수정 → 0건
```

---

## Step 1 — AppConfig + `.env` 인프라

**목표**: `.env` 파일(또는 `--dart-define`)로 credential 주입. 비면 dormant.

**신규**:
- `lib/core/app_config.dart`
  ```dart
  class AppConfig {
    // dotenv(런타임 .env) 우선, 없으면 --dart-define(빌드타임) fallback, 둘 다 없으면 ''
    static String get supabaseUrl => _read('SUPABASE_URL');
    static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');
    static String get geminiApiKey => _read('GEMINI_API_KEY');
    static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
    static bool get hasGeminiBuildKey => geminiApiKey.isNotEmpty;
    static String _read(String k) {
      final v = dotenv.maybeGet(k); // flutter_dotenv (asset 없으면 throw 안 하게 isInitialized 가드)
      if (v != null && v.isNotEmpty) return v;
      return _fromDefine(k); // const lookup table → String.fromEnvironment
    }
  }
  ```
- `.env.example` (저장소 커밋 — 템플릿)
  ```
  # 사용자가 값만 채우고 .env 로 복사 후 재빌드하면 활성화됩니다.
  SUPABASE_URL=
  SUPABASE_ANON_KEY=
  GEMINI_API_KEY=
  ```
- `.env` (gitignore 추가, 빈 파일로 생성 — flutter_dotenv asset 로드용)

**수정**:
- `pubspec.yaml`: `flutter_dotenv: ^5.1.0` 의존성 + `assets: - .env`
- `.gitignore`: `.env` 추가
- `lib/main.dart`: `runApp` 전 `await dotenv.load(fileName: '.env')` (try/catch — 파일 없거나 비어도 진행). `WidgetsFlutterBinding.ensureInitialized()` 이미 있음.
- `lib/core/providers.dart`: `appConfigProvider`(단순 Provider). Gemini: `keyMode`/secure-storage 흐름 유지하되, 인앱 키 없을 때 `AppConfig.geminiApiKey` fallback (parse_orchestrator 의 keyMode 분기에 build-key 옵션 1개 추가 — 기존 user_provided 우선).

**예외처리**: `.env` asset 부재/빈값 → `hasSupabase=false`, `hasGeminiBuildKey=false`. 앱은 기존대로 동작(로컬 파서 + 인앱 Gemini 키).

**검증**: `flutter analyze` 0 issues. `.env` 비어있는 상태에서 앱 빌드/기존 테스트 통과(dormant 경로).

**테스트**: `test/core/app_config_test.dart` — dotenv 미초기화 시 빈 문자열 반환, hasSupabase=false.

---

## Step 2 — 애니메이션

**목표**: 강의 위젯 lifecycle/애니메이션 + 고득점 예시 "리스트 애니메이션". UI/UX 완성도 체감↑.

### 2a. Hero (리스트 → 상세 공유 요소)
- `log_list_screen.dart` `_LogTile`: 날짜/요약 텍스트를 `Hero(tag: 'log-${log.id}', child: Material(type: transparency, ...))` 로 래핑.
- `log_detail_screen.dart` `_DetailBody`: 동일 tag Hero 로 날짜 텍스트 래핑. (tag 충돌 방지: log.id 기반)
- 주의: Hero child 의 text style 전환 시 Material 래핑 필요(글꼴 깨짐 방지).

### 2b. 기록 리스트 등장 애니메이션
- `log_list_screen.dart`: `ListView.separated` itemBuilder 의 타일을 `TweenAnimationBuilder<double>`(opacity+slide, index 기반 stagger delay)로 래핑 — 진입 시 부드러운 fade-in-up. (AnimatedList 는 add/remove diff 관리 복잡 → 진입 애니는 TweenAnimationBuilder 가 저위험. 삭제는 기존 즉시 갱신 유지하되 선택적으로 AnimatedSize.)
- 대안 평가: 완전한 AnimatedList(add/remove 애니)는 Riverpod 리스트 재빌드와 key 관리 충돌 위험 → 진입 애니(TweenAnimationBuilder) + 삭제 시 `AnimatedSwitcher`/즉시갱신으로 한정. Codex 리뷰에서 재검토.

### 2c. 암시적 애니메이션
- 탭 전환/통계: `AnimatedSwitcher` 또는 `AnimatedContainer` 로 값 변경 부드럽게. (stats_screen 차트 기간 전환 시 fade.)
- 빈 상태 ↔ 데이터: `AnimatedSwitcher`.

**예외처리**: 애니메이션은 순수 시각 — 데이터 로직 무변경. reduce-motion 접근성: `MediaQuery.disableAnimations` 체크해 duration 0 분기(선택).

**검증**: `flutter analyze`. golden/integration capture 재실행해 레이아웃 회귀 없음. 기존 26 PNG capture 와 비교.

---

## Step 3 — 음주 캘린더

**목표**: 월별 음주일 시각화(고득점 예시 ⑤, 실생활 유용 — "이번 달 며칠 마셨나").

**신규**:
- `pubspec.yaml`: `table_calendar: ^3.1.2`
- `lib/viewmodels/calendar_viewmodel.dart`: `calendarMonthProvider`(FutureProvider.family<Map<DateTime,DayStat>, DateTime month>) — 해당 월 음주 기록을 일자별 집계(건수/표준잔). Repository 에 `getByDateRange(start,end)` 추가(없으면).
- `lib/views/calendar/calendar_screen.dart`: `TableCalendar` + 일자별 마커(음주량 색 농도) + 날짜 탭 시 해당일 기록 bottom sheet/리스트.
- DayStat: `{int logCount, double standardDrinks}` — `standard_drink_utils.dart` 재사용.

**수정**:
- `lib/data/drink_log_repository.dart`: `Future<List<DrinkLog>> getByDateRange(DateTime start, DateTime end)` (읽기 — raw 통과, try-catch 불필요 per 규칙6). drankAt BETWEEN 쿼리.
- `lib/views/settings/more_screen.dart`: ListTile '음주 캘린더'(Icons.calendar_month) 추가 → calendar_screen.

**예외처리**: 빈 월(기록 0) → 캘린더만 표시, 마커 없음. 미래 월 탐색 가능하나 마커 없음. DB 에러 → ErrorStateWidget.

**검증**: `flutter analyze`. integration capture 추가(calendar_capture_test). 빈 상태 + 데이터 상태.

**테스트**: `calendar_viewmodel` 집계 로직 단위 테스트(일자 그룹핑, 6시 컷오프 정합).

---

## Step 4 — Named Routes + onGenerateRoute

**목표**: EffectiveNavigator 베스트프랙티스. 현 `Navigator.push(MaterialPageRoute)` 9곳 → 경로 상수 + onGenerateRoute. 강의 정합 + 타입세이프.

**신규**:
- `lib/core/app_routes.dart`:
  ```dart
  class Routes {
    static const logDetail = '/log/detail';   // args: int logId
    static const archive = '/archive';
    static const archiveDetail = '/archive/detail'; // args
    static const stats = '/stats';
    static const settings = '/settings';
    static const aiSettings = '/settings/ai';
    static const notifications = '/settings/notifications';
    static const calendar = '/calendar';
    static const draftReview = '/draft-review'; // ProviderScope override 필요 → 특수 처리
    static const account = '/account'; // Step5
  }
  Route<dynamic>? onGenerateRoute(RouteSettings s) { switch(s.name) {...} } // args 타입검증 + 미스매치 시 에러 라우트
  ```
- `lib/views/common/route_error_screen.dart`: 잘못된 경로/인자 fallback.

**수정**:
- `lib/app.dart` MaterialApp: `onGenerateRoute: onGenerateRoute`. `home:` 유지(_AppEntry).
- 9곳 push 사이트: `Navigator.pushNamed(context, Routes.x, arguments: ...)` 로 교체. 단 **DraftReviewScreen 은 ProviderScope override 필요** → onGenerateRoute 에서 arguments 로 DraftReviewState 받아 override 구성(또는 해당 1곳은 기존 직접 push 유지 + 주석). IndexedStack 3탭은 라우트 아님(유지).
- 결과 반환 패턴: `_openDetail` 의 `.then(refresh)` 유지(pushNamed 도 Future 반환).

**예외처리**: onGenerateRoute 에서 arguments null/타입 불일치 → route_error_screen. (EffectiveNavigator 강조점)

**검증**: `flutter analyze`. 전 화면 네비게이션 integration test(app_test) 통과. 인자 전달 정상.

**주의(Scope Discipline)**: `<template>`/UI 무변경 — 네비게이션 메커니즘만. 화면 외형 동일.

---

## Step 5 — Supabase opt-in 백업/복원 + 이메일 인증 (dormant)

**목표**: 사용자가 `.env` 에 SUPABASE_URL/ANON_KEY 채우고 제공된 SQL 실행하면 → 이메일 가입/로그인 → 음주 기록 클라우드 백업/복원. **`.env` 비면 설정에 "미설정" 표시만, 기존 로컬 동작 100% 유지.** offline-first(로컬이 SoT, 클라우드는 백업).

**신규**:
- `pubspec.yaml`: `supabase_flutter: ^2.5.6`
- `lib/integrations/supabase/supabase_client_provider.dart`: `supabaseClientProvider` → `AppConfig.hasSupabase` 면 `Supabase.instance.client`, 아니면 `null`.
- `lib/integrations/supabase/supabase_auth_service.dart`: 이메일 signUp/signInWithPassword/signOut/currentUser. 에러 → `NetworkError`/`ValidationError` 매핑.
- `lib/integrations/supabase/supabase_sync_service.dart`:
  - `backup()`: 로컬 전체 DrinkLog(+entries/food/tastingNote) → Supabase upsert(user_id 스코프). 멱등(서버 row id = 로컬 uuid 또는 logId+userId).
  - `restore()`: Supabase pull → 로컬 DrinkLogRepository 재구성(중복 병합 전략: 서버 우선 또는 최신 updatedAt).
  - `pushOne(log)`/`deleteOne(id)`: 단건 동기화(저장/삭제 hook).
- `lib/data/sync_metadata_repository.dart`: `syncMeta` 테이블(lastSyncAt, pending queue) — 신규 DB 테이블 → `_dbVersion` 증가 + onUpgrade 마이그레이션(CREATE TABLE IF NOT EXISTS). **주의: Codex가 강조한 마이그레이션 안전성** — additive only, 기존 테이블 무변경.
- `lib/viewmodels/account_viewmodel.dart`: `accountProvider`(AsyncNotifier) — 인증 상태(로그인/로그아웃), 동기화 상태(idle/syncing/error/done), lastSyncAt. config 없으면 `unconfigured` 상태.
- `lib/views/settings/account_screen.dart`: 로그인 폼(이메일/비번) + "백업하기"/"복원하기" 버튼 + 마지막 동기화 시각 + 동기화 상태(StreamBuilder/AsyncValue). `.env` 미설정 시 안내 카드("클라우드 백업을 쓰려면 .env 설정 — docs 링크").
- `docs/supabase-schema.sql`: 사용자가 Supabase SQL editor 에 1회 실행할 테이블 DDL(drink_logs, drink_entries, ... + RLS policy user_id = auth.uid()).
- `docs/supabase-setup.md`: 설정 가이드(프로젝트 생성 → URL/anon key → .env → SQL 실행 → 재빌드).

**수정**:
- `lib/main.dart`: `AppConfig.hasSupabase` 면 `await Supabase.initialize(url, anonKey)` (dotenv.load 이후). 아니면 skip.
- `lib/views/settings/settings_screen.dart` "데이터" 섹션: ListTile '클라우드 백업·동기화'(Icons.cloud_outlined) → account_screen. (사용자가 이미 데이터 init/초기화 보는 위치 — 자연스러움)
- `lib/core/database/database_helper.dart`: `_dbVersion` 2→3, onUpgrade(oldVersion<3) syncMeta 테이블 생성.
- (선택) 저장/삭제 hook: `draft_review_viewmodel.saveToDb`/`drink_log_repository.delete` 후 로그인 상태면 `pushOne`/`deleteOne` enqueue. **단 offline-first — 로컬 성공이 우선, 동기화 실패는 배너만, 롤백 X.**

**예외처리(채점 핵심)**:
- `.env` 미설정 → unconfigured(기능 숨김/안내). 앱 정상.
- 로그인 실패(잘못된 비번) → ValidationError UI.
- 네트워크 실패(백업/복원/동기화) → NetworkError 배너, 로컬 데이터 무손상, 재시도 버튼.
- 복원 충돌 → 병합 전략 명시(서버 최신 우선) + 사용자 확인 다이얼로그.
- 토큰 만료 → 재로그인 유도.

**검증(정직 라벨 — Verification Discipline)**:
- `.env` 비움(기본): `flutter analyze` 0, 앱 빌드/기존 테스트 통과, dormant 경로 = 기존 동작 (이게 **실제 검증 가능 영역**).
- 라이브 Supabase 경로(가입/백업/복원): **사용자 .env + SQL 실행 후 검증 가능 → 현 세션은 `backend_unavailable`(credential 부재)로 SKIP 라벨**. 코드 구조/컴파일/dormant 분기만 검증. mock env var(USE_FAKE 등) 미사용.
- `account_viewmodel` 상태 전이 단위 테스트(unconfigured/loggedOut/loggedIn/syncing).

---

## Step 6 — Sync status StreamBuilder (fold into Step 5)

- account_screen 의 동기화 진행률/상태를 `StreamBuilder<SyncStatus>`(sync_service 가 emit 하는 Stream)로 표시 — 강의 StreamBuilder 키워드 충족 + 실제 UX.
- `supabase_sync_service` 에 `Stream<SyncStatus> get statusStream`(StreamController.broadcast). backup/restore 진행 시 emit.

---

## 2. 사용자가 나중에 할 일 (".env 만 넣으면")

본 구현 완료 후 사용자가 클라우드 기능을 켜려면:
1. `.env.example` → `.env` 복사, `SUPABASE_URL`/`SUPABASE_ANON_KEY` 채움 (Supabase 프로젝트 Settings→API). 선택: `GEMINI_API_KEY`.
2. Supabase SQL editor 에 `docs/supabase-schema.sql` 1회 실행(테이블 + RLS).
3. 앱 재빌드 → 설정 > 클라우드 백업·동기화 > 이메일 가입/로그인 > 백업/복원.

`.env` 안 채우면: AI(로컬 파서/인앱 Gemini 키) + 모든 로컬 기능 기존대로. 클라우드 메뉴는 "미설정" 안내만.

## 3. 리스크 & 가드

| 리스크 | 가드 |
|------|------|
| 패키지 추가로 Android 빌드 깨짐(desugaring 등) | 각 step `flutter analyze` + smoke. supabase_flutter 는 minSdk 영향 가능 → 확인 |
| Named Routes 리팩토링 회귀 | UI 무변경(메커니즘만), app_test 네비게이션 통과 |
| DB `_dbVersion` 증가 마이그레이션 | additive only(CREATE TABLE IF NOT EXISTS), 기존 테이블 무변경, 기존 설치 무손상 |
| Supabase 라이브 미검증 | dormant 경로만 검증, 라이브는 `backend_unavailable` SKIP 정직 라벨 |
| Hero/애니메이션 레이아웃 회귀 | golden/capture 재실행 비교 |
| Scope creep | 실시간/소셜 제외 확정. 백업/복원+인증 한정 |

## 4. 완료 기준 (Phase 5 진입 조건)
- 전 step `flutter analyze` 0 issues + 기존 46 유닛/위젯 테스트 통과
- 신규 테스트(app_config/calendar/account) 통과
- `.env` 비움 상태 = 기존 동작 회귀 0 (dormant 검증)
- Phase 5: Codex 페어 전체 리뷰 → 수정 → 재리뷰 0건

## 5. 구현 완료 결과 (as-built)

### Phase 4 — 5 step 전부 완료 (커밋)
| Step | 커밋 | 핵심 |
|------|------|------|
| 1 .env 인프라 | `d92801b` | AppConfig(dotenv+define), dormant 게이트 |
| 2 애니메이션 | `cc4e037` | AppearAnimation/fadeSlideRoute/AnimatedSwitcher |
| 3 캘린더 | `989a7d9` | table_calendar 월별 음주 시각화 |
| 4 Named Routes | `06debe3` | Routes+onGenerateRoute, 11 push 마이그레이션 |
| 5 Supabase 백업/복원 | `58dc255` | opt-in dormant, 스냅샷 백업+이메일 인증 |

### Phase 5 — Codex 페어 리뷰 루프 (수렴)
- **R1** (`ef2332d`): 9 finding(CRITICAL 1/HIGH 2/MEDIUM 4/LOW 2) 수정
- **R2** (`df85238`): R1 검증 11 통과 + 신규 3 finding(HIGH 1/MEDIUM 2) 수정
- **R3** (`08c35fc`): R2 검증 2 통과 + 잔여 1(복원 원자성) → 단일 트랜잭션 replace
- **R4**: 최종 수렴 확인 (0건 목표)
- 추이: 9 → 3 → 1 → 0 (수렴)

### Codex 리뷰로 확정된 주요 설계 (계획 대비 변경/강화)
- **스냅샷 백업** 채택(per-row sync 아님) — DB 마이그레이션 회피, offline-first.
- **복원 순서**: fetch → (확인) → wipe → apply — 네트워크 실패 시 로컬 무손상.
- **테이스팅 노트 포함** — LogBackup, 복원 시 새 entryId 재연결(id ASC 순서매칭).
- **FK 안전**: liquorMasterId 를 canonicalName 으로 재매칭(없으면 null).
- **Gemini 보안**: `.env` 에서 읽지 않음 → `--dart-define`/인앱 보안저장소만.
- **codec 방어**: version `!=` 검증 + payload 타입 체크 → ValidationError.
- **캘린더 stale**: 저장/삭제/초기화 invalidate 셋에 calendarLogsByDayProvider.

### 검증 상태 (정직 라벨)
- ✅ `flutter analyze` 0 issues (전 step)
- ✅ `flutter test --exclude-tags golden` 132 pass (app_config/calendar/route/codec/account
  dormant/restoreReplaceAll FFI 신규 포함)
- ✅ integration boot smoke (Windows) PASS — home→draft→save→loglist→more→archive E2E.
  dormant(.env 미설정) 구동 + Named Routes 네비게이션 + 저장 플로우 런타임 정상
- ⏭️ Supabase **라이브 네트워크 경로(auth/backup/restore)** = `backend_unavailable` SKIP
  — 사용자가 `.env`(SUPABASE_URL/ANON_KEY) + `docs/supabase-schema.sql` 실행 후 검증 가능.
  단, 복원의 로컬 DB 교체 로직(restoreReplaceAll)은 FFI 실 DB 단위 테스트로 검증됨.
- 📝 golden 7건 실패 = 환경적 pixel-diff(미변경 draft_review 화면 포함), CI 제외 항목 — 회귀 아님

### 사용자가 클라우드 기능 켜는 법 (".env 만 넣으면")
`docs/supabase-setup.md` 참조: ① `.env` 에 SUPABASE_URL/ANON_KEY ② `docs/supabase-schema.sql`
실행 ③ 재빌드 → 설정>클라우드 백업·동기화. 안 채우면 모든 로컬 기능 기존대로(dormant).

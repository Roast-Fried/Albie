# ULTRA PLAN — 강의 정합 보강 + 전체 비주얼 리디자인

> 생성: 2026-06-04 `/goal` · 전 과정 Codex 페어 · 강의 47파일 fan-out 분석 + Codex 독립 갭 분석 기반
> 상태 SoT: 본 문서 §6 진행 로그 (헤더/요약은 라운드-무관 서술)

## 0. 목적 / 범위

모바일프로그래밍 강의가 가르치는 기법 중 Albi 프로젝트에 누락·약한 항목을 보강하고, 사용자 명시 요구인 **전체 비주얼 리디자인 + 아이콘/자산 전부 생성**을 수행한다. 강의 루브릭(OT.txt): 기능 구현 충실성 · 앱 완성도/실용성 · 학습성찰 · 기획서 충실성 + 필기.

### 사용자 합의 (2026-06-04, AskUserQuestion)
- **Drift**: 격리 데모 + 문서화 (sqflite 유지, 앱 안정성 우선)
- **디자인**: 전체 화면 비주얼 리디자인 (새 디자인 시스템 + 런처/스플래시/아이콘셋/팔레트/일러스트 전부 생성·적용, 기능 보존)

### 스코프 가드
- ViewModel / Repository / 파서 / DB(sqflite) **동작 로직 보존** — 리디자인은 위젯 트리/테마/스타일만.
- Drift 데모는 **완전 격리** (별도 DB 파일, 기존 8테이블 sqflite 무간섭).
- CLAUDE.md "zero UI change" 통합 규칙의 예외: 본 디자인 작업은 사용자 명시 승인 영역.

---

## 1. 갭 → 워크스트림 매핑

| 갭 | 심각도 | 워크스트림 |
|----|--------|-----------|
| Drift ORM 미사용 | MAJOR | WS-A (격리 데모 + 문서) |
| Spec-Kit/SDD 산출물 부재 | MAJOR | WS-B |
| 학습성찰 보고서 부재 (rubric) | MAJOR | WS-C |
| FutureBuilder/StreamBuilder 직접 사용 약함 | MINOR | WS-A (데모가 watch()+StreamBuilder+FutureBuilder 시연) |
| OOP(abstract/interface/mixin)·Lifecycle hook | MINOR | WS-C (강의개념↔코드 매핑 문서) |
| Navigator/onGenerateRoute | NONE | 변경 없음 (이미 정합) |
| 디자인/아이콘 미생성 | 사용자 핵심 요구 | WS-E (E1~E6) |

---

## 2. 워크스트림 상세 (구현-ready)

### WS-A — Drift 격리 데모 모듈 + 문서 [Tier HIGH, Effort L]

**데모 기능**: "컨디션 로그" (음주 다음날 숙취/수면/메모 기록). 도메인 적합 + 기존 sqflite 스키마와 무관한 독립 기능. Drift의 핵심(watch reactive query)을 자연스럽게 시연.

- **A1** pubspec 의존성: `drift`, `drift_flutter`, **`path_provider`** (런타임), dev: `drift_dev`, `build_runner`. (sqlite3 네이티브는 `drift_flutter`가 제공) — *acceptance*: `flutter pub get` 성공.
- **A2** `lib/integrations/drift_demo/condition_database.dart`
  - 테이블 `ConditionLogs`: `id` (autoIncrement PK), `loggedOn` (DateTime, 날짜), `severity` (int 1~5 숙취정도), `sleepHours` (real, nullable), `memo` (text, nullable), `createdAt` (DateTime).
  - `@DriftDatabase(tables: [ConditionLogs])` class `ConditionDatabase`, `schemaVersion = 1`.
  - **DB 경로 정책 고정**: `getApplicationSupportDirectory()` (path_provider) 하위 `albi_condition.sqlite`. 기존 sqflite `getDatabasesPath()/albi.db` 와 **경로·파일명 모두 분리** (격리 증명). `getDatabasesPath()` 재사용 금지.
- **A3** DAO (또는 DB 메서드): `Stream<List<ConditionLog>> watchAll()` (orderBy loggedOn desc), `Future<List<ConditionLog>> getAll()`, `Future<int> add(...)`, `Future<bool> update(...)`, `Future<int> remove(int id)`. 평균 숙취도는 **watch 기반 derived** (목록 stream에서 계산) — 쓰기 후 자동 갱신 보장.
- **A4** build_runner codegen → `condition_database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`). **`.g.dart` 는 git 커밋 대상** (CI `ci.yml` 은 `pub get→analyze→test→build`만 수행, build_runner 미포함 — 커밋 안 하면 CI build 깨짐). `.gitignore` 는 `.g.dart` 무시 안 함(확인됨). *acceptance*: `.g.dart` 생성·커밋 + analyze 0.
- **A5** Riverpod 경유 (**MVVM 엄수** — CLAUDE.md §5 View→Repository 직접 접근 금지): `lib/viewmodels/condition_log_viewmodel.dart` 가 `Stream<List<ConditionLog>> watchLogs()`, `Stream<double> watchAvgSeverity()` (또는 목록 stream에서 평균 derive), 입력/CRUD 메서드를 노출. DB/DAO 인스턴스는 ViewModel/provider 내부에만.
- **A6** `lib/views/condition/condition_log_screen.dart` — **DB/DAO 직접 접근 금지, ViewModel/provider 메서드만 호출**:
  - **StreamBuilder**`<List<ConditionLog>>`(stream: viewModel.watchLogs()) 로 reactive 목록 (Drift watch 자동 갱신 시연).
  - 평균 숙취도 카드: **FutureBuilder** 시연 — `viewModel.avgSeverityOnce()` (one-shot Future) 사용하되, 쓰기 후 provider invalidation 으로 future 재생성하여 자동 갱신 보장 (또는 watch 기반 stream 카드로 대체). connectionState/hasData/hasError 명시 처리.
  - 추가/수정/삭제 (DeleteConfirmDialog 재활용).
  - `app_routes.dart`에 route 상수+case 등록 + `more_screen.dart`에 진입 메뉴 1줄 추가 (E0 selector hardening 후).
- **A7** 테스트 `test/integrations/drift_demo/condition_dao_test.dart` — `NativeDatabase.memory()`:
  - insert 후 `watchAll()` emits length 1 / update 후 severity 변경 반영 / delete 후 empty (watch emit 명시 검증).
  - **격리 검증**: Drift DB 의 `sqlite_master` 에 production 8테이블(drinkLog/drinkEntry/...) 부재 확인.
- **A8** 문서 `docs/drift-vs-sqflite.md` — sqflite 선택 근거(8테이블 트랜잭션/FK/마이그레이션 완성) + Drift 대비표 + 본 데모가 시연하는 Drift 기능(테이블/DAO/build_runner/watch/StreamBuilder) 매핑.

*WS-A acceptance*: analyze 0 · DAO 테스트 green(watch emit + 격리) · 화면 ViewModel 경유(직접 DB 접근 0) · 컨디션 화면 진입/추가/삭제 + watch 실시간 갱신 · `.g.dart` 커밋.

### WS-B — Spec-Kit / SDD canonical 산출물 [Tier MEDIUM, Effort M]

- **B1** `specs/albi-mvp/spec.md` — 기획서.md 기반 MVP 정의 + user story + 기능 요구사항 + 화면 목록.
- **B2** `specs/albi-mvp/plan.md` — 기술 스택(Flutter/Riverpod/sqflite/Drift데모/Gemini/Supabase) + MVVM 아키텍처 + 화면별 전략.
- **B3** `specs/albi-mvp/tasks.md` — 구현 task 분해 (기존 구현분 done 체크 + 본 goal 추가분).
- **B4** `specs/albi-mvp/test.md` — 화면별 검증 시나리오 (integration_test 매핑).

*acceptance*: 4문서 존재 + 기획서와 내용 정합 + 강의 Spec-Kit 구조(spec/plan/tasks/test) 준수.

### WS-C — 학습성찰 보고서 + 강의개념↔코드 매핑 [Tier MEDIUM, Effort M]

- **C1** `docs/학습성찰.md` — 진행 과정 / 마주친 문제·해결 / 강점·개선점 / 기능 달성도 (rubric 항목).
- **C2** `docs/강의개념-구현매핑.md` — 강의 개념별 코드 증거표:
  - **Dart 언어**: null-safety(`?`/`??`/`!`), sealed class + exhaustive `switch` (`exceptions.dart:5`), records/collection-if, enum
  - **Widget**: StatelessWidget / StatefulWidget / ConsumerWidget / 위젯 합성 (각 화면)
  - OOP: sealed class (`exceptions.dart:5`), 상속 (`StateNotifier`), named ctor, `copyWith`, getter
  - 함수형: `map`/`where`/`fold`/`toList` (`drink_log_repository.dart`, `providers.dart`)
  - Lifecycle: `initState`/`didUpdateWidget`/`dispose` (`entry_card_widget.dart`, `input_section_widget.dart`)
  - async: `Future`/`async`/`await`, `Stream` (Drift watch)
  - Navigation: onGenerateRoute (`app_routes.dart`)
  - 저장소: SharedPreferences (설정), sqflite (메인), Drift (데모)
  - 비동기 UI: FutureBuilder/StreamBuilder (컨디션 화면) + Riverpod AsyncValue
- **C3** `docs/강의필기-요약.md` — 필기고사 대비 Dart/Flutter 기초 이론 요약 (강의 txt 전사 기반: 변수/연산자/제어문/OOP/함수형/비동기/Widget lifecycle/Navigator/저장소). rubric "필기" 항목 산출물.
- **루브릭 근거 보관**: OT.txt 원문이 워크스페이스에 없으므로(강의 폴더 임시 위치) C1 또는 B에 rubric 인용 출처(`...all/OT.txt`)를 기록.

*acceptance*: 3문서 존재 + 매핑표 모든 항목 file:line 증거 (검증 통과분만) + OT.txt 출처 명시.

### WS-E — 전체 비주얼 리디자인 + 아이콘/자산 [Tier HIGH, Effort XL]

#### E0 — integration_test selector 안정화 (E4 착수 전 BLOCKING) [Effort M]
리디자인이 capture/parser 테스트를 깨지 않도록 **선행**. 현재 테스트가 `find.text('건너뛰기'/'나가기'/'AI로 생성'/'직접 입력'/'항목 추가'/'저장')`, `find.byIcon(Icons.list_alt_outlined/search/close)`, `find.byType(TextField/ListView/InkWell)` 에 의존 (`_screenshot_helper.dart`, 각 capture test).
- **E0a** 위험 화면 핵심 인터랙션 요소에 안정 `Key` 부여: Home(입력 TextField/AI·직접 버튼), Draft(항목추가/저장/항목카드 `ValueKey(stable id)`), Log(검색 아이콘/닫기/리스트), More·Settings(각 ListTile `Key('more_archive')` 등), Onboarding(다음/건너뛰기/시작).
- **E0b** integration_test/capture helper 를 text/Icon → **Key 기반 finder** 로 우선 전환 (텍스트 fallback 유지 가능).
- **E0c** E3a 아이콘 토큰화(`Icons.X`→`AppIcons`)는 selector 깨짐 유발 → E0 후 또는 화면별 동시 수행.
- *acceptance*: 기존 `scripts/run-all-tests.sh integration:windows` capture/parser 테스트가 Key 기반으로 green (리디자인 전 baseline).

#### E1 — 디자인 시스템 토큰 [Effort M]
- 위스키 컨셉 유지·고도화. `lib/core/theme/app_tokens.dart` 신설:
  - Spacing scale (4/8/12/16/24/32), Radius (8/12/16/full), Elevation
  - Typography scale (Pretendard: display/headline/title/body/label) — `TextTheme`
  - Semantic color tokens (success/warning/error/info + source badge 4색 — 기존 WCAG 통과값 보존)
- `app_theme.dart` 확장: 위 토큰을 `ThemeData`(textTheme + 컴포넌트 테마: Card/FilledButton/OutlinedButton/TextButton/Chip/FAB/SegmentedButton/ListTile/Dialog/SnackBar/Divider) 에 주입. Light/Dark 패리티.
- *acceptance*: 토큰 단일 SoT · analyze 0 · 기존 화면 빌드 깨짐 0.

#### E2 — 런처 아이콘 + 스플래시 [Effort M] (독립 커밋)
- **E2a** 아이콘 아트워크 생성: 위스키 글래스/앰버 모티프 + 알비 심볼. **1차 경로 = SVG 원본 → 래스터화** (`rsvg-convert`/Inkscape 가용 시; 없으면 Pillow fallback). `assets/branding/app_icon.svg` + 1024px `app_icon.png`, `app_icon_foreground.png`(adaptive 전경), 배경색 토큰. 도구 가용성은 구현 시 확인.
- **E2b** `flutter_launcher_icons` (dev dep) 설정 → Android adaptive (mono 포함) + iOS 생성.
- **E2c** `flutter_native_splash` (dev dep) 설정 → 브랜드 컬러 배경 + 로고. Light/Dark.
- **E2d 리소스 덮어쓰기 검토**: launcher_icons/native_splash 는 `android/app/src/main/res/mipmap-*`, launch background, `ios/Runner/Assets.xcassets`, `LaunchScreen.storyboard` 를 덮어씀. 생성 전후 `git diff` 검토. **알림 아이콘 영향**: `notification_service.dart:35` 이 `@mipmap/ic_launcher` 참조 → 새 아이콘이 status bar 알림에도 적용됨. 필요 시 monochrome `@drawable/ic_notification` 별도 분리 검토.
- *acceptance*: 빌드 후 런처/스플래시 커스텀 아이콘 노출 + android/ios 리소스 diff 의도 부합 + 알림 아이콘 확인. E2 독립 커밋.

#### E3 — 인앱 아이콘셋 통일 + 일러스트 [Effort M-L]
- **E3a** `lib/core/theme/app_icons.dart` — 의미별 아이콘 중앙 매핑 (홈/기록/아카이브/통계/설정/추가/삭제/술종류 등). 화면들이 직접 `Icons.X` 산발 사용 → 토큰 경유로 통일.
- **E3b** 빈 상태 일러스트 (`assets/illustrations/*.svg` + `flutter_svg` dep): 빈 기록 / 빈 아카이브 / 빈 통계 / 온보딩 3컷. `ErrorStateWidget` 및 빈 상태 CTA에 적용.
- *acceptance*: 아이콘 토큰 단일 SoT · 일러스트 빈 상태 렌더 · analyze 0.

#### E4 — 화면별 리디자인 적용 (14 화면) [Effort XL]
디자인 시스템(E1) + 아이콘(E3a) + 일러스트(E3b) 적용. **동작/ViewModel 호출 보존**. 클러스터별:
- C1 Home: `home_screen` + `input_section_widget` + `recent_logs_widget`
- C2 Draft: `draft_review_screen` + `entry_card_widget` + `food_chips_widget` + `source_badge_widget`
- C3 Log: `log_list_screen` + `log_detail_screen` + `star_rating` + `tasting_note_section` + `tasting_note_edit_sheet`
- C4 Archive: `archive_screen` + `archive_detail_screen`
- C5 Stats: `stats_screen` (fl_chart 스타일 토큰화)
- C6 Calendar: `calendar_screen` (table_calendar 테마)
- C7 Settings: `settings_screen` + `more_screen` + `ai_settings_screen` + `notification_settings_screen` + `account_screen`
- C8 Onboarding: `onboarding_screen` (일러스트 적용)
- 공통: `error_state_widget`, `delete_confirm_dialog`, `route_error_screen`, `animations`
- **동작 보존 BLOCKING 항목** (Codex R1 위험 지점): controller 생명주기 유지(`input_section_widget`/`entry_card_widget` 의 TextEditingController·debounce·didUpdateWidget), `ValueKey(stable id)` 정책 유지(entry 항목 값 섞임 방지), capture용 `RepaintBoundary` 를 screen body root 에 유지, ListView/SingleChildScrollView 구조 보존.
- *acceptance*: 클러스터별 빌드/동작 보존 + capture/parser integration_test green(E0 Key 기반) + 다크모드 패리티 + 하드코딩 잔존 검사: `rg "Color\(0x|EdgeInsets|SizedBox\(|BorderRadius\.circular" lib/views` 결과 검토 후 허용 예외만 잔존(주석/문서 기록).

#### E5 — 다방면 디자인 재검토 [Effort L]
- **E5a** 캡처: 캡처 인프라 `scripts/run-all-tests.sh integration:windows` (+ seeded_capture)로 리디자인 화면 스크린샷 재생성.
- **E5b** Claude 비주얼 리뷰 (스크린샷 Read): 5축 — (1) 비주얼 심미성 (2) 접근성/대비 WCAG AA (3) 디자인시스템 일관성 (4) 브랜드 아이덴티티 (5) UX/정보위계. → `docs/reviews/design-review-claude-2026-06-04.md`.
- **E5c** Codex 코드레벨 디자인 리뷰: 토큰 사용 일관성, 하드코딩 잔존, a11y semantics, 다크모드 누락. → `docs/reviews/design-review-codex-2026-06-04.md`.
- **E5d** 발견 수정 → 재캡처 → 수렴 (5축 모두 HIGH 0).
- *acceptance*: 5축 리뷰 finding HIGH 0 + 양 리뷰 결과 파일 존재 + 수정 반영 로그.

#### E6 — 골든 테스트 갱신 + 최종 검증 [Effort S]
- 리디자인으로 깨진 golden (`home/draft/more`) 재생성: **`flutter test --update-goldens test/golden`** (`golden_helper.dart:11` — `UPDATE_GOLDENS=true` 는 compile-time const라 미작동, `--update-goldens` 로 통일) + 변경 시각 검토.
- 최종: `flutter analyze` 0 · `flutter test --exclude-tags golden` green · `flutter test test/golden` green · (가능 시) `scripts/install-and-test-device.sh` device e2e.

---

## 3. 실행 순서 / 의존성 그래프

```
[병렬 시작]
 WS-B (Spec-Kit) ─┐
 WS-C (학습성찰)  ─┤ 독립 문서 (저위험)
 WS-A (Drift데모) ─┘ 독립 코드 (격리) — A6 진입메뉴는 E0 후
 WS-E0 (selector 안정화) ─ E4 착수 전 BLOCKING
 WS-E1 (토큰) ───── 리디자인 기반
        ↓
 WS-E2 (아이콘/스플래시, 독립커밋) ∥ WS-E3 (아이콘셋/일러스트)
        ↓        (E3a 아이콘 토큰화는 E0 후 / 화면별 동시)
 WS-E4 (14화면 리디자인) ← E0/E1/E2/E3 완료 후
        ↓
 WS-E5 (다방면 재검토) → 수정 루프
        ↓
 WS-E6 (골든 갱신 + 최종 검증)
```

우선순위 Tier (시간 환산 없음): **HIGH** WS-E0·E1·E2·E4·A / **MEDIUM** WS-B·C·E3·E5 / **LOW** WS-E6.

## 4. Codex 페어 게이트 (전 워크스트림)
각 WS done 직전 Codex 리뷰 1회 (skip 시 taxonomy 사유). 디자인은 E5c 코드레벨 + 본 계획 §5 수렴에 Codex 다라운드.

## 5. 계획 수렴 게이트 (구현 착수 전)
본 계획을 Codex 다라운드 리뷰 → finding 0 수렴 후 구현 착수. 검토 축: (a) Drift 격리 완전성 (b) 리디자인 동작 보존 위험 (c) 누락 강의 갭 (d) task atomicity (e) acceptance 측정가능성.

## 6. 진행 로그
- 2026-06-04: 계획 v1 작성.
- 2026-06-04: Codex 수렴 리뷰 R1 (GO-with-fixes, 6 HIGH+MEDIUM) → 전 항목 SoT 검증 TRUE → v2 반영:
  - A1 path_provider 추가 / A2 getApplicationSupportDirectory 경로 격리 / A4 `.g.dart` 커밋 명시(CI build_runner 부재) / A5-A6 ViewModel 경유 MVVM 엄수 + 평균 자동갱신 / A7 watch emit + 격리 검증
  - E0 selector 안정화 단계 신설(E4 전 BLOCKING) / E2 리소스 diff+알림아이콘 검토+SVG 1차경로 / E4 동작보존 BLOCKING + 하드코딩 검사명령 / E5 경로 `scripts/run-all-tests.sh`+리뷰 산출물 / E6 `flutter test --update-goldens test/golden`
  - C2 Dart/Widget 기본문법 행 추가 / C3 필기요약 신설 / OT.txt 출처 보관
- 다음 = Codex R2 확인 리뷰 (잔여 finding 0 검증) → 구현 착수.

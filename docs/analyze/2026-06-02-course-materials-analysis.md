# 강의 자료 전수 분석 — albi 에 넣을 후보 도출

> 출처: `D:\...\study-helper\data\downloads\모바일프로그래밍 (대면+사전녹화) (2150151401)\all\` (47개 파일)
> 작성: 2026-06-02 / `/goal` 세션 Phase 2 산출물
> 목적: 모바일프로그래밍 과목 강의 자료를 전수 분석해 albi(과목 프로젝트)에 넣을만한 기법/기능 도출

## 1. 커버리지 증명 (미탐색 0건)

전체 47개 파일 = txt 28(빈 파일 4 포함) + pdf 19. union-diff 로 전수 커버:

| 스코프 | 파일 | 읽은 주체 |
|--------|------|----------|
| 저장소/스트림/과목 | OT.txt, Drift.txt, StreamBuilder.txt, FutureBuilder.txt, SharedPreferences.txt, 5주차_오프라인_자료.pdf, AI_시대의_개발_방식.pdf (+twin: Drift.pdf, FutureBuilder.pdf, StreamBuilder.pdf, 데이터_저장소-SharedPreferences.pdf) | Claude 직접 |
| Dart 언어 (9) | 1-연산자, 2-제어문과 함수, 변수, OOP, 함수형프로그래밍(txt), HelloWorld + Dart.pdf, Dart_OOP.pdf, 함수형프로그래밍.pdf | Agent A |
| Flutter 위젯 (10) | Flutter_환경세팅.txt, Flutter_환경설정.pdf, StatefulWidget(txt+pdf), Widget Lifecycle.txt, Widget_Life_Cycle.pdf, Widget_Layout.pdf, Widget.pdf, Widget(1).pdf, 비동기프로그래밍.pdf | Agent B |
| 네비게이션 (5) | Navigator.txt, Navigation.pdf, EffectiveNavigator(txt+pdf), Flutter_Route.pdf | Agent C |
| AI 워크플로우 (8) | Claude Design, Claude·Codex 결과물, Claude·Codex 앱구현, codex setting, oh-my-claude-code, SDD Spec-kit setup, Spec-Kit 구현, Spec-Kit 수정 | Agent D |
| 빈 파일 (4, 0바이트) | ClaudeCode Setting.txt, Widget Layout.txt, Widget.txt, 비동기프로그래밍.txt | 내용 없음 (pdf twin 으로 대체) |

→ 차집합 0. **전수 탐색 완료**.

## 2. 채점 기준 (OT.txt — 가장 중요)

총 100점: 출석 + 기말필기(14주차, Flutter/Dart 기초 객관식) + 프로젝트 계획서(기획서+MVP) + 팀 상호평가 + **최종 결과물** + 학습성찰.

**최종 결과물 채점 3축** (albi 직결):
1. **기능 구현 충실성** — 기획서 정의 내용을 정확히 구현
2. **예외 처리 완성도** — 오류/예외 처리가 완성도 있게 구성 (교수 명시 강조)
3. **앱 완성도/실용성** — UI/UX 완성도 + 실제 사용 가능한 퀄리티

교수 강조: "실생활 활용 앱", "AI 적극 활용", "스토어 출시 목표".

**고득점 예시 앱**: ① SNS 소셜 로그인 ② 리스트 애니메이션 ③ **Supabase 서버 연동(실시간/알림/유저간 실시간)** ④ 뽀모도로(To-do + 예외처리 + 그래프/트렌드) ⑤ 캘린더 + 다이얼로그.

## 3. 강의가 가르치는 스택 vs albi 현재 (grep 확정)

| 강의 주제 | 강의 권장 | albi 현재 | gap |
|-----------|----------|-----------|-----|
| 데이터 저장 | SharedPreferences → **Drift(반응형 ORM)** | sqflite raw + Riverpod | Drift 미사용 (Riverpod 으로 반응성 대체 中) |
| 비동기 UI | FutureBuilder → **StreamBuilder** | FutureProvider | StreamBuilder/StreamProvider 0건 |
| 네비게이션 | Navigator.push → **Named Routes/onGenerateRoute** → GoRouter | Navigator.push 6곳 imperative | Named routes 0건 |
| 애니메이션 | (위젯 강의) AnimatedList/Hero/암시적 | 정적 UI | 애니메이션 0건 (AnimatedList/Hero/Transition/AnimationController 전무) |
| AI | Gemini 등 외부 API + **Gemma 온디바이스 대안** | Gemini API + LocalRuleParser fallback | 온디바이스 미사용 (단 fallback 존재) |
| 인증/서버 | (고득점 예시) 소셜로그인 + Supabase | 로컬 전용 | Supabase/소셜 0건 |
| 캘린더 | (고득점 예시) | stats(fl_chart)만 | 캘린더 0건 |
| 개발 방법론 | DDD/TDD/SDD, Spec-Kit, AI Driven | CLAUDE.md 규칙 | (방법론, 기능 아님) |

## 4. 후보 (Tier 분류) — Codex 검토 대상

### Tier 1 — credential 필요, 사용자 명시 요구(".env 만 넣으면" 사전배선)
- **A. Supabase 클라우드 백업/동기화 + 인증** — 고득점 예시 ①③ 직결. 기기 변경 시 음주 기록 복원(실생활). 네트워크/오프라인 예외처리(채점 2축). **local-first opt-in**: `.env` 비면 dormant(기존 로컬 동작 100% 유지), 채우면 활성. `.env`: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (+ 소셜 OAuth 선택).
- **B. Gemini API key `.env`(--dart-define) 주입 옵션** — 현재 secure storage 인앱 입력만. `.env`/`--dart-define` 으로도 주입 가능하게(빌드 타임 기본 키). 소규모.

### Tier 2 — credential 불필요, 완성도(UI/UX 채점)
- **C. 애니메이션** — AnimatedList(기록 추가/삭제 슬라이드), Hero(리스트→상세 공유 요소), 암시적 애니(통계 값 전환). 고득점 예시 ②, UI/UX 채점.
- **D. 캘린더 뷰** — 월별 음주 달력(`table_calendar`). 음주일 시각화. 고득점 예시 ⑤, 실생활 유용.
- **E. Named Routes + onGenerateRoute 리팩토링** — EffectiveNavigator 베스트프랙티스(경로 상수화, 타입세이프 인자, 에러 라우팅). 강의 강조.
- **F. StreamBuilder/Drift 반응형** — 강의 핵심 스택. 단 Riverpod(ref.watch+invalidate)이 이미 동등 반응성 제공 → 마이그레이션 가치 의문(Codex 판단 영역).

### Tier 3 — 보류 후보
- 온디바이스 Gemma(LocalRuleParser 이미 "AI 없어도 동작" 충족), Dart 기법(records/extension/pattern matching — 점진 개선), Spec-Kit 방법론(앱 기능 아님).

## 5. Codex 페어 검토 항목
1. 미탐색 0건 검증 (놓친 후보?)
2. Scope 챌린지 (Supabase 가 로컬 음주앱에 적합? bloat?)
3. Drift 마이그레이션 판단 (작동 sqflite 유지 vs 강의 정합)
4. .env-ready 아키텍처 베스트 패턴
5. 우선순위 + 최종 권고 세트

## 6. Codex verdict (2026-06-02 검토 완료 — 미탐색 0건 확정)

Codex(GPT-5.x, `opnd-codex:codex-rescue`)가 강의 원본 8+ 파일 + albi 코드 직접 확인. 5필드 검증형식. 핵심:

1. **미탐색 0건**: Claude 후보 세트 누락 거의 없음(confidence 높음). albi 는 이미 `PopScope`(draft_review_screen.dart:45), 전역 crash handler(main.dart:16), `CancelToken`(home_viewmodel.dart:121), `showDatePicker` 보유. 추가 제안: 예외처리 시나리오 문서/검증 로그(발표·성찰 점수 방어용, 기능 아님).
2. **Scope**: 가치O = 캘린더/애니메이션/Supabase opt-in 백업/Named Routes. bloat = Drift 전면전환·Gemma·Supabase 실시간/유저간·소셜로그인 완전구현. Supabase 는 "백업/복원+이메일인증+.env 없으면 비활성" 범위면 정당.
3. **Drift**: 전면 마이그레이션 **하지 말 것**. sqflite 가 단순 CRUD 아님 — 트랜잭션/개인정보 NULL 정리/entry-id 보존 upsert(tastingNote CASCADE 보호) 의미. 회귀 위험 XL > 점수 상승. DB sqflite 유지. 대안: StreamBuilder 시연용 작은 read-only stream.
4. **.env 아키텍처**: `lib/core/app_config.dart`(String.fromEnvironment) + `appConfigProvider`/`supabaseClientProvider`(config 비면 null) + `lib/integrations/supabase/`(sync/auth service) + `lib/data/sync_metadata_repository.dart`(변경 큐/마지막 동기화 시각). offline-first: 로컬 먼저 저장→sync queue enqueue→네트워크 실패는 NetworkError 배너만, 로컬 성공 롤백 안 함.
5. **최종 우선순위**:

| 후보 | 채점기여 | 난이도 | 구현여부 |
|---|---|---|---|
| `table_calendar` 월별 음주 캘린더 (lib/views/calendar/) | 높음 | M | **구현** |
| 리스트/Hero 애니메이션 (LogList/LogDetail) | 높음 | S~M | **구현** |
| Named Routes + onGenerateRoute (lib/core/app_routes.dart) | 중간 | M | **구현** |
| Gemini --dart-define 기본 키 옵션 (lib/core/app_config.dart) | 중간 | S | **구현** |
| Supabase opt-in 백업/복원 + 이메일 인증 (supabase_flutter) | 높음 | L | **구현**(.env dormant) |
| StreamBuilder 시연용 sync status stream | 낮음~중간 | S | 선택(Supabase UI 에 fold) |
| Drift 전면 마이그레이션 | 낮음/위험 큼 | XL | **미구현** |
| 온디바이스 Gemma | 낮음/위험 큼 | XL | **미구현** |
| Supabase 실시간/소셜 완전 | 과함 | XL | **미구현** |

> 사용자 명시 요구(".env 만 넣으면" credential 사전배선)에 따라 Codex 가 "선택"으로 둔 Supabase 백업/복원도 **구현 대상에 포함**(단 백업/복원+이메일인증 범위 한정, 실시간/소셜 제외). → ULTRA PLAN: [docs/plan-course-additions-2026-06-02.md](../plan-course-additions-2026-06-02.md)

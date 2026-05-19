# Albi - Project Instructions

## 프로젝트 개요

알비(Albi, 알코올 비서) — 자연어 음주 기록 앱 (Flutter)
- 과목: 모바일 앱 프로그래밍
- 팀: 김태겸(파싱/DB), 곽지한(UI/디자인)
- 기간: 2026-03-30 ~ 2026-05-10

## 아키텍처

**MVVM** — View → ViewModel → Model, 의존성 최소화

```
lib/
├── views/
│   ├── common/           # 공통 위젯 (ErrorStateWidget, DeleteConfirmDialog)
│   ├── draft_review/     # Screen + Widget
│   ├── home/, log/, archive/, stats/, settings/, onboarding/
├── viewmodels/           # Riverpod StateNotifier/AsyncNotifier
├── domain/entities/      # Entity data classes
├── data/                 # Repository (sqflite 직접 구현, 인터페이스 없음)
├── integrations/         # AI adapter (parser, gemini client)
└── core/
    ├── database/         # database_helper, seed_loader, init
    ├── utils/            # label_utils, korean_number, date_utils
    ├── exceptions.dart   # sealed AppError 계층
    ├── providers.dart    # Repository + 공유 데이터 providers
    └── app_theme.dart
```

구현체가 1개면 인터페이스 없이 직접 사용.

## 핵심 규칙

1. **저장 전 반드시 검토/수정 화면** — 자동 저장 금지
2. **AI 로직은 `integrations/parser/` 안에만** — View/ViewModel에 직접 넣지 말 것
3. **AI 없어도 동작** — LocalRuleParser가 항상 fallback
4. **failure path first** — 정상보다 비정상 복구가 더 중요
5. **View 는 Repository 직접 접근 금지** — ViewModel 메서드 호출만
6. **Repository 쓰기 경계는 try-catch + DatabaseError** — 읽기는 raw 통과 허용
7. **Provider 는 autoDispose 미사용 default** — `lib/app.dart` 의 `IndexedStack` 이 3 탭 화면을 유지하므로 autoDispose 적용 시 사용자 입력/스크롤 상태 소실. 저사용 family provider 만 한정적으로 적용 가능 (현재 0건).
8. **개인정보 cleanup** — 단일 기록 삭제 (`DrinkLogRepository.delete`) 시 같은 트랜잭션에서 `parseJob.rawRequest/rawResponse/errorMessage` 를 NULL 처리. 전체 삭제 (`settings_viewmodel.resetAllRecords`) 는 `parseJobRepo.deleteAll()` 로 행 자체 삭제.

## 에러 계층 (sealed)

`lib/core/exceptions.dart` — `sealed class AppError` + 4 subclass:
- `DatabaseError` — sqflite 쓰기 실패
- `NetworkError(statusCode)` — Dio/API 실패
- `ParseError` — 입력 파싱 실패
- `ValidationError` — 입력 검증 실패

switch pattern 은 exhaustive — 새 subclass 추가 시 컴파일 에러로 감지.

## 데이터 흐름

```
입력 → ParseOrchestrator
         ├─ AI 사용 가능? → GeminiTextParser → ParseResult
         └─ 아니면        → LocalRuleParser  → ParseResult
       → DraftReviewScreen (검토/수정)
       → DrinkLogRepository.save() (트랜잭션)
       → 홈/목록/아카이브/통계 갱신
```

## DB 테이블 (8개)

drinkLog, drinkEntry, drinkLogFood, liquorMaster, tastingNote, parseJob, aiConfig, usageQuota

## 주요 Provider

| Provider | 위치 | 역할 |
|----------|------|------|
| `databaseProvider` | core/providers.dart | sqflite Database 인스턴스 (FutureProvider) |
| `drinkLogRepoProvider` | core/providers.dart | DrinkLogRepository |
| `liquorMasterRepoProvider` | core/providers.dart | LiquorMasterRepository |
| `aiConfigRepoProvider` | core/providers.dart | AiConfigRepository |
| `parseJobRepoProvider` | core/providers.dart | ParseJobRepository |
| `recentLogsProvider` | core/providers.dart | 홈 최근 5건 (FutureProvider) |
| `logCountProvider` | core/providers.dart | 전체 기록 수 (FutureProvider) |
| `homeViewModelProvider` | viewmodels/home_viewmodel.dart | 홈 입력 상태 + 파서 호출 |
| `orchestratorProvider` | viewmodels/home_viewmodel.dart | ParseOrchestrator |
| `localParserProvider` | viewmodels/home_viewmodel.dart | LocalRuleParser |
| `draftReviewProvider` | viewmodels/draft_review_viewmodel.dart | 초안 검토/수정 상태 |
| `logListProvider` | viewmodels/log_list_viewmodel.dart | 기록 목록 (AsyncNotifier) |
| `archiveListProvider` | viewmodels/archive_viewmodel.dart | 아카이브 집계 |
| `archiveCategoryFilter` | viewmodels/archive_viewmodel.dart | 카테고리 필터 (StateProvider) |
| `statsProvider` | viewmodels/stats_viewmodel.dart | 통계 (FutureProvider) |
| `aiConfigProvider` | viewmodels/ai_settings_viewmodel.dart | AI 설정 + quota (AsyncNotifier) |

## 시드 데이터

- `assets/seed/liquor_master.json` — **553종** (위스키/와인/맥주/스피릿/사케/소주/막걸리/칵테일 등), 한국어 라벨 70%
- `assets/seed/food_dictionary.json` — 음식 36종
- `assets/seed/place_keywords.json` — 장소 키워드 (접미사, 지역명, 정확매칭)

**시드 재생성**: `python tools/seed_generator/generate_seed.py`
- Wikidata SPARQL (P1056 역쿼리) + `curated_brands.json` (수작업 한국 시장 브랜드) 병합
- 기존 entry 보존, canonicalName lowercase 기준 dedupe
- 브랜드 추가 방법: `curated_brands.json` 편집 후 재실행

## 테스트

### 직접 호출

```bash
flutter test --exclude-tags golden  # 46개 유닛/위젯 테스트
flutter test                        # +3 golden (로컬 pixel diff 주의, CI 제외)
flutter test integration_test/      # E2E (Windows desktop 기본)
flutter test integration_test/ -d <DEVICE_ID>  # 특정 device 에서 실행
flutter analyze                     # 0 issues
```

Golden 테스트는 `UPDATE_GOLDENS=true` 환경변수로만 자동 갱신 (기본 false).

### LLM 자율 실행 wrapper (scripts/)

`scripts/run-all-tests.sh` — analyze + unit + golden + integration 자동 실행:

```bash
bash scripts/run-all-tests.sh smoke              # analyze + unit (~10s)
bash scripts/run-all-tests.sh unit               # analyze + unit
bash scripts/run-all-tests.sh golden             # golden test
bash scripts/run-all-tests.sh integration:windows  # Windows desktop
bash scripts/run-all-tests.sh integration:android  # 연결된 Android device
bash scripts/run-all-tests.sh all                # 모두 (Android 우선, fallback Windows)
UPDATE_GOLDENS=true bash scripts/run-all-tests.sh golden  # golden 재생성
```

`scripts/install-and-test-device.sh` — APK 빌드 + Android device install + integration test:

```bash
bash scripts/install-and-test-device.sh
```

### 디바이스 테스트 환경 요구사항

- Flutter SDK PATH (`/d/flutter/bin` 또는 `$PATH`)
- JDK 17+ 설정 (Android Gradle Plugin 요구): `flutter config --jdk-dir="C:\Program Files\OpenJDK\jdk-21.0.2"`
- Android licenses 수락: `yes | flutter doctor --android-licenses`
- USB 디버깅 활성화된 Android device 또는 emulator
- `flutter devices` 에 `android-arm64` 표시 확인

## CI

GitHub Actions: push/PR → analyze → test → (main만) APK 빌드

## 커밋 컨벤션

`type: 한글 설명` (feat/fix/ci/docs/refactor/chore)

---

## 📌 향후 작업 지침 (2026-05-18 갱신)

### 활성 문서 계층
| 역할 | 파일 | 비고 |
|------|------|------|
| **최상위 기획** | [docs/기획서.md](docs/기획서.md) | 외부 docx v2.1 + 와이어프레임 + 현재 구현을 통합. 작업 시 항상 이 문서 § 4.1 화면 목록을 기준으로 삼을 것 |
| **와이어프레임 Gap 플랜** | [docs/plan-wireframe-diff.md](docs/plan-wireframe-diff.md) | 39 건 Gap + Phase A/B/C 우선순위. 다음 기능 착수 전 반드시 확인 |
| **UI/UX 6라운드 평가 (2026-05-18)** | [docs/analyze/2026-05-18-ui-ux-evaluation.md](docs/analyze/2026-05-18-ui-ux-evaluation.md) | 14 agent (Claude 9 + Codex 5) 양방향 cross-feedback. ~165 unique finding. CRITICAL/HIGH 백로그 |
| **Phase C plan (도메인 차별화)** | [docs/plan-phase-c-domain-differentiation.md](docs/plan-phase-c-domain-differentiation.md) | C1-C5 (표준잔/알림/occasion/i18n/라벨갤러리) — 사용자 결정 영역 |
| **Phase D plan (시각 identity)** | [docs/plan-phase-d-visual-identity.md](docs/plan-phase-d-visual-identity.md) | D1-D5 (6색 팔레트/illustration 10건/splash) — 사용자 결정 영역 |
| **개발 지침** | [CLAUDE.md](CLAUDE.md) | 이 파일. 아키텍처 규칙, 기술 스택, 명령어 |
| **자료 원본** | `C:\Users\tgkim\AppData\Local\Temp\albi_spec_review\` | 외부 docx + wireframes.html + screen_flow.png (로컬 임시) |
| **과거 플랜 (완료)** | [plan.md](plan.md), [plan-error-handling.md](plan-error-handling.md) | Phase 1-4 + 에러 처리 잔여분. 역사 보존용, 신규 작업에 참조하지 말 것 |

### 구현 진도 (2026-04-23 기준)

**Phase A ✅ 완료** (MVP 필수 누락 3건 + 선행 결함 1건)
- A0 drink_log update() entry id 보존 upsert
- L-4 테이스팅 노트 UI · A-5 아카이브 상세 · D-1 AI 실패 배너

**Phase B1~B3 ✅ 완료** (UX 완성, 15 Gap)
- 통계 차트 + 기간 탭, 설정 메인 재설계, AI 처리 로그, 홈 보강
- 기록 월 그룹·시간대·서브타이틀, 아카이브 카드 강화
- 검토 디테일 (매칭 아이콘·영문 병기), 더보기 링크, 빈 상태 CTA

**Phase C ✅ 완료** (실질 가치 3건)
- 다크 모드 선택 · 오픈소스 라이선스 · 온보딩 비주얼

**잔여 0 건** — 와이어프레임 39 Gap 전체 완료.

> H-5 AI 로딩 취소 / C-4 기본 수량 단위 / C-5 6시 컷오프 모두 완료 — 2026-05-18 /analyze 후속 검증에서 확인 (CancelToken: `gemini_client.dart:35` + `parse_orchestrator.dart:33` + `home_viewmodel.dart:76-106` / `defaultQuantityUnit` 와 `sixHourCutoffEnabled` 는 `app_settings_viewmodel.dart:5-6` + `settings_screen.dart` UI + `home_viewmodel.dart:19` 파서 전달).

와이어프레임 정합성 **36/39 완료**. 세부는 [docs/plan-wireframe-diff.md](docs/plan-wireframe-diff.md) § 8 히스토리 참조.

### 추가 구현 진도 (2026-05-18 — UI/UX 6라운드 평가 후속)

**Phase 0 ✅ 완료** (출시 차단 CRITICAL 8건, `e7bd5ab`)
- Android INTERNET / iOS Photo+Camera 권한
- Android release keystore 분리 (`key.properties` gitignore)
- parseJob.rawRequest 원문 privacy fix
- LogList long-press → trailing 휴지통 button (a11y)
- entry_card IconButton 48dp tap target
- Day 1 첫 저장 reward Snackbar
- Source badge 4 색 WCAG AA fix

**Phase 1 ✅ 완료** (HIGH 6건, `e093b28`)
- 미래 날짜 입력 차단
- 0-entry 저장 차단 + qty/abv silent fallback 제거
- archive_detail 빈 상태 grey → onSurfaceVariant
- stats pie chart 라벨 white → black87
- home/food Chip shrinkWrap 제거 (48dp tap target)

**Phase 2 Mini ✅ 완료** (`2591650`)
- StarRating Semantics (TalkBack/VoiceOver button + label)

**Phase 2/3 잔여** (사용자 결정 영역 또는 sprint 단위)
- 잔여 HIGH ~50건 — announce / userMessage / DB retry / permission_handler / recovery flow / period filter empty / search 등
- Phase C implementation (docs/plan-phase-c-domain-differentiation.md)
- Phase D implementation (docs/plan-phase-d-visual-identity.md)

### LLM 자율 device test 환경 (2026-05-18)

- `scripts/run-all-tests.sh` — 6 target wrapper (smoke/unit/golden/integration:windows/integration:android/all)
- `scripts/install-and-test-device.sh` — APK 빌드 + device install + integration test
- 검증된 device: SM F711N (Android 15 API 35)
- JDK 21 + Android licenses 사전 설정 필수 (위 § 테스트 참조)
- mixed file 처리 전략 (사전 WIP 보존): backup → `git restore` HEAD → 내 변경만 재적용 → stage → commit → backup 복원

### 작업 루틴 (권장)

```
1. /analyze 로 현재 상태 파악
2. docs/plan-wireframe-diff.md 의 Gap ID 선택
3. /plan {Gap ID} 구현 으로 plan 작성 후 승인 받기
4. 구현 → flutter analyze + flutter test 로컬 통과
5. /commit 으로 논리 단위 분리 커밋
6. 완료된 Gap 은 plan-wireframe-diff.md 체크박스 토글 + 기획서.md 상태 컬럼 업데이트
```

### 작업 시 확인 규칙

1. **구현 상태 검증 전 Gap 주장 금지** — 와이어프레임-구현 diff 시 반드시 실제 파일 Read/Grep 으로 5-Check (`CLAUDE.md` § Verification Before Reporting 참조)
2. **스키마 우선 확인** — `tastingNote`, `parseJob`, `liquorMaster.isFavorite` 등 테이블/필드는 이미 존재. 신규 필드 추가 전 `database_helper.dart` 먼저 확인
3. **마이그레이션 불필요한 작업 우선** — Phase A/B 대부분은 UI 만 추가하면 됨. `_dbVersion` 증가 필요한 작업은 별도 검토
4. **View → ViewModel 규칙 유지** — 신규 화면도 ViewModel 경유, Repository 직접 접근 금지
5. **공통 위젯 재활용** — `ErrorStateWidget`, `DeleteConfirmDialog` 를 새 화면에도 사용

### 외부 기획서 원본 위치 (참고)
- 제공자: 곽태만상 공동 작성
- 수신일: 2026-04-23
- 원본 zip: `C:\Users\tgkim\Downloads\Telegram Desktop\알비_모바일앱개발_기획서_곽태만상.zip`
- 본 프로젝트에 필요한 내용은 [docs/기획서.md](docs/기획서.md) 로 통합 완료 — 원본 zip 은 git 추적 제외

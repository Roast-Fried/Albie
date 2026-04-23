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

```bash
flutter test --exclude-tags golden  # 37개 유닛/위젯 테스트
flutter test                        # +3 golden (로컬 pixel diff 주의, CI 제외)
flutter test integration_test/      # E2E (Windows desktop)
flutter analyze                     # 0 issues
```

Golden 테스트는 `UPDATE_GOLDENS=true` 환경변수로만 자동 갱신 (기본 false).

## CI

GitHub Actions: push/PR → analyze → test → (main만) APK 빌드

## 커밋 컨벤션

`type: 한글 설명` (feat/fix/ci/docs/refactor/chore)

---

## 📌 향후 작업 지침 (2026-04-23 갱신)

### 활성 문서 계층
| 역할 | 파일 | 비고 |
|------|------|------|
| **최상위 기획** | [docs/기획서.md](docs/기획서.md) | 외부 docx v2.1 + 와이어프레임 + 현재 구현을 통합. 작업 시 항상 이 문서 § 4.1 화면 목록을 기준으로 삼을 것 |
| **와이어프레임 Gap 플랜** | [docs/plan-wireframe-diff.md](docs/plan-wireframe-diff.md) | 39 건 Gap + Phase A/B/C 우선순위. 다음 기능 착수 전 반드시 확인 |
| **개발 지침** | [CLAUDE.md](CLAUDE.md) | 이 파일. 아키텍처 규칙, 기술 스택, 명령어 |
| **자료 원본** | `C:\Users\tgkim\AppData\Local\Temp\albi_spec_review\` | 외부 docx + wireframes.html + screen_flow.png (로컬 임시) |
| **과거 플랜 (완료)** | [plan.md](plan.md), [plan-error-handling.md](plan-error-handling.md) | Phase 1-4 + 에러 처리 잔여분. 역사 보존용, 신규 작업에 참조하지 말 것 |

### 다음 작업 우선순위 (Phase A → B → C)

**Phase A (MVP 필수 누락, 2-3일)** — 반드시 먼저
1. 테이스팅 노트 UI (L-4) — `log_detail_screen.dart` 에 향/맛/피니시/평점 섹션 + CTA
2. 아카이브 상세 화면 (A-5) — `views/archive/archive_detail_screen.dart` 신규
3. AI 실패 경고 배너 (D-1) — `draft_review_screen.dart` 상단 Material banner

**Phase B (UX 완성, 3-4일)** — Phase A 이후
- 통계 차트 (파이/라인) + 기간 탭 · 설정 데이터 섹션 · 최근 처리 로그 · 월별 그룹 + 시간대 자연어 · 아카이브 카드 강화 · 홈 보강 · 신뢰도 % 디테일 · 설정 메인 AI 토글 · 별점 입력

**Phase C (폴리싱)** — 여유 시
- 온보딩 비주얼 · 6시 컷오프 toggle · 기본 수량 단위 · 다크 모드 명시 · 오픈소스 라이선스 · 영문 병기 · 빈 상태 일관성

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

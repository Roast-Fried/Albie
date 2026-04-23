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

`type: 한글 설명` (feat/fix/ci/docs)

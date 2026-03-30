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
├── views/           # View (Screen + Widget)
├── viewmodels/      # ViewModel (Riverpod StateNotifier/AsyncNotifier)
├── domain/entities/ # Model (Entity data classes)
├── data/            # Repository (sqflite 직접 구현, 인터페이스 없음)
├── integrations/    # AI adapter (parser, gemini client)
└── core/            # DB 초기화, 테마, 유틸, providers
```

구현체가 1개면 인터페이스 없이 직접 사용.

## 핵심 규칙

1. **저장 전 반드시 검토/수정 화면** — 자동 저장 금지
2. **AI 로직은 `integrations/parser/` 안에만** — View/ViewModel에 직접 넣지 말 것
3. **AI 없어도 동작** — LocalRuleParser가 항상 fallback
4. **failure path first** — 정상보다 비정상 복구가 더 중요

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

| Provider | 역할 |
|----------|------|
| `databaseProvider` | sqflite Database 인스턴스 |
| `drinkLogRepoProvider` | DrinkLogRepository |
| `liquorMasterRepoProvider` | LiquorMasterRepository |
| `homeViewModelProvider` | 홈 입력 상태 + 파서 호출 |
| `draftReviewProvider` | 초안 검토/수정 상태 |
| `logListProvider` | 기록 목록 (AsyncNotifier) |
| `archiveListProvider` | 아카이브 집계 |
| `statsProvider` | 통계 데이터 |
| `aiConfigProvider` | AI 설정 + quota |
| `orchestratorProvider` | ParseOrchestrator |

## 시드 데이터

- `assets/seed/liquor_master.json` — 위스키 48종 + 기타 27종 = 75종
- `assets/seed/food_dictionary.json` — 음식 36종
- `assets/seed/place_keywords.json` — 장소 키워드 (접미사, 지역명, 정확매칭)

## 테스트

```bash
flutter test  # 33개 유닛 테스트
flutter analyze  # 0 issues
```

## CI

GitHub Actions: push/PR → analyze → test → (main만) APK 빌드

## 커밋 컨벤션

`type: 한글 설명` (feat/fix/ci/docs)

# PLAN.md 추가 검토 + Toolkit 업데이트 계획

> 작성일: 2026-03-29
> 대상: docs/PLAN.md v1.0
> 목적: (1) 기획서 내부 일관성 최종 점검 (2) 구현 시 필요한 toolkit 도구 식별

---

## Part A. PLAN.md 내부 일관성 검토

### A-1. 발견된 불일치 및 보완점

#### 1) liquorMaster.isFavorite 미정의

섹션 4-6(아카이브)에서 "즐겨찾기 상태: `liquorMaster`에 `isFavorite` 컬럼 추가"라고 했지만,
섹션 1-2의 `liquorMaster` 테이블 스키마에 `isFavorite` 컬럼이 **없다**.

**조치**: 스키마에 추가 필요.
```
isFavorite | INTEGER | O | 0 or 1. 기본값 0
```

#### 2) drinkLogFood vs foodItems 이름 혼용

- 섹션 1-1 ER: `drinkLogFood` 테이블
- 섹션 3-2 ParseResult: `foodItems: List<String>`
- 섹션 3-5 Gemini 스키마: `"foodItems"`
- 섹션 4-3 검토 화면: `🍽️ 음식: [육회] [치즈]`

흐름: AI/파서 → `foodItems` (문자열 리스트) → 저장 시 → `drinkLogFood` (개별 row)

**판정**: 불일치가 아니라 **레이어 간 변환**이다. 다만 변환 로직이 명시되지 않았다.

**조치**: Phase 4의 `save_log_use_case.dart` 태스크에 다음 추가:
- `ParseResult.foodItems: List<String>` → `drinkLogFood` 테이블 INSERT (log당 N개 row)

#### 3) overallMemo 위치

- `drinkLog` 테이블에 `overallMemo` 있음 ✓
- `ParseResult`에 `overallMemo` 있음 ✓
- 검토 화면에 `📝 메모` 있음 ✓
- Gemini 스키마에 `overallMemo` 있음 ✓

**판정**: 일관됨. 문제 없음.

#### 4) appSettings 엔티티 미정의

섹션 1-1 ER에서 `(독립) appSettings`를 언급했지만, 스키마 정의가 없다.

**조치**: `shared_preferences`로 처리하므로 별도 테이블 불필요. ER 관계도에서 제거하거나, 명시적으로 "shared_preferences에 저장" 주석 추가.

관리할 설정값:
- `onboarding_completed: bool`
- `default_quantity_unit: string` (glass)
- `dark_mode: string` (system/light/dark)
- `six_hour_cutoff_enabled: bool` (true)

#### 5) parseJob.logId nullable 설명 부족

parseJob은 "저장 전이면 null"이라고 했는데, 저장 후에는 어떻게 연결하는가?

**조치**: save_log_use_case에서:
1. drinkLog INSERT → logId 획득
2. parseJob UPDATE SET logId = {logId} WHERE id = {parseJobId}

orchestrator가 parseJob을 먼저 생성(logId=null) → 저장 시 연결.

#### 6) 디렉토리 구조에 누락된 파일

섹션 6 디렉토리에 있지만 섹션 7 태스크에서 언급 안 된 것:
- `core/router/app_router.dart` → Phase 1에서 생성이라 OK
- `presentation/common/` 위젯들 → Phase 9에서 처리라 OK
- `application/use_cases/validate_api_key_use_case.dart` → Phase 6 태스크에 있음 ✓

섹션 7 태스크에서 언급되지만 섹션 6에 없는 파일:
- 없음. 일관됨.

#### 7) drinkEntry에서 place 제거 확인

섹션 1-2의 `drinkEntry` 스키마에 `place` 컬럼이 **없다** ✓
`place`는 `drinkLog` 레벨에만 있다 ✓

**판정**: 의도대로. B-1 보완이 반영됨.

#### 8) Riverpod AsyncNotifier 구체 패턴 미정의

섹션 0-2에서 "AsyncNotifier 패턴 사용"이라 했지만, 구체적으로:
- provider를 어떻게 정의하는가? (`@riverpod` codegen? 수동?)
- family provider는 쓰는가?

**조치**: 과제 규모에서는 **수동 정의 (코드 생성 없음)** 이 적절.
```dart
// 예시: 기록 목록
final logListProvider = AsyncNotifierProvider<LogListNotifier, List<DrinkLog>>(
  LogListNotifier.new,
);
```
family는 상세 화면(logId 기반)에서만 사용:
```dart
final logDetailProvider = AsyncNotifierProvider.family<LogDetailNotifier, DrinkLog, int>(
  LogDetailNotifier.new,
);
```

### A-2. 자동 검토 에이전트 결과 (20개 이슈 분류)

에이전트가 20개 이슈를 보고했다. 분류 및 처리 결과:

**PLAN.md에 즉시 반영 (7건)**:
- #1 drinkLogFood DAO 누락 → 디렉토리에 추가 (drink_log_dao.dart에 통합)
- #2/#12 parseJob DAO/repository 누락 → 디렉토리에 추가
- #4 isFavorite 누락 → 이미 추가 완료
- #8 parseWarnings 비영속화 → 설계 결정 메모로 명시 (저장 안 함, parseJob.rawResponse로 대체)
- #9 ageStatement 형식 → "15년" (한글 단위 포함) 으로 확정
- #10 place_keywords.json → 구조 정의 추가
- #14 자유입력 vs 매칭 → 설계 결정 메모로 명시
- #18 검색 쿼리 → 멀티 테이블 SQL 예시 추가

**설계상 의도적인 것 (5건, 수정 불필요)**:
- #5 gemini_image_parser.dart가 디렉토리에 있는 이유 → 파일 자체는 Phase 6에서 stub 생성, 구현은 Phase 8. 정상.
- #11 userKey 카운트 → 통계 표시용으로 유지. 주석에 "(통계 표시용, 제한 없음)" 추가.
- #13 quota 이력 보관 → 자연 축적, 삭제 정책은 R2. 과제 규모에서 문제 없음.
- #17 parseSource(DB) vs source(모델) → 레이어 간 네이밍 차이. DAO에서 매핑. 정상 패턴.
- #20 최소 1개 entry 제약 → 어플리케이션 레벨 검증. DB 제약 불필요.

**오탐 (3건)**:
- #3 liquorCategory 네이밍 불일치 → 검증 결과 drinkEntry.liquorCategory, liquorMaster.category로 각각 독립. 문맥상 정상.
- #15 테스트 케이스 "15년" → ageStatement 형식을 "15년"으로 확정했으므로 테스트 케이스가 맞음.
- #16 parse_job.dart 누락 → 실제로는 line 1000에 존재. 에이전트 오탐.

**후속 과제 (2건, R2 이후)**:
- #6 parseJob provider → Phase 9에서 구현 (설정 > 최근 처리 로그 화면)
- #7 이미지 저장 정책 → 5-7에 정책 추가 완료
- #19 처리 로그 표시 형식 → parseJob 테이블의 status + createdAt + parserUsed로 충분

### A-3. 최종 판정

| 항목 | 상태 |
|------|------|
| 테이블 스키마 ↔ ER 관계 | ✓ 반영 완료 (isFavorite, 설계 결정 메모) |
| 파서 출력 ↔ Gemini 스키마 | ✓ 일관 |
| 화면 필드 ↔ 데이터 모델 | ✓ 일관 |
| 디렉토리 ↔ Phase 태스크 | ✓ 반영 완료 (parseJob DAO/repo, drinkLogFood 통합) |
| 네이밍 | ✓ 일관 (레이어 간 매핑은 정상) |
| appSettings | ✓ 반영 완료 (shared_preferences 명시) |
| Riverpod 패턴 | ✓ 반영 완료 (수동 정의 명시) |
| 검색 쿼리 | ✓ 반영 완료 (멀티 테이블 SQL 추가) |
| 시드 데이터 구조 | ✓ 반영 완료 (place_keywords.json 정의) |
| 이미지 저장 | ✓ 반영 완료 (5-7 추가) |

**결론: 20개 이슈 중 7건 즉시 반영, 5건 의도적 설계, 3건 오탐, 2건 R2 후속. 구현 착수 가능.**

---

## Part B. Toolkit 현황 분석

### B-1. 현재 toolkit 구성

```
agents/     → 30+ 에이전트, 전부 scope: nuxt
skills/     → 40+ 스킬, 전부 nuxt/ 또는 openerd/ 또는 tooling/
commands/   → 17개, scope: core 또는 nuxt
solutions/  → 30+ 솔루션, 대부분 nuxt 프로젝트
```

**Flutter/Dart 지원: 0%**

### B-2. 현재 toolkit에서 그대로 쓸 수 있는 것

| 도구 | 용도 | 수정 필요 |
|------|------|-----------|
| `/commit` | 시맨틱 커밋 | scope: core라 그대로 사용 가능. 단 lint/typecheck 부분에서 `nuxi typecheck` → `flutter analyze` 변경 필요 |
| `/plan` | 구현 계획 | scope: core라 사용 가능 |
| `/research` | 코드베이스 리서치 | 사용 가능 |
| `/checkpoint` | 세션 상태 저장 | 사용 가능 |
| `/compound` | 솔루션 기록 | 사용 가능 |
| `solution-search-agent` | 솔루션 탐색 | 사용 가능 (Flutter 솔루션이 쌓이면) |

### B-3. 수정해서 쓸 수 있는 것

| 도구 | 현재 | Flutter용 수정 |
|------|------|----------------|
| `/code-review` | 4개 nuxt 에이전트 병렬 | Flutter용 리뷰 에이전트 세트로 교체 |
| `/typecheck` | `nuxi typecheck` / `vue-tsc` | `flutter analyze` / `dart analyze` |
| `lint-review-agent` | ESLint/oxlint | `dart analyze` + custom lint rules |
| `test-agent` | Vitest | Flutter test / integration_test |
| `architecture-review-agent` | createGlobalState, CRUD Store | Riverpod 패턴, repository 패턴 |
| `security-review-agent` | XSS(v-html), 하드코딩 키 | API key 노출, secure storage 미사용 |
| `/init` | Nuxt3 스캐폴딩 | Flutter 프로젝트 스캐폴딩 |

### B-4. 새로 만들어야 하는 것

| 우선순위 | 도구 종류 | 이름 (안) | 역할 |
|----------|-----------|-----------|------|
| **P0** | 스킬 | `flutter/core/flutter-riverpod` | Riverpod AsyncNotifier 패턴, provider 정의, DI 가이드 |
| **P0** | 스킬 | `flutter/core/flutter-sqflite` | sqflite 초기화, 마이그레이션, DAO 패턴, 시드 로더 |
| **P0** | 스킬 | `flutter/core/flutter-architecture` | presentation/application/domain/data 레이어 규칙 |
| **P1** | 에이전트 | `flutter-architecture-review-agent` | Riverpod 패턴, repository 분리, AI 격리 검사 |
| **P1** | 에이전트 | `flutter-test-agent` | flutter test 기반 단위/위젯 테스트 작성 및 실행 |
| **P1** | 에이전트 | `flutter-lint-agent` | dart analyze + custom lint 검사 |
| **P1** | 커맨드 | `/flutter-review` | Flutter용 code-review (위 3개 에이전트 병렬) |
| **P2** | 스킬 | `flutter/api/flutter-gemini-client` | Gemini API structured output, 멀티모달, 에러 처리 |
| **P2** | 스킬 | `flutter/ui/flutter-form-pattern` | 검토/수정 폼 패턴, 드롭다운, 칩, 자동완성 |
| **P2** | 스킬 | `flutter/state/flutter-crud-pattern` | CRUD 상태관리 + AsyncNotifier + repository |
| **P3** | 스킬 | `flutter/ui/flutter-chart` | fl_chart 기본 차트 패턴 (파이, 바, 라인) |
| **P3** | 스킬 | `flutter/core/flutter-secure-storage` | flutter_secure_storage 패턴, 키 관리 |
| **P3** | 솔루션 | (구현 중 발견 시) | Flutter 특화 버그픽스/패턴 기록 |

---

## Part C. Toolkit 업데이트 실행 계획

### Phase 순서와 연동

toolkit 업데이트는 **구현과 동시에** 진행한다.
각 Phase를 구현하면서 패턴이 확립되면, 해당 스킬/에이전트를 작성한다.

```
Phase 1 (뼈대)     → 작성: flutter-architecture 스킬
Phase 2 (도메인/DB) → 작성: flutter-sqflite 스킬
Phase 3 (파서)      → 작성: (파서는 알비 고유이므로 스킬 불필요)
Phase 4 (UI)        → 작성: flutter-riverpod 스킬, flutter-form-pattern 스킬
Phase 5 (CRUD)      → 작성: flutter-crud-pattern 스킬
Phase 6 (Gemini)    → 작성: flutter-gemini-client 스킬
Phase 7~9           → 작성: flutter-test-agent, flutter-lint-agent, /flutter-review
```

### 스킬 작성 기준

기존 toolkit의 스킬 구조를 따른다:

```
skills/
└── flutter/
    ├── core/
    │   ├── flutter-architecture/skill.md
    │   ├── flutter-riverpod/skill.md
    │   └── flutter-sqflite/skill.md
    ├── api/
    │   └── flutter-gemini-client/skill.md
    ├── state/
    │   └── flutter-crud-pattern/skill.md
    └── ui/
        ├── flutter-form-pattern/skill.md
        ├── flutter-chart/skill.md
        └── flutter-secure-storage/skill.md
```

각 스킬 파일 포맷:
```markdown
---
name: flutter-riverpod
description: Flutter Riverpod 상태관리 가이드. AsyncNotifier, Provider DI, family, 레이어별 provider 구성.
scope: flutter
---

# flutter-riverpod

## 핵심 규칙
...

## 패턴
...

## Anti-Pattern
...
```

### 에이전트 작성 기준

기존 에이전트 구조를 따르되 `scope: flutter`로 설정:

```
agents/
└── review/  (기존 위치에 추가)
    ├── flutter-architecture-review-agent.md
    ├── flutter-test-agent.md
    └── flutter-lint-agent.md
```

각 에이전트 frontmatter:
```yaml
---
name: flutter-architecture-review-agent
description: Flutter 아키텍처 컨벤션 리뷰. Riverpod 패턴, repository 분리, AI adapter 격리 검사.
model: sonnet
tools: [Read, Glob, Grep, Bash]
scope: flutter
portable: true
---
```

### 커맨드 수정

`/commit`은 scope: core이므로 Flutter에서도 동작하지만, 사전 검증 단계를 분기해야 한다:

```bash
# pubspec.yaml이 있으면 Flutter 프로젝트로 판단
if [ -f pubspec.yaml ]; then
  flutter analyze
  flutter test --reporter compact 2>&1 | tail -20
else
  # 기존 nuxt 로직
  npx nuxi typecheck ...
fi
```

이 수정은 `/commit`에 직접 반영하거나, `/flutter-commit`을 별도로 만든다.
**권고**: `/commit`에 분기를 추가하는 것이 관리 부담이 적다.

---

## Part D. PLAN.md 수정 사항 요약

구현 착수 전 PLAN.md에 반영할 항목:

| # | 위치 | 내용 | 우선순위 |
|---|------|------|----------|
| 1 | 섹션 1-2 liquorMaster | `isFavorite INTEGER O 기본값 0` 컬럼 추가 | 필수 |
| 2 | 섹션 1-1 ER | `appSettings` 제거 또는 "shared_preferences" 주석 | 권장 |
| 3 | Phase 4 태스크 | `save_log_use_case`에 foodItems→drinkLogFood 변환 로직 명시 | 권장 |
| 4 | Phase 4 태스크 | `save_log_use_case`에 parseJob.logId 연결 로직 명시 | 권장 |
| 5 | 섹션 0-2 | Riverpod 수동 정의 방식 명시 (codegen 미사용) | 권장 |
| 6 | 섹션 1-4 | shared_preferences에 저장할 설정값 목록 추가 | 선택 |

---

## Part E. 요약: 구현 착수 전 체크리스트

- [x] PLAN.md 작성 완료
- [x] PLAN.md 수정 (Part D 6개 항목 + 에이전트 검토 7건 반영)
- [ ] git init + 초기 커밋
- [ ] Phase 1 착수
- [ ] Phase 1 완료 후 → `flutter-architecture` 스킬 초안 작성
- [ ] Phase 2 완료 후 → `flutter-sqflite` 스킬 초안 작성
- [ ] Phase 4 완료 후 → `flutter-riverpod` 스킬 초안 작성
- [ ] Phase 6 완료 후 → `flutter-gemini-client` 스킬 초안 작성
- [ ] Phase 9 완료 후 → Flutter 리뷰 에이전트 3개 작성

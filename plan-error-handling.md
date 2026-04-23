# Plan: 뷰 에러 UI 통합 + Exception 계층화
> 날짜: 2026-04-23
> 상태: 완료
> 전제: 기존 `plan.md` (전체 개선) 완료 이후 잔여분. `/analyze` HIGH 2건 대응.

## 목표
`ErrorStateWidget`이 홈 화면에서만 미적용이고 `RepositoryException`이 1종 평면 구조로 남아있는 잔여 기술 부채를 해소한다.

## 현재 상태 (검증됨)
- `ErrorStateWidget` 적용: archive/stats/log_list/log_detail ✅ / home ❌ ([home_screen.dart:46,86](lib/views/home/home_screen.dart))
- Exception: `RepositoryException` 1종만 존재 ([exceptions.dart:2](lib/core/exceptions.dart)), `drink_log_repository.dart:42/78/86`에서만 throw. 나머지 4개 repo는 raw 예외 통과. **catch 하는 코드 0건** (grep 검증).

## 접근법
최소 침습. (1) 홈 2건 silent fail → `ErrorStateWidget`로 교체. (2) `sealed AppError` 도입, `RepositoryException` 은 catch 참조 0건이므로 **BC alias 없이 `DatabaseError` 로 완전 rename**. ParseOrchestrator 는 fallback 보존 위해 **throw 하지 않고 `NetworkError` 인스턴스의 `userMessage` 만 aiConfig 에 저장 후 null 반환**.

## 변경 파일
| 파일 | 유형 | 설명 |
|------|------|------|
| lib/core/exceptions.dart | 수정 | `sealed AppError` + `DatabaseError`/`ParseError`/`NetworkError`/`ValidationError` 추가. 기존 `RepositoryException` 제거 (catch 참조 0건). |
| lib/views/home/home_screen.dart | 수정 | `recentLogs`/`logCount` 의 `error:` → `ErrorStateWidget(message, onRetry: () => ref.invalidate(...))` |
| lib/data/drink_log_repository.dart | 수정 | `RepositoryException` → `DatabaseError` (3곳) |
| lib/data/liquor_master_repository.dart | 수정 | **쓰기 메서드만** (`insert`/`toggleFavorite`/`addAlias`) try-catch → `DatabaseError` |
| lib/data/ai_config_repository.dart | 수정 | **`update` 1건만** try-catch → `DatabaseError` (읽기/rawInsert 는 raw 통과) |
| lib/data/parse_job_repository.dart | 수정 | `insert`/`linkToLog` try-catch → `DatabaseError` |
| lib/data/tasting_note_repository.dart | 수정 | `save`/`delete` try-catch → `DatabaseError` |
| lib/integrations/parser/parse_orchestrator.dart | 수정 | DioException 분기 → `NetworkError` 인스턴스 생성, `error.userMessage` 를 aiConfig 저장, **null 반환 유지** (throw 하지 않음) |
| test/core/exceptions_test.dart | 신규 | `AppError` sealed 계층 + switch exhaustive + toString 테스트 |

## 구현 단계
- [x] 1. `exceptions.dart`: `sealed class AppError` + 4 subclass 작성, `RepositoryException` 삭제.
- [x] 2. `drink_log_repository.dart`: 3곳 `RepositoryException` → `DatabaseError` 교체.
- [x] 3. 4개 repo 쓰기 경계 메서드 try-catch 추가 (liquor_master 3건, ai_config update, parse_job 2건, tasting_note save/delete).
- [x] 4. `parse_orchestrator.dart`: `_classifyAiError(e)` helper 추출 → `NetworkError`/`ParseError` 인스턴스 생성 후 `userMessage` 만 aiConfig 에 저장, `null` 반환 유지 (fallback 보존).
- [x] 5. `home_screen.dart`: `recentLogs`/`logCount` 의 `error:` 분기를 `ErrorStateWidget(... onRetry: ref.invalidate(...))` 로 교체.
- [x] 6. `test/core/exceptions_test.dart`: 4개 테스트 그룹 (필드/toString/sealed exhaustive/Exception 계약).
- [x] 7. `flutter analyze` 0 issues + `flutter test --exclude-tags golden` 37/37 통과.

## 비범위
- ViewModel의 `AsyncValue.guard` 재설계 — 기존 동작 유지
- 에러 로깅 인프라 (Sentry/Crashlytics) 연동
- i18n 에러 메시지 카탈로그화 — 상수 인라인 유지
- `GeminiClient.validateKey`의 bare catch — 이미 `plan.md` Phase 2-2에서 처리

## 트레이드오프
| 선택지 | 장점 | 단점 | 결정 |
|--------|------|------|------|
| `RepositoryException` → `DatabaseError` 완전 rename | 타입 통일, 명칭 1개 | throw 3곳 수정 필요 | **채택** — catch 참조 0건이라 BC 불필요 |
| ParseOrchestrator throw 전파 | 에러 타입 일관성 | LocalRuleParser fallback 깨짐 | **미채택** — null 반환 유지로 fallback 보존 |
| 쓰기 경계만 try-catch | 최소 침습 | 읽기 에러 원본 통과 | **채택** — view 레이어가 어차피 `AsyncValue.error` 로 수신 |

## 위험 요소
- `home_screen`의 `onRetry: ref.invalidate(...)` — [providers.dart:39,45](lib/core/providers.dart) 확인: `FutureProvider` 는 autoDispose 미사용, invalidate 시 재평가됨 ✅
- DB 락/timeout 시 `DatabaseException` 이외 예외 누락 가능 → `on DatabaseException catch (e)` + 최종 `catch (e)` 2단 구성 적용.
- `ParseOrchestrator` 에서 NetworkError 인스턴스를 **로컬 변수로만 사용**하고 throw 하지 않음 — 분석기가 unused_local_variable 경고 낼 수 있음 → 직접 `userMessage` 만 추출하는 방식도 대안.

## 검증 기준 *(Sprint Contract)*
- [x] `flutter analyze` 0 issues (ran in 16.4s)
- [x] `flutter test --exclude-tags golden` 37/37 통과
- [x] `home_screen.dart` 의 `recentLogs`/`logCount` `error:` 분기 — `ErrorStateWidget` 로 전환, 잔여 `SizedBox.shrink()` 는 data/loading 분기용만
- [x] `on DatabaseException` 11회 / 5개 repo 파일 (기준 ≥ 4 충족)
- [x] `parse_orchestrator.dart` `_classifyAiError(e)` → `NetworkError`/`ParseError` 반환 + `_tryAiParse` 는 `null` 반환 유지
- [x] `AppError` sealed switch exhaustive — `exceptions_test.dart` 의 label 함수 컴파일 및 실행 성공
- [x] `grep "RepositoryException" lib/ test/` → 0건 (완전 rename 확인)

## 참조 코드
- Dart 3 sealed class + pattern matching: https://dart.dev/language/class-modifiers#sealed
- 이미 완료된 `plan.md` Phase 2-1 (AppError 계획) / Phase 2-4 (에러 분류) / Phase 3-2 (ErrorStateWidget) — 본 작업은 그 잔여분.

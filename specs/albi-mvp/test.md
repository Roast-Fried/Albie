# Albi MVP — Test Scenarios (SDD)

> 화면/기능별 검증 시나리오. 강의 Spec-Kit `test` 단계 대응. 실제 테스트 파일 매핑.

## 1. 단위/위젯 (test/) — 138 통과
| 영역 | 시나리오 | 파일 |
|------|----------|------|
| 파서 | 자연어 → 술/수량/도수/날짜 추출, "반 병"/"열두" 경계 | `test/integrations/parser/local_rule_parser_test.dart` |
| 한글수 | parseKoreanNumber 회귀 | `test/integrations/parser/quantity_test.dart` |
| Repo | DrinkLog 저장/수정/삭제/복원 트랜잭션 | `test/data/drink_log_repository_test.dart` |
| 복원 | restoreReplaceAll 원자성 | `test/data/restore_replace_test.dart` |
| 에러 | AppError sealed switch exhaustive | `test/core/exceptions_test.dart` |
| 라우트 | onGenerateRoute 인자 검증/에러 fallback | `test/core/app_routes_test.dart` |
| 백업 | codec 왕복 + 손상 payload 방어 | `test/integrations/supabase/backup_codec_test.dart` |
| 초안 | DraftReview copyWith sentinel / addEntry / fromParseResult | `test/widget_test.dart`, `test/viewmodels/draft_review_viewmodel_test.dart` |
| 캘린더 | 일자 그룹핑/정규화 | `test/viewmodels/calendar_viewmodel_test.dart` |
| **컨디션(Drift)** | insert→watch emit / update / delete→empty / avg / 정렬 / **격리(8테이블 부재)** | `test/integrations/drift_demo/condition_dao_test.dart` |

## 2. 골든 (test/golden/) — `flutter test --update-goldens test/golden`
- 홈 / 초안검토 / 더보기 스냅샷. 리디자인 후 재생성 필요.

## 3. 통합 캡처 (integration_test/) — 화면별 스크린샷
home / draft / log / archive / stats / onboarding / settings / theme_full / parser_ui / seeded_capture. 실행: `scripts/run-all-tests.sh integration:windows`.

## 4. 수동 검증 시나리오 (emulator/device)
| # | 시나리오 | 기대 |
|---|----------|------|
| M1 | AI 미연결 + 한 줄 입력 → 저장 | 로컬 파서 초안 → 검토 → 저장 → 홈 갱신 |
| M2 | AI 연결 + 입력 → 취소 | CancelToken 으로 로딩 취소, 로컬 fallback |
| M3 | 기록 삭제 | parseJob 원문 NULL 처리 확인 |
| M4 | 통계 기간 탭 전환 | 차트/TOP5 갱신 |
| M5 | 캘린더 날짜 선택 | 선택일 기록 → 상세 진입 |
| M6 | 알림 설정 토글 | master off 시 schedule 취소 |
| M7 | **컨디션 로그 추가/삭제** | watch 목록 자동 갱신 + 평균 숙취도 재계산 |
| M8 | 다크모드 전환 | 전 화면 패리티 |

## 5. 본 사이클 추가 검증
- WS-A: DAO 테스트 6 + 격리 검증 (자동).
- WS-E5: 다방면 디자인 재검토 5축 (비주얼/접근성/일관성/브랜드/UX) → `docs/reviews/`.
- WS-E6: analyze 0 + 전체 테스트 green + golden 재생성.

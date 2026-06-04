# Drift vs raw sqflite — 선택 근거 + 데모 매핑

> 강의(모바일프로그래밍)의 "Drift(반응형 SQLite ORM)" 단원 대응 문서.
> 메인 DB는 raw sqflite로 유지하고, Drift는 **격리 데모 모듈**로 역량을 시연한다.

## 1. 왜 메인 DB는 raw sqflite인가

Albi의 메인 데이터 계층은 `lib/core/database/database_helper.dart` 의 raw sqflite로,
이미 다음을 직접 구현해 프로덕션 수준의 완성도를 갖췄다.

- **8개 테이블** (drinkLog/drinkEntry/drinkLogFood/liquorMaster/tastingNote/parseJob/aiConfig/usageQuota)
- **트랜잭션** 5곳 (저장/수정/삭제/복원 원자성 — `drink_log_repository.dart`)
- **외래키(FK)** + `PRAGMA foreign_keys ON` + `ON DELETE SET NULL` (개인정보 cleanup)
- **인덱스** + **마이그레이션** (`_dbVersion=2`, `onUpgrade`)
- **N+1 방지** 배치 로딩 (IN 절)

이 위에서 동작 중인 8테이블을 Drift로 전체 마이그레이션하는 것은 15+ 파일에
걸친 고위험 아키텍처 변경이며(제출 임박 시 앱 완성도 리스크), 강의 루브릭
(기능 충실성·앱 완성도)에 오히려 불리하다. 따라서 **메인은 sqflite 유지**,
**Drift는 독립 데모**로 학습 역량을 입증한다.

## 2. Drift vs sqflite 대비표

| 항목 | raw sqflite (메인) | Drift (데모) |
|------|--------------------|--------------|
| 쿼리 | raw SQL 문자열 | 타입 안전 Dart 쿼리 + SQL |
| 모델 매핑 | 수동 `fromMap`/`toMap` | 코드생성(`build_runner`) 자동 |
| reactive | 수동 (Riverpod invalidate) | `watch()` Stream 자동 emit |
| 타입 안전성 | 런타임 (`as`) | 컴파일 타임 |
| 보일러플레이트 | 많음 | 적음 (생성기) |
| 마이그레이션 | 수동 `onUpgrade` | `schemaVersion` + 헬퍼 |
| 학습 비용 | 낮음 | 중간 (코드생성 이해 필요) |

## 3. Drift 데모가 시연하는 강의 기법

데모 기능: **컨디션 로그** (음주 다음날 숙취/수면/메모). 메인 sqflite와 완전 격리
(별도 파일 `albi_condition.sqlite`, 별도 디렉터리 `getApplicationSupportDirectory()`).

| 강의 기법 | 데모 구현 위치 |
|-----------|----------------|
| Drift Table 정의 | `condition_database.dart` `ConditionLogs extends Table` |
| 코드 생성 (build_runner) | `condition_database.g.dart` (git 커밋) |
| DAO 스타일 CRUD | `ConditionDatabase` add/updateLog/remove/getAll |
| **watch() reactive query** | `watchAll()`, `watchAvgSeverity()` |
| **StreamBuilder** | `condition_log_screen.dart` 목록 (watch 소비) |
| **FutureBuilder** | `condition_log_screen.dart` 평균 숙취도 카드 (one-shot + setState 재실행) |
| StatefulWidget lifecycle | `_ConditionLogScreenState.initState` |
| MVVM 경계 | View → `ConditionLogViewModel` 경유 (DB 직접 접근 0) |

## 4. 격리 보증

- 파일: `albi_condition.sqlite` (메인 `albi.db`와 다름)
- 디렉터리: `getApplicationSupportDirectory()` (메인은 `getDatabasesPath()`)
- 공유 테이블/FK 없음 — `condition_dao_test.dart` 의 "격리 검증" 테스트가
  Drift DB `sqlite_master`에 메인 8테이블이 없음을 자동 검증.

## 5. 빌드 주의

- `.g.dart`(생성물)는 **git 커밋 대상**. CI(`ci.yml`)는 `pub get→analyze→test→build`만
  수행하고 `build_runner`를 실행하지 않으므로, 커밋하지 않으면 CI 빌드가 깨진다.
- 스키마 변경 시: `dart run build_runner build` 재실행 후 `.g.dart` 재커밋.
- drift 도입으로 `sqflite_common_ffi`/`sqlite3`가 소폭 다운그레이드되지만
  기존 138개 테스트 전부 통과(회귀 없음) 확인됨.

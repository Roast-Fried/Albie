import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'condition_database.g.dart';

/// 컨디션 로그 — Drift 격리 데모 모듈.
///
/// 강의 "Drift(반응형 SQLite ORM)" 단원을 시연하기 위한 **독립** 기능.
/// 음주 다음날 숙취/수면/메모를 기록한다.
///
/// 기존 메인 DB(raw sqflite, `albi.db`, 8테이블)와 **완전 분리**:
/// - 별도 파일 `albi_condition.sqlite`
/// - 별도 디렉터리 `getApplicationSupportDirectory()` (sqflite 는 `getDatabasesPath()`)
/// - FK/공유 테이블 없음
///
/// 시연 Drift 기능: Table 정의 · 코드생성(build_runner) · DAO 스타일 쿼리 ·
/// `watch()` reactive Stream · 트랜잭션 안전 CRUD.
class ConditionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 컨디션을 기록한 날짜 (음주 다음날 등).
  DateTimeColumn get loggedOn => dateTime()();

  /// 숙취 정도 1(없음)~5(심함).
  IntColumn get severity => integer()();

  /// 수면 시간(시간). 선택.
  RealColumn get sleepHours => real().nullable()();

  /// 메모. 선택.
  TextColumn get memo => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [ConditionLogs])
class ConditionDatabase extends _$ConditionDatabase {
  /// 앱 실행 시: path_provider 기반 격리 파일로 연결.
  /// 테스트 시: `ConditionDatabase(NativeDatabase.memory())` 로 인메모리 주입.
  ConditionDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  /// 메인 sqflite DB와 다른 디렉터리/파일명으로 격리 연결.
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'albi_condition.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // ---- reactive 조회 (강의 watch 시연) ----

  /// 전체 컨디션 로그 reactive 스트림 (최신 날짜순). 쓰기 시 자동 emit.
  Stream<List<ConditionLog>> watchAll() {
    return (select(conditionLogs)
          ..orderBy([
            (t) => OrderingTerm(expression: t.loggedOn, mode: OrderingMode.desc),
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// 평균 숙취도 reactive 스트림 — 목록 stream에서 파생(쓰기 후 자동 갱신).
  /// 데이터 없으면 0.
  Stream<double> watchAvgSeverity() {
    return watchAll().map((rows) {
      if (rows.isEmpty) return 0;
      final sum = rows.fold<int>(0, (acc, r) => acc + r.severity);
      return sum / rows.length;
    });
  }

  /// 평균 숙취도 one-shot (FutureBuilder 시연용). 데이터 없으면 0.
  Future<double> avgSeverityOnce() async {
    final rows = await select(conditionLogs).get();
    if (rows.isEmpty) return 0;
    final sum = rows.fold<int>(0, (acc, r) => acc + r.severity);
    return sum / rows.length;
  }

  Future<List<ConditionLog>> getAll() {
    return (select(conditionLogs)
          ..orderBy([
            (t) => OrderingTerm(expression: t.loggedOn, mode: OrderingMode.desc)
          ]))
        .get();
  }

  // ---- 쓰기 ----

  Future<int> add({
    required DateTime loggedOn,
    required int severity,
    double? sleepHours,
    String? memo,
    DateTime? createdAt,
  }) {
    return into(conditionLogs).insert(
      ConditionLogsCompanion.insert(
        loggedOn: loggedOn,
        severity: severity,
        sleepHours: Value(sleepHours),
        memo: Value(memo),
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
  }

  Future<bool> updateLog(ConditionLog log) {
    return update(conditionLogs).replace(log);
  }

  Future<int> remove(int id) {
    return (delete(conditionLogs)..where((t) => t.id.equals(id))).go();
  }
}

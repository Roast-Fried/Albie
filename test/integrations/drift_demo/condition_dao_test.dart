import 'package:albi/integrations/drift_demo/condition_database.dart';
import 'package:albi/viewmodels/condition_log_viewmodel.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drift 격리 데모 DAO 테스트 — 인메모리 NativeDatabase.
void main() {
  late ConditionDatabase db;

  setUp(() {
    db = ConditionDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('insert 후 watchAll 이 length 1 을 emit', () async {
    expect(await db.getAll(), isEmpty);

    await db.add(loggedOn: DateTime(2026, 6, 1), severity: 3, sleepHours: 6.5);

    final logs = await db.watchAll().first;
    expect(logs.length, 1);
    expect(logs.first.severity, 3);
    expect(logs.first.sleepHours, 6.5);
  });

  test('update 후 severity 변경 반영', () async {
    final id =
        await db.add(loggedOn: DateTime(2026, 6, 1), severity: 2);
    final original = (await db.getAll()).single;
    expect(original.id, id);

    await db.updateLog(original.copyWith(severity: 5));

    final updated = (await db.getAll()).single;
    expect(updated.severity, 5);
  });

  test('delete 후 watchAll empty', () async {
    final id = await db.add(loggedOn: DateTime(2026, 6, 1), severity: 4);
    expect((await db.getAll()).length, 1);

    await db.remove(id);

    expect(await db.watchAll().first, isEmpty);
  });

  test('avgSeverity — derived stream + one-shot 일치', () async {
    await db.add(loggedOn: DateTime(2026, 6, 1), severity: 2);
    await db.add(loggedOn: DateTime(2026, 6, 2), severity: 4);

    expect(await db.avgSeverityOnce(), 3.0);
    expect(await db.watchAvgSeverity().first, 3.0);
  });

  test('watchAll 정렬 — loggedOn desc', () async {
    await db.add(loggedOn: DateTime(2026, 6, 1), severity: 1);
    await db.add(loggedOn: DateTime(2026, 6, 3), severity: 2);
    await db.add(loggedOn: DateTime(2026, 6, 2), severity: 3);

    final logs = await db.watchAll().first;
    expect(logs.map((e) => e.loggedOn.day).toList(), [3, 2, 1]);
  });

  test('ViewModel.add — severity 경계 보정 + sleepHours 정규화', () async {
    final vm = ConditionLogViewModel(db);
    // 경계 밖 severity 와 무효 sleepHours 가 보정되어 저장되는지
    await vm.add(loggedOn: DateTime(2026, 6, 1), severity: 9, sleepHours: -3);
    await vm.add(loggedOn: DateTime(2026, 6, 2), severity: 0, sleepHours: 99);
    final logs = await db.getAll();
    expect(logs.every((l) => l.severity >= 1 && l.severity <= 5), isTrue);
    expect(logs.every((l) => l.sleepHours == null), isTrue,
        reason: '음수/24초과 sleepHours 는 null 정규화');
  });

  test('clampSeverity / normalizeSleep 단위', () {
    expect(ConditionLogViewModel.clampSeverity(0), 1);
    expect(ConditionLogViewModel.clampSeverity(7), 5);
    expect(ConditionLogViewModel.clampSeverity(3), 3);
    expect(ConditionLogViewModel.normalizeSleep(-1), isNull);
    expect(ConditionLogViewModel.normalizeSleep(25), isNull);
    expect(ConditionLogViewModel.normalizeSleep(double.infinity), isNull);
    expect(ConditionLogViewModel.normalizeSleep(6.5), 6.5);
    expect(ConditionLogViewModel.normalizeSleep(null), isNull);
  });

  test('격리 검증 — Drift DB sqlite_master 에 production 8테이블 부재', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final tableNames = rows.map((r) => r.read<String>('name')).toSet();

    // Drift 데모 테이블만 존재해야 함
    expect(tableNames, contains('condition_logs'));
    // 기존 sqflite 메인 DB 8테이블이 섞이지 않았는지 확인
    for (final t in [
      'drinkLog',
      'drinkEntry',
      'drinkLogFood',
      'liquorMaster',
      'tastingNote',
      'parseJob',
      'aiConfig',
      'usageQuota',
    ]) {
      expect(tableNames, isNot(contains(t)), reason: '$t 가 격리 위반');
    }
  });
}

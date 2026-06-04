import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../integrations/drift_demo/condition_database.dart';

/// 컨디션 로그(Drift 데모) ViewModel.
///
/// View 는 Drift DB/DAO 를 직접 접근하지 않고 본 ViewModel 메서드만 호출한다
/// (CLAUDE.md §5 View→ViewModel 규칙). DB 인스턴스는 provider 내부에만 존재.
class ConditionLogViewModel {
  ConditionLogViewModel(this._db);

  final ConditionDatabase _db;

  /// reactive 목록 (Drift watch) — 쓰기 시 자동 갱신.
  Stream<List<ConditionLog>> watchLogs() => _db.watchAll();

  /// 평균 숙취도 reactive 스트림 (목록에서 파생).
  Stream<double> watchAvgSeverity() => _db.watchAvgSeverity();

  /// 평균 숙취도 one-shot (FutureBuilder 시연용).
  Future<double> avgSeverityOnce() => _db.avgSeverityOnce();

  Future<void> add({
    required DateTime loggedOn,
    required int severity,
    double? sleepHours,
    String? memo,
  }) {
    return _db.add(
      loggedOn: loggedOn,
      severity: clampSeverity(severity),
      sleepHours: normalizeSleep(sleepHours),
      memo: memo,
    );
  }

  Future<void> update(ConditionLog log) =>
      _db.updateLog(log.copyWith(severity: clampSeverity(log.severity)));

  /// 숙취도 경계 방어 — 1~5 범위로 보정 (UI 는 1~5만 노출하나 경계 안전).
  static int clampSeverity(int v) => v.clamp(1, 5);

  /// 수면시간 정규화 — 음수/비유한/24 초과는 null (무효 입력 방어).
  static double? normalizeSleep(double? h) {
    if (h == null) return null;
    if (!h.isFinite || h < 0 || h > 24) return null;
    return h;
  }

  Future<void> remove(int id) => _db.remove(id);
}

/// Drift DB 인스턴스 — provider 내부에서만 생성/보유. dispose 시 close.
final conditionDatabaseProvider = Provider<ConditionDatabase>((ref) {
  final db = ConditionDatabase();
  ref.onDispose(db.close);
  return db;
});

final conditionLogViewModelProvider = Provider<ConditionLogViewModel>((ref) {
  return ConditionLogViewModel(ref.watch(conditionDatabaseProvider));
});

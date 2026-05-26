import 'package:sqflite/sqflite.dart';
import '../core/exceptions.dart';
import '../domain/entities/ai_config.dart';
import '../domain/entities/usage_quota.dart';
import 'package:intl/intl.dart';

class AiConfigRepository {
  final Database _db;

  AiConfigRepository(this._db);

  Future<AiConfig> get() async {
    final rows = await _db.query('aiConfig', where: 'id = 1');
    if (rows.isEmpty) return AiConfig();
    return AiConfig.fromMap(rows.first);
  }

  Future<void> update(AiConfig config) async {
    try {
      await _db.update('aiConfig', config.toMap(), where: 'id = 1');
    } on DatabaseException catch (e) {
      throw DatabaseError('AI 설정 저장 실패', cause: e);
    }
  }

  // --- Usage Quota ---

  /// 앱 키 텍스트 quota 를 원자적으로 reserve. (Codex C4 fix, 2026-05-26)
  ///
  /// `UPDATE ... WHERE count < limit` 단일 statement 로 check + increment 를 묶어
  /// 병렬 호출 race 차단. 한도 미달이면 +1 후 true, 한도 초과면 false.
  /// app 키 분기 전용 — user 키는 본인만 사용하므로 race 없음, 기존 increment 유지.
  Future<bool> reserveAppText() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await _db.rawInsert(
        'INSERT OR IGNORE INTO usageQuota (dayKey) VALUES (?)',
        [today],
      );
      final affected = await _db.rawUpdate(
        'UPDATE usageQuota SET appDefaultTextCount = appDefaultTextCount + 1 '
        'WHERE dayKey = ? AND appDefaultTextCount < ?',
        [today, UsageQuota.maxAppTextPerDay],
      );
      return affected > 0;
    } on DatabaseException catch (e) {
      throw DatabaseError('AI 텍스트 사용량 reserve 실패', cause: e);
    }
  }

  /// 앱 키 이미지 quota 를 원자적으로 reserve. (Codex C4 fix)
  Future<bool> reserveAppImage() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await _db.rawInsert(
        'INSERT OR IGNORE INTO usageQuota (dayKey) VALUES (?)',
        [today],
      );
      final affected = await _db.rawUpdate(
        'UPDATE usageQuota SET appDefaultImageCount = appDefaultImageCount + 1 '
        'WHERE dayKey = ? AND appDefaultImageCount < ?',
        [today, UsageQuota.maxAppImagePerDay],
      );
      return affected > 0;
    } on DatabaseException catch (e) {
      throw DatabaseError('AI 이미지 사용량 reserve 실패', cause: e);
    }
  }

  Future<UsageQuota> getQuotaToday() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      // INSERT OR IGNORE: 경쟁 조건 방지
      await _db.rawInsert(
        'INSERT OR IGNORE INTO usageQuota (dayKey) VALUES (?)',
        [today],
      );
      final rows = await _db.query(
        'usageQuota',
        where: 'dayKey = ?',
        whereArgs: [today],
      );
      if (rows.isEmpty) return UsageQuota(dayKey: today);
      return UsageQuota.fromMap(rows.first);
    } on DatabaseException catch (e) {
      throw DatabaseError('AI 사용량 조회 실패', cause: e);
    }
  }

  Future<void> incrementTextCount({required bool isUserKey}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await _db.rawInsert(
        'INSERT OR IGNORE INTO usageQuota (dayKey) VALUES (?)',
        [today],
      );
      if (isUserKey) {
        await _db.rawUpdate(
          'UPDATE usageQuota SET userKeyTextCount = userKeyTextCount + 1 WHERE dayKey = ?',
          [today],
        );
      } else {
        await _db.rawUpdate(
          'UPDATE usageQuota SET appDefaultTextCount = appDefaultTextCount + 1 WHERE dayKey = ?',
          [today],
        );
      }
    } on DatabaseException catch (e) {
      throw DatabaseError('AI 텍스트 사용량 저장 실패', cause: e);
    }
  }

  Future<void> incrementImageCount({required bool isUserKey}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await _db.rawInsert(
        'INSERT OR IGNORE INTO usageQuota (dayKey) VALUES (?)',
        [today],
      );
      if (isUserKey) {
        await _db.rawUpdate(
          'UPDATE usageQuota SET userKeyImageCount = userKeyImageCount + 1 WHERE dayKey = ?',
          [today],
        );
      } else {
        await _db.rawUpdate(
          'UPDATE usageQuota SET appDefaultImageCount = appDefaultImageCount + 1 WHERE dayKey = ?',
          [today],
        );
      }
    } on DatabaseException catch (e) {
      throw DatabaseError('AI 이미지 사용량 저장 실패', cause: e);
    }
  }
}

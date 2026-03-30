import 'package:sqflite/sqflite.dart';
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
    await _db.update('aiConfig', config.toMap(), where: 'id = 1');
  }

  // --- Usage Quota ---

  Future<UsageQuota> getQuotaToday() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // INSERT OR IGNORE: 경쟁 조건 방지
    await _db.rawInsert(
      'INSERT OR IGNORE INTO usageQuota (dayKey) VALUES (?)',
      [today],
    );
    final rows = await _db.query('usageQuota',
        where: 'dayKey = ?', whereArgs: [today]);
    return UsageQuota.fromMap(rows.first);
  }

  Future<void> incrementTextCount({required bool isUserKey}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // 먼저 row 확보
    await _db.rawInsert(
      'INSERT OR IGNORE INTO usageQuota (dayKey) VALUES (?)',
      [today],
    );
    final col = isUserKey ? 'userKeyTextCount' : 'appDefaultTextCount';
    await _db.rawUpdate(
      'UPDATE usageQuota SET $col = $col + 1 WHERE dayKey = ?',
      [today],
    );
  }

  Future<void> incrementImageCount({required bool isUserKey}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _db.rawInsert(
      'INSERT OR IGNORE INTO usageQuota (dayKey) VALUES (?)',
      [today],
    );
    final col = isUserKey ? 'userKeyImageCount' : 'appDefaultImageCount';
    await _db.rawUpdate(
      'UPDATE usageQuota SET $col = $col + 1 WHERE dayKey = ?',
      [today],
    );
  }
}

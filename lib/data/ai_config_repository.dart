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
    final rows = await _db.query('usageQuota',
        where: 'dayKey = ?', whereArgs: [today]);

    if (rows.isEmpty) {
      final id = await _db.insert('usageQuota', {'dayKey': today});
      return UsageQuota(id: id, dayKey: today);
    }
    return UsageQuota.fromMap(rows.first);
  }

  Future<void> incrementTextCount({required bool isUserKey}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final col = isUserKey ? 'userKeyTextCount' : 'appDefaultTextCount';
    await _db.rawUpdate(
      'UPDATE usageQuota SET $col = $col + 1 WHERE dayKey = ?',
      [today],
    );
  }

  Future<void> incrementImageCount({required bool isUserKey}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final col = isUserKey ? 'userKeyImageCount' : 'appDefaultImageCount';
    await _db.rawUpdate(
      'UPDATE usageQuota SET $col = $col + 1 WHERE dayKey = ?',
      [today],
    );
  }
}

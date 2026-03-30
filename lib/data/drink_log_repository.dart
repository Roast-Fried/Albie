import 'package:sqflite/sqflite.dart';
import '../domain/entities/drink_log.dart';

class DrinkLogRepository {
  final Database _db;

  DrinkLogRepository(this._db);

  /// 전체 저장: log + entries + foods 트랜잭션
  Future<int> save(DrinkLog log) async {
    return _db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // 1. drinkLog INSERT
      final logId = await txn.insert('drinkLog', {
        ...log.toMap(),
        'updatedAt': now,
      });

      // 2. entries INSERT
      for (final entry in log.entries) {
        await txn.insert('drinkEntry', {
          ...entry.toMap(),
          'logId': logId,
          'updatedAt': now,
        });
      }

      // 3. foods INSERT
      for (final food in log.foodItems) {
        await txn.insert('drinkLogFood', {
          'logId': logId,
          'foodName': food,
        });
      }

      return logId;
    });
  }

  /// 전체 업데이트: 기존 entries/foods 삭제 후 재삽입
  Future<void> update(DrinkLog log) async {
    if (log.id == null) return;
    await _db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      await txn.update('drinkLog', {...log.toMap(), 'updatedAt': now},
          where: 'id = ?', whereArgs: [log.id]);

      // entries 재삽입
      await txn.delete('drinkEntry', where: 'logId = ?', whereArgs: [log.id]);
      for (final entry in log.entries) {
        await txn.insert('drinkEntry', {
          ...entry.toMap(),
          'logId': log.id,
          'updatedAt': now,
        });
      }

      // foods 재삽입
      await txn.delete('drinkLogFood',
          where: 'logId = ?', whereArgs: [log.id]);
      for (final food in log.foodItems) {
        await txn.insert('drinkLogFood', {
          'logId': log.id,
          'foodName': food,
        });
      }
    });
  }

  Future<void> delete(int logId) async {
    await _db.delete('drinkLog', where: 'id = ?', whereArgs: [logId]);
  }

  /// 단건 조회 (entries + foods 포함)
  Future<DrinkLog?> getById(int logId) async {
    final rows =
        await _db.query('drinkLog', where: 'id = ?', whereArgs: [logId]);
    if (rows.isEmpty) return null;

    final log = DrinkLog.fromMap(rows.first);
    final entries = await _getEntries(logId);
    final foods = await _getFoods(logId);

    return log.copyWith(entries: entries, foodItems: foods);
  }

  /// 목록 조회 (최신순, entries 포함)
  Future<List<DrinkLog>> getAll({int? limit, int? offset}) async {
    final rows = await _db.query('drinkLog',
        orderBy: 'drankAt DESC', limit: limit, offset: offset);

    final logs = <DrinkLog>[];
    for (final row in rows) {
      final log = DrinkLog.fromMap(row);
      final entries = await _getEntries(log.id!);
      final foods = await _getFoods(log.id!);
      logs.add(log.copyWith(entries: entries, foodItems: foods));
    }
    return logs;
  }

  /// 검색
  Future<List<DrinkLog>> search(String keyword) async {
    final k = '%$keyword%';
    final rows = await _db.rawQuery('''
      SELECT DISTINCT dl.* FROM drinkLog dl
      LEFT JOIN drinkEntry de ON de.logId = dl.id
      LEFT JOIN drinkLogFood df ON df.logId = dl.id
      WHERE dl.rawInputText LIKE ?
         OR de.liquorNameRaw LIKE ?
         OR dl.place LIKE ?
         OR df.foodName LIKE ?
      ORDER BY dl.drankAt DESC
    ''', [k, k, k, k]);

    final logs = <DrinkLog>[];
    for (final row in rows) {
      final log = DrinkLog.fromMap(row);
      final entries = await _getEntries(log.id!);
      final foods = await _getFoods(log.id!);
      logs.add(log.copyWith(entries: entries, foodItems: foods));
    }
    return logs;
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as cnt FROM drinkLog');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // --- private helpers ---

  Future<List<DrinkEntry>> _getEntries(int logId) async {
    final rows = await _db.query('drinkEntry',
        where: 'logId = ?', whereArgs: [logId], orderBy: 'id ASC');
    return rows.map((r) => DrinkEntry.fromMap(r)).toList();
  }

  Future<List<String>> _getFoods(int logId) async {
    final rows = await _db.query('drinkLogFood',
        where: 'logId = ?', whereArgs: [logId]);
    return rows.map((r) => r['foodName'] as String).toList();
  }
}

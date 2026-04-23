import 'package:sqflite/sqflite.dart';
import '../core/exceptions.dart';
import '../domain/entities/drink_log.dart';

class DrinkLogRepository {
  final Database _db;

  DrinkLogRepository(this._db);

  /// 전체 저장: log + entries + foods 트랜잭션
  Future<int> save(DrinkLog log) async {
    try {
      return await _db.transaction((txn) async {
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
    } on DatabaseException catch (e) {
      throw DatabaseError('음주 기록 저장 실패', cause: e);
    }
  }

  /// 전체 업데이트: 기존 entries/foods 삭제 후 재삽입
  Future<void> update(DrinkLog log) async {
    if (log.id == null) return;
    try {
      await _db.transaction((txn) async {
        final now = DateTime.now().toIso8601String();

        await txn.update('drinkLog', {...log.toMap(), 'updatedAt': now},
            where: 'id = ?', whereArgs: [log.id]);

        // entries 재삽입
        await txn
            .delete('drinkEntry', where: 'logId = ?', whereArgs: [log.id]);
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
    } on DatabaseException catch (e) {
      throw DatabaseError('음주 기록 수정 실패', cause: e);
    }
  }

  Future<void> delete(int logId) async {
    try {
      await _db.delete('drinkLog', where: 'id = ?', whereArgs: [logId]);
    } on DatabaseException catch (e) {
      throw DatabaseError('음주 기록 삭제 실패', cause: e);
    }
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

  /// 목록 조회 (최신순, 배치 로딩으로 N+1 해소)
  Future<List<DrinkLog>> getAll({int? limit, int? offset}) async {
    final rows = await _db.query('drinkLog',
        orderBy: 'drankAt DESC', limit: limit, offset: offset);
    if (rows.isEmpty) return [];

    return _attachRelations(rows);
  }

  /// 검색 (배치 로딩)
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
    if (rows.isEmpty) return [];

    return _attachRelations(rows);
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as cnt FROM drinkLog');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // --- private helpers ---

  /// 배치 로딩: log 목록에 entries + foods 를 IN 절로 한번에 조회
  Future<List<DrinkLog>> _attachRelations(
      List<Map<String, dynamic>> rows) async {
    final logIds = <int>[];
    for (final row in rows) {
      final id = row['id'] as int?;
      if (id != null) logIds.add(id);
    }
    if (logIds.isEmpty) return rows.map((r) => DrinkLog.fromMap(r)).toList();

    final ph = List.filled(logIds.length, '?').join(',');

    // entries 배치 조회
    final entriesRows = await _db.rawQuery(
        'SELECT * FROM drinkEntry WHERE logId IN ($ph) ORDER BY logId, id',
        logIds);
    final entriesByLog = <int, List<DrinkEntry>>{};
    for (final row in entriesRows) {
      final logId = row['logId'] as int;
      entriesByLog.putIfAbsent(logId, () => []).add(DrinkEntry.fromMap(row));
    }

    // foods 배치 조회
    final foodsRows = await _db.rawQuery(
        'SELECT * FROM drinkLogFood WHERE logId IN ($ph)', logIds);
    final foodsByLog = <int, List<String>>{};
    for (final row in foodsRows) {
      final logId = row['logId'] as int;
      foodsByLog
          .putIfAbsent(logId, () => [])
          .add(row['foodName'] as String);
    }

    return rows.map((row) {
      final log = DrinkLog.fromMap(row);
      return log.copyWith(
        entries: entriesByLog[log.id] ?? [],
        foodItems: foodsByLog[log.id] ?? [],
      );
    }).toList();
  }

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

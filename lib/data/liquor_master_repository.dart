import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/entities/liquor_master.dart';

class LiquorMasterRepository {
  final Database _db;

  LiquorMasterRepository(this._db);

  Future<List<LiquorMaster>> getAll() async {
    final rows = await _db.query('liquorMaster', orderBy: 'canonicalName ASC');
    return rows.map((r) => LiquorMaster.fromMap(r)).toList();
  }

  Future<List<LiquorMaster>> getByCategory(String category) async {
    final rows = await _db.query('liquorMaster',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'canonicalName ASC');
    return rows.map((r) => LiquorMaster.fromMap(r)).toList();
  }

  Future<LiquorMaster?> getById(int id) async {
    final rows =
        await _db.query('liquorMaster', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return LiquorMaster.fromMap(rows.first);
  }

  /// 이름으로 검색 (canonicalName, nameKo, aliases 전부)
  Future<List<LiquorMaster>> search(String keyword) async {
    final k = '%$keyword%';
    final rows = await _db.query('liquorMaster',
        where: 'canonicalName LIKE ? OR nameKo LIKE ? OR aliasesJson LIKE ?',
        whereArgs: [k, k, k],
        orderBy: 'canonicalName ASC');
    return rows.map((r) => LiquorMaster.fromMap(r)).toList();
  }

  /// 정확한 alias 매칭 (로컬 파서용)
  Future<LiquorMaster?> findByAlias(String alias) async {
    final all = await _db.query('liquorMaster');
    final lower = alias.toLowerCase();

    for (final row in all) {
      // canonicalName 매칭
      if ((row['canonicalName'] as String).toLowerCase() == lower) {
        return LiquorMaster.fromMap(row);
      }
      // nameKo 매칭
      if (row['nameKo'] != null &&
          (row['nameKo'] as String).toLowerCase() == lower) {
        return LiquorMaster.fromMap(row);
      }
      // aliases 매칭
      final aliasesRaw = row['aliasesJson'] as String?;
      if (aliasesRaw != null) {
        try {
          final aliases = (jsonDecode(aliasesRaw) as List).cast<String>();
          if (aliases.any((a) => a.toLowerCase() == lower)) {
            return LiquorMaster.fromMap(row);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// 부분 매칭 (로컬 파서용) — 포함 관계
  Future<LiquorMaster?> findByPartialMatch(String keyword) async {
    final all = await _db.query('liquorMaster');
    final lower = keyword.toLowerCase();

    for (final row in all) {
      if ((row['canonicalName'] as String).toLowerCase().contains(lower)) {
        return LiquorMaster.fromMap(row);
      }
      if (row['nameKo'] != null &&
          (row['nameKo'] as String).toLowerCase().contains(lower)) {
        return LiquorMaster.fromMap(row);
      }
      final aliasesRaw = row['aliasesJson'] as String?;
      if (aliasesRaw != null) {
        try {
          final aliases = (jsonDecode(aliasesRaw) as List).cast<String>();
          if (aliases.any((a) => a.toLowerCase().contains(lower))) {
            return LiquorMaster.fromMap(row);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Future<int> insert(LiquorMaster master) async {
    return _db.insert('liquorMaster', master.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> toggleFavorite(int id, bool isFavorite) async {
    await _db.update('liquorMaster', {'isFavorite': isFavorite ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// alias 학습: 기존 마스터에 새 alias 추가
  Future<void> addAlias(int id, String newAlias) async {
    final master = await getById(id);
    if (master == null) return;
    if (master.aliases.contains(newAlias)) return;

    final updated = [...master.aliases, newAlias];
    await _db.update('liquorMaster', {'aliasesJson': jsonEncode(updated)},
        where: 'id = ?', whereArgs: [id]);
  }
}

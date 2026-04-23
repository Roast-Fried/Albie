import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../core/exceptions.dart';
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
  /// 인덱스 활용 → alias JSON 스캔 순으로 탐색
  Future<LiquorMaster?> findByAlias(String alias) async {
    final lower = alias.toLowerCase();

    // 1단계: canonicalName/nameKo 정확 매칭 (인덱스 활용)
    final exact = await _db.query('liquorMaster',
        where: 'LOWER(canonicalName) = ? OR LOWER(nameKo) = ?',
        whereArgs: [lower, lower]);
    if (exact.isNotEmpty) return LiquorMaster.fromMap(exact.first);

    // 2단계: aliasesJson 내 검색 (LIKE 사전 필터 → Dart 정확 매칭)
    final candidates = await _db.query('liquorMaster',
        where: 'LOWER(aliasesJson) LIKE ?',
        whereArgs: ['%$lower%']);
    for (final row in candidates) {
      final aliasesRaw = row['aliasesJson'] as String?;
      if (aliasesRaw != null) {
        try {
          final aliases = (jsonDecode(aliasesRaw) as List).cast<String>();
          if (aliases.any((a) => a.toLowerCase() == lower)) {
            return LiquorMaster.fromMap(row);
          }
        } on FormatException catch (_) {}
      }
    }
    return null;
  }

  /// 부분 매칭 (로컬 파서용) — 포함 관계
  /// 인덱스 활용 → alias JSON 스캔 순으로 탐색
  Future<LiquorMaster?> findByPartialMatch(String keyword) async {
    final lower = keyword.toLowerCase();

    // 1단계: canonicalName/nameKo 부분 매칭
    final exact = await _db.query('liquorMaster',
        where: 'LOWER(canonicalName) LIKE ? OR LOWER(nameKo) LIKE ?',
        whereArgs: ['%$lower%', '%$lower%']);
    if (exact.isNotEmpty) return LiquorMaster.fromMap(exact.first);

    // 2단계: aliasesJson 내 부분 매칭
    final candidates = await _db.query('liquorMaster',
        where: 'LOWER(aliasesJson) LIKE ?',
        whereArgs: ['%$lower%']);
    for (final row in candidates) {
      final aliasesRaw = row['aliasesJson'] as String?;
      if (aliasesRaw != null) {
        try {
          final aliases = (jsonDecode(aliasesRaw) as List).cast<String>();
          if (aliases.any((a) => a.toLowerCase().contains(lower))) {
            return LiquorMaster.fromMap(row);
          }
        } on FormatException catch (_) {}
      }
    }
    return null;
  }

  Future<int> insert(LiquorMaster master) async {
    try {
      return await _db.insert('liquorMaster', master.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } on DatabaseException catch (e) {
      throw DatabaseError('주류 마스터 추가 실패', cause: e);
    }
  }

  Future<void> toggleFavorite(int id, bool isFavorite) async {
    try {
      await _db.update('liquorMaster', {'isFavorite': isFavorite ? 1 : 0},
          where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      throw DatabaseError('즐겨찾기 변경 실패', cause: e);
    }
  }

  /// alias 학습: 기존 마스터에 새 alias 추가
  Future<void> addAlias(int id, String newAlias) async {
    final master = await getById(id);
    if (master == null) return;
    if (master.aliases.contains(newAlias)) return;

    final updated = [...master.aliases, newAlias];
    try {
      await _db.update('liquorMaster', {'aliasesJson': jsonEncode(updated)},
          where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      throw DatabaseError('별칭 저장 실패', cause: e);
    }
  }
}

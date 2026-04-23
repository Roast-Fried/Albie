import 'package:sqflite/sqflite.dart';
import '../core/exceptions.dart';
import '../domain/entities/tasting_note.dart';

class TastingNoteRepository {
  final Database _db;

  TastingNoteRepository(this._db);

  Future<int> save(TastingNote note) async {
    try {
      return await _db.transaction((txn) async {
        final existing = await txn.query('tastingNote',
            where: 'entryId = ?', whereArgs: [note.entryId]);

        if (existing.isEmpty) {
          return txn.insert('tastingNote', note.toMap());
        } else {
          await txn.update('tastingNote', note.toMap(),
              where: 'entryId = ?', whereArgs: [note.entryId]);
          return existing.first['id'] as int;
        }
      });
    } on DatabaseException catch (e) {
      throw DatabaseError('시음 노트 저장 실패', cause: e);
    }
  }

  Future<TastingNote?> getByEntryId(int entryId) async {
    final rows = await _db.query('tastingNote',
        where: 'entryId = ?', whereArgs: [entryId]);
    if (rows.isEmpty) return null;
    return TastingNote.fromMap(rows.first);
  }

  /// 여러 entry id 의 테이스팅 노트 일괄 조회 (아카이브 상세 집계용).
  Future<List<TastingNote>> getByEntryIds(List<int> entryIds) async {
    if (entryIds.isEmpty) return [];
    final placeholders = List.filled(entryIds.length, '?').join(',');
    final rows = await _db.query('tastingNote',
        where: 'entryId IN ($placeholders)', whereArgs: entryIds);
    return rows.map(TastingNote.fromMap).toList();
  }

  Future<void> delete(int entryId) async {
    try {
      await _db.delete('tastingNote',
          where: 'entryId = ?', whereArgs: [entryId]);
    } on DatabaseException catch (e) {
      throw DatabaseError('시음 노트 삭제 실패', cause: e);
    }
  }
}

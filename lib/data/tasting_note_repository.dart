import 'package:sqflite/sqflite.dart';
import '../domain/entities/tasting_note.dart';

class TastingNoteRepository {
  final Database _db;

  TastingNoteRepository(this._db);

  Future<int> save(TastingNote note) async {
    // upsert: entryId 기준 1:1
    final existing = await _db.query('tastingNote',
        where: 'entryId = ?', whereArgs: [note.entryId]);

    if (existing.isEmpty) {
      return _db.insert('tastingNote', note.toMap());
    } else {
      await _db.update('tastingNote', note.toMap(),
          where: 'entryId = ?', whereArgs: [note.entryId]);
      return existing.first['id'] as int;
    }
  }

  Future<TastingNote?> getByEntryId(int entryId) async {
    final rows = await _db.query('tastingNote',
        where: 'entryId = ?', whereArgs: [entryId]);
    if (rows.isEmpty) return null;
    return TastingNote.fromMap(rows.first);
  }

  Future<void> delete(int entryId) async {
    await _db.delete('tastingNote',
        where: 'entryId = ?', whereArgs: [entryId]);
  }
}

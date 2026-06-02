import 'package:albi/data/drink_log_repository.dart';
import 'package:albi/domain/entities/drink_log.dart';
import 'package:albi/domain/entities/tasting_note.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _openTestDb() {
  return openDatabase(
    inMemoryDatabasePath,
    version: 1,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE drinkLog (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          rawInputText TEXT, rawImagePath TEXT,
          parseSource TEXT NOT NULL DEFAULT 'manual',
          place TEXT, overallMemo TEXT, drankAt TEXT NOT NULL,
          userConfirmedAt TEXT, createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE drinkEntry (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          logId INTEGER NOT NULL REFERENCES drinkLog(id) ON DELETE CASCADE,
          liquorMasterId INTEGER,
          liquorNameRaw TEXT NOT NULL,
          liquorCategory TEXT NOT NULL DEFAULT 'other', ageStatement TEXT,
          quantityValue REAL NOT NULL DEFAULT 1.0,
          quantityUnit TEXT NOT NULL DEFAULT 'glass',
          isEstimated INTEGER NOT NULL DEFAULT 1, alcoholPercent REAL,
          createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE drinkLogFood (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          logId INTEGER NOT NULL REFERENCES drinkLog(id) ON DELETE CASCADE,
          foodName TEXT NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE tastingNote (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entryId INTEGER NOT NULL UNIQUE REFERENCES drinkEntry(id) ON DELETE CASCADE,
          nose TEXT, palate TEXT, finish TEXT, rating REAL, note TEXT,
          createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL
        )''');
      await db.execute('''
        CREATE TABLE parseJob (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          logId INTEGER REFERENCES drinkLog(id) ON DELETE SET NULL,
          rawRequest TEXT, rawResponse TEXT, errorMessage TEXT
        )''');
    },
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('restoreReplaceAll — 기존 전체 교체 + entries/foods/note 재구성', () async {
    final db = await _openTestDb();
    final repo = DrinkLogRepository(db);

    // 교체될 기존 데이터
    await repo.save(
      DrinkLog(
        rawInputText: 'OLD',
        drankAt: DateTime(2020, 1, 1),
        entries: [DrinkEntry(liquorNameRaw: '기존술')],
      ),
    );
    expect((await repo.getAll()).length, 1);

    await repo.restoreReplaceAll(
      [
        DrinkLog(
          rawInputText: 'NEW',
          place: '집',
          drankAt: DateTime(2026, 5, 12, 20),
          foodItems: const ['치즈'],
          entries: [DrinkEntry(liquorNameRaw: '글렌피딕', quantityValue: 2)],
        ),
      ],
      [
        [TastingNote(entryId: 0, nose: '배', rating: 4.5)],
      ],
    );

    final all = await repo.getAll();
    expect(all.length, 1); // OLD 사라지고 NEW 만
    expect(all.first.rawInputText, 'NEW');
    expect(all.first.place, '집');
    expect(all.first.foodItems, ['치즈']);
    expect(all.first.entries.single.liquorNameRaw, '글렌피딕');

    // 테이스팅 노트가 새 entryId 에 재연결됐는지
    final newEntryId = all.first.entries.single.id!;
    final notes = await db.query(
      'tastingNote',
      where: 'entryId = ?',
      whereArgs: [newEntryId],
    );
    expect(notes.length, 1);
    expect(notes.first['nose'], '배');
    expect(notes.first['rating'], 4.5);

    await db.close();
  });

  test('restoreReplaceAll([]) — 빈 백업은 전체 비우기', () async {
    final db = await _openTestDb();
    final repo = DrinkLogRepository(db);
    await repo.save(DrinkLog(rawInputText: 'X', drankAt: DateTime(2020, 1, 1)));
    await repo.restoreReplaceAll([], []);
    expect(await repo.getAll(), isEmpty);
    await db.close();
  });
}

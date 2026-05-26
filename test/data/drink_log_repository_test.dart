import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:albi/core/exceptions.dart';
import 'package:albi/data/drink_log_repository.dart';
import 'package:albi/domain/entities/drink_log.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });


  group('DrinkLog serialization', () {
    test('toMap/fromMap roundtrip', () {
      final log = DrinkLog(
        rawInputText: '벤로막 15 두 잔',
        parseSource: 'local_parser',
        place: '바',
        drankAt: DateTime(2026, 3, 29, 23, 30),
      );

      final map = log.toMap();
      final restored = DrinkLog.fromMap({
        ...map,
        'id': 1,
      });

      expect(restored.rawInputText, '벤로막 15 두 잔');
      expect(restored.parseSource, 'local_parser');
      expect(restored.place, '바');
      expect(restored.drankAt.day, 29);
    });

    test('copyWith preserves unchanged fields', () {
      final log = DrinkLog(
        rawInputText: 'test',
        drankAt: DateTime.now(),
        place: '집',
      );

      final modified = log.copyWith(place: '바');
      expect(modified.place, '바');
      expect(modified.rawInputText, 'test');
    });

    test('copyWith(place: null) explicitly clears place', () {
      final log = DrinkLog(
        rawInputText: 'test',
        drankAt: DateTime.now(),
        place: '집',
        overallMemo: '기분 좋음',
      );

      final cleared = log.copyWith(place: null);
      expect(cleared.place, isNull);
      // 다른 필드는 영향 없음
      expect(cleared.overallMemo, '기분 좋음');
      expect(cleared.rawInputText, 'test');
    });

    test('copyWith(overallMemo: null) explicitly clears memo', () {
      final log = DrinkLog(
        rawInputText: 'test',
        drankAt: DateTime.now(),
        place: '집',
        overallMemo: '기분 좋음',
      );

      final cleared = log.copyWith(overallMemo: null);
      expect(cleared.overallMemo, isNull);
      expect(cleared.place, '집');
    });

    test('copyWith() without place arg preserves existing place', () {
      // sentinel 회귀 — 인자 미지정 시 null 로 덮어쓰면 안 됨
      final log = DrinkLog(
        rawInputText: 'test',
        drankAt: DateTime.now(),
        place: '바',
      );

      final modified = log.copyWith(rawInputText: 'changed');
      expect(modified.place, '바');
      expect(modified.rawInputText, 'changed');
    });
  });

  group('DrinkLogRepository.update — id 검증', () {
    test('log.id == null 이면 ValidationError 를 던진다 (silent no-op 금지)', () async {
      final db = await openDatabase(inMemoryDatabasePath);
      try {
        final repo = DrinkLogRepository(db);
        final log = DrinkLog(drankAt: DateTime(2026, 5, 18));
        // id 가 null — DB 접근 전에 throw 되어야 함
        expect(
          () => repo.update(log),
          throwsA(isA<ValidationError>()),
        );
      } finally {
        await db.close();
      }
    });

    // 2026-05-26 /goal HIGH 4 (Codex C5): 존재하지 않는 id 로 update 시
    // txn.update 의 affected row 가 0 이면 ValidationError throw (silent no-op 금지).
    test('존재하지 않는 id 로 update 호출 시 ValidationError 를 던진다', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE drinkLog (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              rawInputText TEXT,
              rawImagePath TEXT,
              parseSource TEXT NOT NULL DEFAULT 'manual',
              place TEXT,
              overallMemo TEXT,
              drankAt TEXT NOT NULL,
              userConfirmedAt TEXT,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE drinkEntry (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              logId INTEGER NOT NULL,
              liquorMasterId INTEGER,
              liquorNameRaw TEXT NOT NULL,
              liquorCategory TEXT NOT NULL DEFAULT 'other',
              ageStatement TEXT,
              quantityValue REAL NOT NULL DEFAULT 1.0,
              quantityUnit TEXT NOT NULL DEFAULT 'glass',
              isEstimated INTEGER NOT NULL DEFAULT 1,
              alcoholPercent REAL,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE drinkLogFood (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              logId INTEGER NOT NULL,
              foodName TEXT NOT NULL
            )
          ''');
        },
      );
      try {
        final repo = DrinkLogRepository(db);
        final log = DrinkLog(
          id: 99999,
          rawInputText: 'phantom',
          drankAt: DateTime(2026, 5, 18),
        );

        expect(
          () => repo.update(log),
          throwsA(isA<ValidationError>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('99999'),
          )),
          reason: 'Codex C5 fix: nonexistent id 는 silent no-op 대신 ValidationError',
        );

        // 실패 시에도 entry 가 부분 삽입되지 않았는지 확인 (트랜잭션 rollback)
        final entries = await db.query('drinkEntry');
        expect(entries, isEmpty, reason: '트랜잭션 rollback 으로 entry 부분 삽입 없음');
      } finally {
        await db.close();
      }
    });
  });

  group('DrinkLogRepository.delete — 개인정보 cleanup', () {
    test('단일 기록 삭제 시 parseJob.rawRequest/rawResponse/errorMessage 가 NULL 로 정리된다',
        () async {
      // 2026-05-18 /goal CRITICAL 4 잔여: FK ON DELETE SET NULL 만으로는
      // parseJob 행의 raw 컬럼이 영구 잔류 → DrinkLogRepository.delete 가 명시적
      // cleanup 해야 함.
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE drinkLog (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              rawInputText TEXT,
              rawImagePath TEXT,
              parseSource TEXT NOT NULL DEFAULT 'manual',
              place TEXT,
              overallMemo TEXT,
              drankAt TEXT NOT NULL,
              userConfirmedAt TEXT,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE drinkEntry (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              logId INTEGER NOT NULL REFERENCES drinkLog(id) ON DELETE CASCADE,
              liquorMasterId INTEGER,
              liquorNameRaw TEXT NOT NULL,
              liquorCategory TEXT NOT NULL DEFAULT 'other',
              ageStatement TEXT,
              quantityValue REAL NOT NULL DEFAULT 1.0,
              quantityUnit TEXT NOT NULL DEFAULT 'glass',
              isEstimated INTEGER NOT NULL DEFAULT 1,
              alcoholPercent REAL,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE drinkLogFood (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              logId INTEGER NOT NULL REFERENCES drinkLog(id) ON DELETE CASCADE,
              foodName TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE parseJob (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              logId INTEGER REFERENCES drinkLog(id) ON DELETE SET NULL,
              sourceType TEXT NOT NULL,
              parserUsed TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'success',
              rawRequest TEXT,
              rawResponse TEXT,
              errorCode TEXT,
              errorMessage TEXT,
              durationMs INTEGER,
              createdAt TEXT NOT NULL
            )
          ''');
        },
      );
      try {
        final now = DateTime.now().toIso8601String();
        final logId = await db.insert('drinkLog', {
          'rawInputText': '시크릿 입력',
          'parseSource': 'ai_app_key',
          'drankAt': now,
          'createdAt': now,
          'updatedAt': now,
        });
        // 같은 log 에 연결된 parseJob 두 행 — raw 컬럼 + 메타데이터 모두 채움
        await db.insert('parseJob', {
          'logId': logId,
          'sourceType': 'text',
          'parserUsed': 'ai_app_key',
          'status': 'success',
          'rawRequest': '소주 한 잔', // 개인정보
          'rawResponse': '{...}',
          'errorMessage': '개인 식별 가능 텍스트',
          'durationMs': 1234,
          'createdAt': now,
        });

        final repo = DrinkLogRepository(db);
        await repo.delete(logId);

        // drinkLog 삭제 확인
        final logRows = await db.query('drinkLog', where: 'id = ?', whereArgs: [logId]);
        expect(logRows, isEmpty);

        // parseJob 행은 (logId 가 NULL 되어) 유지되지만 raw 컬럼은 모두 NULL
        final jobRows = await db.query('parseJob');
        expect(jobRows.length, 1, reason: 'parseJob 행은 메타데이터 보존');
        expect(jobRows.first['rawRequest'], isNull);
        expect(jobRows.first['rawResponse'], isNull);
        expect(jobRows.first['errorMessage'], isNull);
        // 통계 메타데이터는 보존
        expect(jobRows.first['parserUsed'], 'ai_app_key');
        expect(jobRows.first['status'], 'success');
        expect(jobRows.first['durationMs'], 1234);
      } finally {
        await db.close();
      }
    });
  });

  group('DrinkEntry serialization', () {
    test('toMap/fromMap roundtrip', () {
      final entry = DrinkEntry(
        liquorNameRaw: '벤로마크',
        liquorCategory: 'whisky',
        ageStatement: '15년',
        quantityValue: 2.0,
        quantityUnit: 'glass',
        isEstimated: false,
        alcoholPercent: 43.0,
      );

      final map = entry.toMap();
      final restored = DrinkEntry.fromMap({...map, 'id': 1, 'logId': 1});

      expect(restored.liquorNameRaw, '벤로마크');
      expect(restored.liquorCategory, 'whisky');
      expect(restored.ageStatement, '15년');
      expect(restored.quantityValue, 2.0);
      expect(restored.isEstimated, false);
      expect(restored.alcoholPercent, 43.0);
    });

    test('boolean conversion int<->bool', () {
      final entry = DrinkEntry(
        liquorNameRaw: 'test',
        isEstimated: true,
      );
      final map = entry.toMap();
      expect(map['isEstimated'], 1);

      final restored = DrinkEntry.fromMap({
        ...map,
        'id': 1,
        'logId': 1,
      });
      expect(restored.isEstimated, true);
    });
  });
}

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

import 'package:flutter_test/flutter_test.dart';
import 'package:albi/domain/entities/drink_log.dart';

void main() {
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

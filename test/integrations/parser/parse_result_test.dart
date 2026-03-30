import 'package:flutter_test/flutter_test.dart';
import 'package:albi/integrations/parser/parse_result.dart';

void main() {
  group('DraftEntry', () {
    test('toJson/fromJson roundtrip', () {
      final entry = DraftEntry(
        liquorName: '벤로마크',
        liquorNameRaw: '벤로마크',
        liquorCategory: 'whisky',
        ageStatement: '15년',
        quantityValue: 2.0,
        quantityUnit: 'glass',
        isEstimated: false,
        alcoholPercent: 43.0,
      );

      final json = entry.toJson();
      final restored = DraftEntry.fromJson(json);

      expect(restored.liquorName, '벤로마크');
      expect(restored.liquorCategory, 'whisky');
      expect(restored.quantityValue, 2.0);
      expect(restored.isEstimated, false);
    });

    test('fromJson with missing fields uses defaults', () {
      final entry = DraftEntry.fromJson({});
      expect(entry.liquorCategory, 'other');
      expect(entry.quantityValue, 1.0);
      expect(entry.quantityUnit, 'glass');
      expect(entry.isEstimated, true);
    });
  });

  group('ParseResult', () {
    test('empty factory creates minimal result', () {
      final result = ParseResult.empty(warnings: ['테스트 경고']);
      expect(result.source, 'local_parser');
      expect(result.confidence, 0.0);
      expect(result.parseWarnings, ['테스트 경고']);
      expect(result.entries.length, 1);
    });

    test('copyWith overrides selected fields', () {
      final original = ParseResult(
        source: 'local_parser',
        confidence: 0.5,
        place: '집',
      );
      final modified = original.copyWith(place: '바', confidence: 0.8);
      expect(modified.place, '바');
      expect(modified.confidence, 0.8);
      expect(modified.source, 'local_parser'); // 변경 안 됨
    });
  });
}

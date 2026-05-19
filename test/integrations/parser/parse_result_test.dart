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

    test('fromJson 빈 문자열 liquorName 은 null 로 정규화된다', () {
      // 2026-05-18 /goal: AI 가 liquorName 을 "" 로 반환해도 UI 가 placeholder
      // 처리할 수 있도록 nullable 로 정규화. liquorNameRaw 도 null fallback.
      final entry = DraftEntry.fromJson({
        'liquorName': '',
        'liquorCategory': 'beer',
        'quantityValue': 1.0,
        'quantityUnit': 'can',
        'isEstimated': false,
      });
      expect(entry.liquorName, isNull);
      expect(entry.liquorNameRaw, '');
      expect(entry.liquorCategory, 'beer');
    });

    test('fromJson 공백만의 liquorName 도 null 로 정규화된다', () {
      final entry = DraftEntry.fromJson({
        'liquorName': '   ',
        'liquorCategory': 'other',
      });
      expect(entry.liquorName, isNull);
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

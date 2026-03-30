import 'package:flutter_test/flutter_test.dart';
import 'package:albi/core/utils/date_utils.dart';

void main() {
  group('applySixHourCutoff', () {
    test('새벽 2시 → 전날', () {
      final input = DateTime(2026, 3, 30, 2, 0);
      final result = applySixHourCutoff(input);
      expect(result.day, 29);
      expect(result.hour, 2);
    });

    test('새벽 5시59분 → 전날', () {
      final input = DateTime(2026, 3, 30, 5, 59);
      final result = applySixHourCutoff(input);
      expect(result.day, 29);
    });

    test('오전 6시 → 당일 유지', () {
      final input = DateTime(2026, 3, 30, 6, 0);
      final result = applySixHourCutoff(input);
      expect(result.day, 30);
    });

    test('밤 11시 → 당일 유지', () {
      final input = DateTime(2026, 3, 29, 23, 30);
      final result = applySixHourCutoff(input);
      expect(result.day, 29);
    });
  });

  group('parseRelativeDate', () {
    final now = DateTime(2026, 3, 30, 22, 0);

    test('"어제" → 3/29', () {
      final result = parseRelativeDate('어제 마심', now);
      expect(result, isNotNull);
      expect(result!.day, 29);
    });

    test('"그저께" → 3/28', () {
      final result = parseRelativeDate('그저께 마셨어', now);
      expect(result, isNotNull);
      expect(result!.day, 28);
    });

    test('"그제" → 3/28', () {
      final result = parseRelativeDate('그제 바에서', now);
      expect(result, isNotNull);
      expect(result!.day, 28);
    });

    test('관련 없는 텍스트 → null', () {
      final result = parseRelativeDate('벤로막 15 두 잔', now);
      expect(result, isNull);
    });
  });
}

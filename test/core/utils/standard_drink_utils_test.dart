import 'package:flutter_test/flutter_test.dart';
import 'package:albi/core/utils/standard_drink_utils.dart';

void main() {
  group('calcPureAlcohol', () {
    test('맥주 355mL 5도 → 약 14.0g 순알코올', () {
      final result = calcPureAlcohol(355, 5.0);
      // 355 * 0.05 * 0.7894 ≈ 14.01g
      expect(result, closeTo(14.01, 0.1));
    });

    test('소주 50mL 25도 → 약 9.87g 순알코올', () {
      final result = calcPureAlcohol(50, 25.0);
      // 50 * 0.25 * 0.7894 ≈ 9.87g
      expect(result, closeTo(9.87, 0.1));
    });

    test('도수 0이면 0g', () {
      expect(calcPureAlcohol(500, 0.0), 0.0);
    });
  });

  group('calcStandardDrinks', () {
    test('맥주 355mL 5도 → 약 1.75 표준잔', () {
      final result = calcStandardDrinks(355, 5.0);
      // ≈ 14.01 / 8.0 ≈ 1.75
      expect(result, closeTo(1.75, 0.05));
    });

    test('1 표준잔 정확 계산: 101.35mL 10도 ≈ 1.0 표준잔', () {
      // 8.0g / (0.10 * 0.7894) = 101.35mL
      final volumeFor1Drink = kStandardDrinkGrams / (0.10 * kEthanolDensity);
      final result = calcStandardDrinks(volumeFor1Drink, 10.0);
      expect(result, closeTo(1.0, 0.001));
    });
  });

  group('formatStandardDrinks', () {
    test('1.0 → "1.0 표준잔"', () {
      expect(formatStandardDrinks(1.0), '1.0 표준잔');
    });

    test('0.5 → "0.5 표준잔"', () {
      expect(formatStandardDrinks(0.5), '0.5 표준잔');
    });

    test('1.749 → "1.7 표준잔" (소수점 1자리 반올림)', () {
      expect(formatStandardDrinks(1.749), '1.7 표준잔');
    });

    test('1.75 → "1.8 표준잔" (소수점 1자리 반올림)', () {
      expect(formatStandardDrinks(1.75), '1.8 표준잔');
    });
  });
}

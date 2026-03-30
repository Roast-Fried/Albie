import 'package:flutter_test/flutter_test.dart';
import 'package:albi/core/utils/korean_number.dart';

void main() {
  group('parseKoreanNumber', () {
    test('기본 숫자', () {
      expect(parseKoreanNumber('한'), 1.0);
      expect(parseKoreanNumber('두'), 2.0);
      expect(parseKoreanNumber('세'), 3.0);
      expect(parseKoreanNumber('네'), 4.0);
      expect(parseKoreanNumber('다섯'), 5.0);
      expect(parseKoreanNumber('열'), 10.0);
      expect(parseKoreanNumber('반'), 0.5);
    });

    test('합성 숫자', () {
      expect(parseKoreanNumber('열한'), 11.0);
      expect(parseKoreanNumber('열두'), 12.0);
    });

    test('알 수 없는 입력 → null', () {
      expect(parseKoreanNumber('백'), isNull);
      expect(parseKoreanNumber('맥주'), isNull);
    });
  });

  group('mapUnit', () {
    test('기본 단위 매핑', () {
      expect(mapUnit('잔'), 'glass');
      expect(mapUnit('샷'), 'shot');
      expect(mapUnit('병'), 'bottle');
      expect(mapUnit('캔'), 'can');
      expect(mapUnit('모금'), 'unknown');
    });

    test('알 수 없는 단위 → null', () {
      expect(mapUnit('리터'), isNull);
    });
  });

  group('mapCategory', () {
    test('주종 매핑', () {
      expect(mapCategory('위스키'), 'whisky');
      expect(mapCategory('맥주'), 'beer');
      expect(mapCategory('소주'), 'soju');
      expect(mapCategory('하이볼'), 'highball');
      expect(mapCategory('막걸리'), 'makgeolli');
      expect(mapCategory('와인'), 'wine');
    });

    test('줄임말', () {
      expect(mapCategory('생맥주'), 'beer');
    });
  });
}

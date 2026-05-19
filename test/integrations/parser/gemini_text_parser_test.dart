import 'package:flutter_test/flutter_test.dart';
import 'package:albi/integrations/parser/gemini_text_parser.dart';
import 'package:albi/integrations/parser/parse_result.dart';

/// GeminiTextParser 의 Dart-side 방어 로직 unit test.
///
/// HTTP/이미지 의존성 없는 순수 helper 만 테스트 — `parse()` 전체는
/// integration 흐름에서 검증.
void main() {
  group('warningsForMissingLiquorNames', () {
    test('모든 entry 이름이 채워져 있으면 빈 리스트', () {
      final entries = [
        DraftEntry(liquorName: '맥주', liquorNameRaw: '맥주'),
        DraftEntry(liquorName: '와인', liquorNameRaw: '와인'),
      ];
      expect(warningsForMissingLiquorNames(entries), isEmpty);
    });

    test('null 이름 entry 1개 있으면 1개 경고 텍스트', () {
      final entries = [
        DraftEntry(liquorName: '맥주', liquorNameRaw: '맥주'),
        DraftEntry(liquorName: null, liquorNameRaw: ''),
      ];
      final warnings = warningsForMissingLiquorNames(entries);
      expect(warnings.length, 1);
      expect(warnings.first, contains('1개'));
    });

    test('빈 문자열 / 공백 이름도 missing 으로 카운트', () {
      final entries = [
        DraftEntry(liquorName: '', liquorNameRaw: ''),
        DraftEntry(liquorName: '   ', liquorNameRaw: ''),
        DraftEntry(liquorName: '와인', liquorNameRaw: '와인'),
      ];
      final warnings = warningsForMissingLiquorNames(entries);
      expect(warnings.length, 1);
      expect(warnings.first, contains('2개'));
    });

    test('모든 entry 가 missing 이면 전체 count 가 메시지에 반영', () {
      final entries = [
        DraftEntry(liquorName: null, liquorNameRaw: ''),
        DraftEntry(liquorName: '', liquorNameRaw: ''),
        DraftEntry(liquorName: null, liquorNameRaw: ''),
      ];
      final warnings = warningsForMissingLiquorNames(entries);
      expect(warnings.length, 1);
      expect(warnings.first, contains('3개'));
    });

    test('빈 entries 리스트는 빈 경고', () {
      expect(warningsForMissingLiquorNames(const []), isEmpty);
    });
  });
}

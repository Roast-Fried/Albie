import 'package:flutter_test/flutter_test.dart';
import 'package:albi/core/database/sqflite_row_ext.dart';

void main() {
  group('SqfliteRowX', () {
    test('requireInt returns int value', () {
      final row = <String, Object?>{'id': 42};
      expect(row.requireInt('id'), 42);
    });

    test('requireInt accepts num and converts', () {
      final row = <String, Object?>{'id': 7.0};
      expect(row.requireInt('id'), 7);
    });

    test('requireInt throws StateError on null', () {
      final row = <String, Object?>{'id': null};
      expect(() => row.requireInt('id'), throwsStateError);
    });

    test('requireInt throws StateError on missing key', () {
      final row = <String, Object?>{};
      expect(() => row.requireInt('id'), throwsStateError);
    });

    test('optionalInt returns null for null value', () {
      final row = <String, Object?>{'id': null};
      expect(row.optionalInt('id'), isNull);
    });

    test('optionalInt returns int', () {
      final row = <String, Object?>{'id': 5};
      expect(row.optionalInt('id'), 5);
    });
  });
}

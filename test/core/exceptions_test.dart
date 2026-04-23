import 'package:albi/core/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppError 계층', () {
    test('각 subclass 인스턴스 생성 및 필드', () {
      const db = DatabaseError('저장 실패', cause: 'sqlite error');
      expect(db.userMessage, '저장 실패');
      expect(db.cause, 'sqlite error');

      final net = NetworkError('timeout', statusCode: 429);
      expect(net.userMessage, 'timeout');
      expect(net.statusCode, 429);

      const parse = ParseError('JSON 파싱 실패');
      expect(parse.userMessage, 'JSON 파싱 실패');

      const val = ValidationError('필수 입력 누락');
      expect(val.userMessage, '필수 입력 누락');
    });

    test('toString 은 userMessage 반환', () {
      const e = DatabaseError('XYZ');
      expect(e.toString(), 'XYZ');
    });

    test('sealed 패턴 매칭이 exhaustive — 모든 subclass 를 다룸', () {
      // 이 switch 문이 컴파일된다는 자체가 계층이 sealed 임을 증명.
      // 새 subclass 추가 시 여기 컴파일이 깨진다.
      String label(AppError e) => switch (e) {
            DatabaseError() => 'db',
            NetworkError() => 'net',
            ParseError() => 'parse',
            ValidationError() => 'val',
          };

      expect(label(const DatabaseError('x')), 'db');
      expect(label(NetworkError('x')), 'net');
      expect(label(const ParseError('x')), 'parse');
      expect(label(const ValidationError('x')), 'val');
    });

    test('AppError 는 Exception 계약 만족', () {
      const AppError e = DatabaseError('x');
      expect(e, isA<Exception>());
    });
  });
}

/// 앱 전역 예외 계층.
///
/// 모든 애플리케이션 예외는 [AppError] 를 상속한다.
/// Dart 3 `sealed` 이므로 `switch` 는 exhaustive 하게 검사된다.
sealed class AppError implements Exception {
  final String userMessage;
  final Object? cause;

  const AppError(this.userMessage, {this.cause});

  @override
  String toString() => userMessage;
}

/// 로컬 DB (sqflite) 오류.
class DatabaseError extends AppError {
  const DatabaseError(super.userMessage, {super.cause});
}

/// 외부 네트워크/API 오류. statusCode 는 HTTP 응답이 있었던 경우만 채워진다.
class NetworkError extends AppError {
  final int? statusCode;
  const NetworkError(super.userMessage, {super.cause, this.statusCode});
}

/// 입력 파싱 오류 (자연어 → 구조화 실패).
class ParseError extends AppError {
  const ParseError(super.userMessage, {super.cause});
}

/// 사용자 입력 검증 오류.
class ValidationError extends AppError {
  const ValidationError(super.userMessage, {super.cause});
}

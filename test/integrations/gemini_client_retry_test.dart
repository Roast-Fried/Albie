import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:albi/integrations/gemini/gemini_client.dart';

/// Fake HttpClientAdapter — 미리 정의한 응답을 순서대로 반환.
/// statusCode 가 null 이면 DioExceptionType.receiveTimeout 을 throw.
class _FakeAdapter implements HttpClientAdapter {
  final List<int?> statusCodes; // null → receiveTimeout
  int _callCount = 0;

  _FakeAdapter(this.statusCodes);

  int get callCount => _callCount;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final code = statusCodes[_callCount];
    _callCount++;

    if (code == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }

    if (code >= 500) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: code,
          data: {'error': 'server error'},
        ),
        type: DioExceptionType.badResponse,
      );
    }

    // 400 badResponse
    if (code >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: code,
          data: {'error': 'bad request'},
        ),
        type: DioExceptionType.badResponse,
      );
    }

    // 200 OK — generateContent 가 기대하는 최소 응답 구조 반환
    final jsonBody = '{"candidates":[{"content":{"parts":[{"text":"{}"}]}}]}';
    return ResponseBody.fromString(jsonBody, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// GeminiClient 를 테스트용으로 생성.
/// retryDelays 는 Duration.zero 로 주입해 지연 없이 빠르게 실행.
GeminiClient _makeClient(_FakeAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 100),
      receiveTimeout: const Duration(milliseconds: 100),
    ),
  );
  dio.httpClientAdapter = adapter;
  return GeminiClient(
    dio: dio,
    retryDelays: const [Duration.zero, Duration.zero],
  );
}

/// generateContent 를 최소 인수로 호출하는 헬퍼.
Future<Map<String, dynamic>> _call(GeminiClient client) =>
    client.generateContent(
      model: 'gemini-2.5-flash-lite',
      apiKey: 'test-key',
      systemPrompt: 'sys',
      userText: 'hello',
      responseSchema: {'type': 'object'},
    );

void main() {
  group('GeminiClient — retry 정책', () {
    test('500 응답 2회 후 성공 → 총 3회 호출', () async {
      final adapter = _FakeAdapter([500, 500, 200]);
      final client = _makeClient(adapter);

      final result = await _call(client);

      expect(adapter.callCount, 3);
      expect(result, isA<Map<String, dynamic>>());
    });

    test('receiveTimeout 3회 → 최종 DioException throw', () async {
      // null = receiveTimeout; max 2회 retry → 총 3회 시도 후 throw
      final adapter = _FakeAdapter([null, null, null]);
      await expectLater(
        _call(_makeClient(adapter)),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 3);
    });

    test('400 응답은 재시도하지 않음 → 총 1회 호출 후 throw', () async {
      final adapter = _FakeAdapter([400]);
      final client = _makeClient(adapter);

      await expectLater(
        _call(client),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 1);
    });
  });
}

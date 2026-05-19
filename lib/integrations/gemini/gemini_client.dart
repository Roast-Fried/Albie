import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/exceptions.dart';

class GeminiClient {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// retry 조건: connectionTimeout, receiveTimeout, 5xx 응답
  /// 최대 2회 재시도 (총 3회 호출 가능)
  /// 기본 backoff: 1s → 2s
  static const _defaultRetryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  final Dio _dio;
  final List<Duration> _retryDelays;

  GeminiClient({Dio? dio, List<Duration>? retryDelays})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ),
      _retryDelays = retryDelays ?? _defaultRetryDelays;

  /// retry 대상 오류 판별:
  /// - connectionTimeout / receiveTimeout: 네트워크 일시 오류
  /// - 5xx: Gemini 서버 측 일시 오류 (500 unexpected, 503 overload, 504 deadline)
  /// - 429 rate limit 은 포함하지 않음 (API 한도 초과 → fallback 이 맞음)
  bool _shouldRetry(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return true;
    }
    final statusCode = error.response?.statusCode;
    return statusCode != null && statusCode >= 500 && statusCode < 600;
  }

  /// generateContent 에만 retry 적용 (validateKey 는 즉시 실패 OK)
  Future<Response<dynamic>> _postWithRetry(
    String url,
    dynamic data,
    Options options,
    CancelToken? cancelToken,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _dio.post(
          url,
          data: data,
          options: options,
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        // CancelToken 취소는 재시도하지 않음
        if (error.type == DioExceptionType.cancel) rethrow;
        // 재시도 한도 초과 또는 재시도 불필요 오류 → throw
        if (attempt >= _retryDelays.length || !_shouldRetry(error)) rethrow;
        // 다음 시도 전 backoff 대기
        await Future<void>.delayed(_retryDelays[attempt]);
      }
    }
  }

  /// Gemini generateContent 호출
  /// [model]: gemini-2.5-flash-lite 또는 gemini-2.5-flash
  /// [apiKey]: Gemini API key
  /// [systemPrompt]: 시스템 프롬프트
  /// [userText]: 사용자 입력
  /// [responseSchema]: structured output JSON schema
  Future<Map<String, dynamic>> generateContent({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userText,
    required Map<String, dynamic> responseSchema,
    Uint8List? imageBytes,
    String? imageMimeType,
    CancelToken? cancelToken,
  }) async {
    final url = '$_baseUrl/models/$model:generateContent?key=$apiKey';
    final parts = <Map<String, dynamic>>[
      {
        'text': userText.trim().isEmpty
            ? '이미지에서 술 라벨, 메뉴, 영수증의 음주 정보를 추출해 기록 초안을 만들어라.'
            : userText.trim(),
      },
      if (imageBytes != null)
        {
          'inline_data': {
            'mime_type': imageMimeType ?? 'image/jpeg',
            'data': base64Encode(imageBytes),
          },
        },
    ];

    final body = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
        'temperature': 0.2,
      },
    };

    final response = await _postWithRetry(
      url,
      body,
      Options(headers: {'Content-Type': 'application/json'}),
      cancelToken,
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw NetworkError(
        'Gemini response.data is not a Map: ${data.runtimeType}',
        statusCode: response.statusCode ?? 0,
      );
    }
    return data;
  }

  /// API Key 유효성 검증 (간단한 models.list 호출)
  Future<bool> validateKey(String apiKey) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/models?key=$apiKey',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } on DioException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}

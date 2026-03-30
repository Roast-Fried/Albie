import 'package:dio/dio.dart';

class GeminiClient {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  final Dio _dio;

  GeminiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

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
  }) async {
    final url = '$_baseUrl/models/$model:generateContent?key=$apiKey';

    final body = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': userText}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
        'temperature': 0.2,
      },
    };

    final response = await _dio.post(
      url,
      data: body,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    return response.data as Map<String, dynamic>;
  }

  /// API Key 유효성 검증 (간단한 models.list 호출)
  Future<bool> validateKey(String apiKey) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/models?key=$apiKey',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

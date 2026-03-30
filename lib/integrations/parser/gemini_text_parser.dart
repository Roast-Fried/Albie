import 'dart:convert';
import '../gemini/gemini_client.dart';
import '../gemini/gemini_schemas.dart';
import 'parse_result.dart';

class GeminiTextParser {
  final GeminiClient _client;

  GeminiTextParser(this._client);

  Future<ParseResult> parse({
    required ParseInput input,
    required String apiKey,
    required String model,
    required String source, // ai_user_key | ai_app_key
  }) async {
    final response = await _client.generateContent(
      model: model,
      apiKey: apiKey,
      systemPrompt: buildSystemPrompt(input.inputTime),
      userText: input.text,
      responseSchema: geminiParseResponseSchema,
    );

    // Gemini 응답에서 텍스트 추출
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini 응답에 candidates가 없습니다');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini 응답에 parts가 없습니다');
    }

    final text = parts[0]['text'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini 응답 텍스트가 비어있습니다');
    }

    // JSON 파싱
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Gemini 응답 JSON 파싱 실패: $e');
    }

    final entries = (json['entries'] as List?)
            ?.map((e) => DraftEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    if (entries.isEmpty) {
      throw Exception('Gemini가 항목을 추출하지 못했습니다');
    }

    final foodItems = (json['foodItems'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final warnings = (json['parseWarnings'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    DateTime? drankAt;
    if (json['drankAt'] != null) {
      try {
        drankAt = DateTime.parse(json['drankAt'] as String);
      } catch (_) {}
    }

    return ParseResult(
      source: source,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
      parseWarnings: warnings,
      entries: entries,
      foodItems: foodItems,
      place: json['place'] as String?,
      overallMemo: json['overallMemo'] as String?,
      drankAt: drankAt,
    );
  }
}

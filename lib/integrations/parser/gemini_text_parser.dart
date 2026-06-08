import 'dart:convert';

import 'package:dio/dio.dart';

import '../gemini/gemini_client.dart';
import '../gemini/gemini_schemas.dart';
import 'ai_image_prep.dart';
import 'parse_result.dart';

class GeminiTextParser {
  final GeminiClient _client;
  final String defaultQuantityUnit;
  final bool sixHourCutoffEnabled;

  GeminiTextParser(
    this._client, {
    this.defaultQuantityUnit = 'unknown',
    this.sixHourCutoffEnabled = true,
  });

  Future<ParseResult> parse({
    required ParseInput input,
    required String apiKey,
    required String model,
    required String source, // ai_user_key | ai_app_key
    CancelToken? cancelToken,
  }) async {
    final image = await prepareImageForAi(input.imagePath,
        cancelToken: cancelToken, maxSide: 1600);
    final response = await _client.generateContent(
      model: model,
      apiKey: apiKey,
      systemPrompt: buildSystemPrompt(
        input.inputTime,
        defaultQuantityUnit: defaultQuantityUnit,
        sixHourCutoffEnabled: sixHourCutoffEnabled,
      ),
      userText: input.text,
      responseSchema: geminiParseResponseSchema,
      imageBytes: image?.bytes,
      imageMimeType: image?.mimeType,
      cancelToken: cancelToken,
    );

    // Gemini 응답에서 텍스트 추출
    final candidates = response['candidates'] as List?;
    if (candidates == null) {
      throw Exception('Gemini 응답에 candidates가 없습니다');
    }

    if (candidates.isEmpty) throw Exception('Gemini 응답에 candidates가 없습니다');
    final candidateMap = candidates[0] is Map<String, dynamic>
        ? candidates[0] as Map<String, dynamic>
        : <String, dynamic>{};
    final content = candidateMap['content'] as Map<String, dynamic>?;
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

    final entries =
        (json['entries'] as List?)
            ?.map((e) => DraftEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    if (entries.isEmpty) {
      throw Exception('Gemini가 항목을 추출하지 못했습니다');
    }

    final foodItems =
        (json['foodItems'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final warnings =
        (json['parseWarnings'] as List?)?.map((e) => e.toString()).toList() ??
        [];

    // Dart side 방어: AI 가 liquorName 을 비워서 보낸 entry 가 있으면 경고 추가.
    warnings.addAll(warningsForMissingLiquorNames(entries));

    DateTime? drankAt;
    if (json['drankAt'] != null) {
      try {
        drankAt = DateTime.parse(json['drankAt'] as String);
      } on FormatException catch (_) {}
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

/// AI 가 liquorName 을 비워서 보낸 entry 가 있으면 경고 텍스트를 생성한다.
///
/// schema `required` 만으로는 빈 문자열을 차단하지 못한다 — DraftReview 화면에서
/// 사용자가 직접 채울 수 있도록 warning surface. test 가 직접 호출하기 위해
/// top-level 로 export (production 호출은 `GeminiTextParser.parse` 내부에서만).
List<String> warningsForMissingLiquorNames(List<DraftEntry> entries) {
  final emptyCount = entries
      .where((e) => e.liquorName == null || e.liquorName!.trim().isEmpty)
      .length;
  if (emptyCount == 0) return const [];
  return ['AI가 술 이름을 찾지 못한 항목이 $emptyCount개 있습니다'];
}

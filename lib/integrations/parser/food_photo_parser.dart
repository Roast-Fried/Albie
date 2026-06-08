import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/exceptions.dart';
import '../../data/ai_config_repository.dart';
import '../../data/parse_job_repository.dart';
import '../../domain/entities/parse_job.dart';
import '../gemini/gemini_client.dart';
import '../gemini/gemini_schemas.dart';
import 'ai_image_prep.dart';

/// 음식 사진 → 음식명 추출 (Gemini 비전). 응답에서 음식 리스트만 파싱.
class FoodPhotoAssistant {
  final GeminiClient _client;

  FoodPhotoAssistant(this._client);

  Future<List<String>> extract({
    required String imagePath,
    required String apiKey,
    required String model,
    CancelToken? cancelToken,
  }) async {
    final image = await prepareImageForAi(imagePath, cancelToken: cancelToken);
    if (image == null) return const [];

    final response = await _client.generateContent(
      model: model,
      apiKey: apiKey,
      systemPrompt: buildFoodPhotoSystemPrompt(),
      userText: '이 사진에 보이는 음식 이름을 추출해라.',
      responseSchema: geminiFoodPhotoResponseSchema,
      imageBytes: image.bytes,
      imageMimeType: image.mimeType,
      cancelToken: cancelToken,
    );

    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini 응답에 candidates가 없습니다');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    final text =
        parts?.isNotEmpty == true ? parts![0]['text'] as String? : null;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini 응답 텍스트가 비어있습니다');
    }

    final json = jsonDecode(text) as Map<String, dynamic>;
    final raw = (json['foods'] as List?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const [];
    // 입력 순서 보존 dedupe
    final seen = <String>{};
    return raw.where((f) => seen.add(f)).toList();
  }
}

/// 음식 사진 AI 호출 reason — UI 가 reason 별 메시지 분기 가능하게.
enum FoodPhotoReason { success, empty, aiDisabled, failed }

class FoodPhotoResult {
  final FoodPhotoReason reason;
  final List<String> foods;

  const FoodPhotoResult(this.reason, [this.foods = const []]);
}

/// AI 키 게이팅 + 사용량 기록 + 에러 분류를 담당. (테이스팅 노트 보완과 동일 패턴)
class FoodPhotoOrchestrator {
  final AiConfigRepository _aiConfigRepo;
  final ParseJobRepository _parseJobRepo;
  final GeminiClient _geminiClient;
  final FlutterSecureStorage _secureStorage;

  FoodPhotoOrchestrator({
    required AiConfigRepository aiConfigRepo,
    required ParseJobRepository parseJobRepo,
    GeminiClient? geminiClient,
    FlutterSecureStorage? secureStorage,
  })  : _aiConfigRepo = aiConfigRepo,
        _parseJobRepo = parseJobRepo,
        _geminiClient = geminiClient ?? GeminiClient(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<FoodPhotoResult> extract({
    required String imagePath,
    CancelToken? cancelToken,
  }) async {
    final config = await _aiConfigRepo.get();
    if (!config.isEnabled || config.keyMode != 'user_provided') {
      return const FoodPhotoResult(FoodPhotoReason.aiDisabled);
    }
    final apiKey = await _secureStorage.read(key: 'gemini_api_key');
    if (apiKey == null || apiKey.isEmpty) {
      return const FoodPhotoResult(FoodPhotoReason.aiDisabled);
    }

    const source = 'ai_user_key';
    final stopwatch = Stopwatch()..start();
    try {
      final foods = await FoodPhotoAssistant(_geminiClient).extract(
        imagePath: imagePath,
        apiKey: apiKey,
        model: config.selectedModel,
        cancelToken: cancelToken,
      );
      await _aiConfigRepo.incrementUserImage();
      stopwatch.stop();
      await _parseJobRepo.insert(
        ParseJob(
          sourceType: 'image_only',
          parserUsed: source,
          status: foods.isEmpty ? 'failed' : 'success',
          errorMessage: foods.isEmpty ? 'AI 가 음식을 찾지 못함' : null,
          durationMs: stopwatch.elapsedMilliseconds,
        ),
      );
      return foods.isEmpty
          ? const FoodPhotoResult(FoodPhotoReason.empty)
          : FoodPhotoResult(FoodPhotoReason.success, foods);
    } catch (e) {
      stopwatch.stop();
      if (cancelToken?.isCancelled == true ||
          (e is DioException && e.type == DioExceptionType.cancel)) {
        rethrow;
      }
      final appError = e is DioException
          ? NetworkError('AI 음식 인식 실패', cause: e)
          : ParseError('AI 음식 인식 실패', cause: e);
      await _aiConfigRepo.update(
        config.copyWith(lastErrorMessage: appError.userMessage),
      );
      await _parseJobRepo.insert(
        ParseJob(
          sourceType: 'image_only',
          parserUsed: source,
          status: 'failed',
          errorMessage: appError.userMessage,
          durationMs: stopwatch.elapsedMilliseconds,
        ),
      );
      return const FoodPhotoResult(FoodPhotoReason.failed);
    }
  }
}

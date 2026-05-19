import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/exceptions.dart';
import '../../data/ai_config_repository.dart';
import '../../data/parse_job_repository.dart';
import '../../domain/entities/parse_job.dart';
import '../gemini/gemini_client.dart';
import '../gemini/gemini_schemas.dart';

class TastingNoteSuggestion {
  final String? nose;
  final String? palate;
  final String? finish;
  final String? note;

  const TastingNoteSuggestion({this.nose, this.palate, this.finish, this.note});

  String toPromptText() {
    return [
      '향: ${nose ?? ''}',
      '맛: ${palate ?? ''}',
      '피니시: ${finish ?? ''}',
      '감상: ${note ?? ''}',
    ].join('\n');
  }

  factory TastingNoteSuggestion.fromJson(Map<String, dynamic> json) {
    String? clean(String key) {
      final value = json[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return TastingNoteSuggestion(
      nose: clean('nose'),
      palate: clean('palate'),
      finish: clean('finish'),
      note: clean('note'),
    );
  }
}

class GeminiTastingNoteAssistant {
  final GeminiClient _client;

  GeminiTastingNoteAssistant(this._client);

  Future<TastingNoteSuggestion> enhance({
    required TastingNoteSuggestion draft,
    required String apiKey,
    required String model,
    CancelToken? cancelToken,
  }) async {
    final response = await _client.generateContent(
      model: model,
      apiKey: apiKey,
      systemPrompt: buildTastingNoteSystemPrompt(),
      userText: draft.toPromptText(),
      responseSchema: geminiTastingNoteResponseSchema,
      cancelToken: cancelToken,
    );

    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini 응답에 candidates가 없습니다');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    final text = parts?.isNotEmpty == true
        ? parts![0]['text'] as String?
        : null;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini 응답 텍스트가 비어있습니다');
    }

    final json = jsonDecode(text) as Map<String, dynamic>;
    return TastingNoteSuggestion.fromJson(json);
  }
}

class TastingNoteEnhancementOrchestrator {
  final AiConfigRepository _aiConfigRepo;
  final ParseJobRepository _parseJobRepo;
  final GeminiClient _geminiClient;
  final FlutterSecureStorage _secureStorage;

  TastingNoteEnhancementOrchestrator({
    required AiConfigRepository aiConfigRepo,
    required ParseJobRepository parseJobRepo,
    GeminiClient? geminiClient,
    FlutterSecureStorage? secureStorage,
  }) : _aiConfigRepo = aiConfigRepo,
       _parseJobRepo = parseJobRepo,
       _geminiClient = geminiClient ?? GeminiClient(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<TastingNoteEnhanceResult> enhance({
    required TastingNoteSuggestion draft,
    CancelToken? cancelToken,
  }) async {
    final config = await _aiConfigRepo.get();
    if (!config.isEnabled) {
      return const TastingNoteEnhanceResult(
          TastingNoteEnhanceReason.aiDisabled);
    }

    String? apiKey;
    String source;
    if (config.keyMode == 'user_provided') {
      apiKey = await _secureStorage.read(key: 'gemini_api_key');
      source = 'ai_user_key';
    } else if (config.keyMode == 'app_default') {
      final quota = await _aiConfigRepo.getQuotaToday();
      if (!quota.canUseAppText) {
        return const TastingNoteEnhanceResult(
            TastingNoteEnhanceReason.quotaExceeded);
      }
      apiKey = const String.fromEnvironment('GEMINI_API_KEY');
      source = 'ai_app_key';
    } else {
      return const TastingNoteEnhanceResult(
          TastingNoteEnhanceReason.aiDisabled);
    }
    if (apiKey == null || apiKey.isEmpty) {
      return const TastingNoteEnhanceResult(
          TastingNoteEnhanceReason.aiDisabled);
    }

    final stopwatch = Stopwatch()..start();
    try {
      final suggestion = await GeminiTastingNoteAssistant(_geminiClient)
          .enhance(
            draft: draft,
            apiKey: apiKey,
            model: config.selectedModel,
            cancelToken: cancelToken,
          );
      await _aiConfigRepo.incrementTextCount(
        isUserKey: config.keyMode == 'user_provided',
      );
      stopwatch.stop();
      // parserUsed: source (ai_user_key / ai_app_key) — AI 로그 화면 일관성을 위해
      // success / failed 모두 source 로 기록 (CDX-009). model 명은 로그 필요 시
      // 별도 컬럼 추가 가능 (현재 schema 변경 회피).
      // CDX-003: AI 가 빈 응답 (nose/palate/finish/note 전부 null) 을 반환하면
      // UI 가 silent 갱신 0 — failed 로 분류해 reason=failed 메시지 노출.
      final hasAny = suggestion.nose != null ||
          suggestion.palate != null ||
          suggestion.finish != null ||
          suggestion.note != null;
      await _parseJobRepo.insert(
        ParseJob(
          sourceType: 'text_only',
          parserUsed: source,
          status: hasAny ? 'success' : 'failed',
          errorMessage: hasAny ? null : 'AI 가 보강 결과를 만들지 못함',
          durationMs: stopwatch.elapsedMilliseconds,
        ),
      );
      if (!hasAny) {
        return const TastingNoteEnhanceResult(TastingNoteEnhanceReason.failed);
      }
      return TastingNoteEnhanceResult(
          TastingNoteEnhanceReason.success, suggestion);
    } catch (e) {
      stopwatch.stop();
      if (cancelToken?.isCancelled == true ||
          (e is DioException && e.type == DioExceptionType.cancel)) {
        rethrow;
      }
      final appError = e is DioException
          ? NetworkError('AI 테이스팅 노트 보완 실패', cause: e)
          : ParseError('AI 테이스팅 노트 보완 실패', cause: e);
      await _aiConfigRepo.update(
        config.copyWith(lastErrorMessage: appError.userMessage),
      );
      await _parseJobRepo.insert(
        ParseJob(
          sourceType: 'text_only',
          parserUsed: source,
          status: 'failed',
          errorMessage: appError.userMessage,
          durationMs: stopwatch.elapsedMilliseconds,
        ),
      );
      return const TastingNoteEnhanceResult(
          TastingNoteEnhanceReason.failed);
    }
  }
}

/// AI 보완 호출 결과 reason — Sheet 가 reason 별 사용자 메시지 분기 가능하게.
enum TastingNoteEnhanceReason {
  success,
  quotaExceeded,
  aiDisabled,
  failed,
}

class TastingNoteEnhanceResult {
  final TastingNoteEnhanceReason reason;
  final TastingNoteSuggestion? suggestion;

  const TastingNoteEnhanceResult(this.reason, [this.suggestion]);
}

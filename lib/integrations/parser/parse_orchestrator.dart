import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/exceptions.dart';
import '../../data/ai_config_repository.dart';
import '../../data/parse_job_repository.dart';
import '../../domain/entities/parse_job.dart';
import '../gemini/gemini_client.dart';
import 'gemini_text_parser.dart';
import 'local_rule_parser.dart';
import 'parse_result.dart';

class ParseOrchestrator {
  final LocalRuleParser _localParser;
  final AiConfigRepository _aiConfigRepo;
  final ParseJobRepository _parseJobRepo;
  final GeminiClient _geminiClient;
  final FlutterSecureStorage _secureStorage;

  ParseOrchestrator({
    required LocalRuleParser localParser,
    required AiConfigRepository aiConfigRepo,
    required ParseJobRepository parseJobRepo,
    GeminiClient? geminiClient,
    FlutterSecureStorage? secureStorage,
  }) : _localParser = localParser,
       _aiConfigRepo = aiConfigRepo,
       _parseJobRepo = parseJobRepo,
       _geminiClient = geminiClient ?? GeminiClient(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<OrchestrateResult> process(
    ParseInput input, {
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    ParseResult result;
    String parserUsed;
    bool wasAiAttempted = false;

    if (input.hasImage) {
      // 이미지가 있으면 AI를 우선 시도하되, 텍스트가 함께 있으면 로컬 텍스트 fallback을 유지한다.
      final ai = await _tryAiParse(input, cancelToken: cancelToken);
      wasAiAttempted = ai.wasAttempted;
      if (ai.result != null) {
        result = ai.result!.result;
        parserUsed = ai.result!.parserUsed;
      } else if (input.text.trim().isNotEmpty) {
        result = await _localParser.parse(
          ParseInput(text: input.text, inputTime: input.inputTime),
        );
        result = result.copyWith(
          parseWarnings: [
            '이미지 분석을 사용할 수 없어 텍스트 기준으로 초안을 만들었습니다.',
            ...result.parseWarnings,
          ],
        );
        parserUsed = 'local_parser';
      } else {
        result = ParseResult.empty(
          source: 'local_parser',
          warnings: ['이미지 분석을 사용할 수 없어 빈 초안을 만들었습니다. 내용을 직접 확인해주세요.'],
        );
        parserUsed = 'local_parser';
      }
    } else {
      // 텍스트: AI 시도 → 실패 시 로컬 fallback
      final ai = await _tryAiParse(input, cancelToken: cancelToken);
      wasAiAttempted = ai.wasAttempted;
      if (ai.result != null) {
        result = ai.result!.result;
        parserUsed = ai.result!.parserUsed;
      } else {
        result = await _localParser.parse(input);
        parserUsed = 'local_parser';
      }
    }

    stopwatch.stop();

    // 개인정보 보호 (Codex C6 fix, 2026-05-26):
    // rawRequest 는 즉시 저장하지 않고 DrinkLog 저장 성공 시점에 linkToLog 에서 update.
    // 사용자가 DraftReview 에서 이탈하면 orphan parseJob 의 rawRequest 는 영구 NULL.
    final jobId = await _parseJobRepo.insert(
      ParseJob(
        sourceType: _sourceType(input),
        parserUsed: parserUsed,
        status: result.entries.isEmpty ? 'failed' : 'success',
        durationMs: stopwatch.elapsedMilliseconds,
      ),
    );

    return OrchestrateResult(
      parseResult: result,
      parseJobId: jobId,
      wasAiAttempted: wasAiAttempted,
    );
  }

  /// AI 파싱 시도.
  ///
  /// 반환 `wasAttempted` 의미:
  /// - false: AI 비활성 / 키 없음 / 쿼터 초과 — 실제 API 호출은 없었음. 배너 미표시 기준.
  /// - true: `GeminiTextParser.parse` 호출까지 도달 — 성공이든 실패든 네트워크 시도 있었음.
  Future<({_AiParseResult? result, bool wasAttempted})> _tryAiParse(
    ParseInput input, {
    CancelToken? cancelToken,
  }) async {
    final config = await _aiConfigRepo.get();
    if (!config.isEnabled) return (result: null, wasAttempted: false);

    String? apiKey;
    String source;

    if (config.keyMode == 'user_provided') {
      apiKey = await _secureStorage.read(key: 'gemini_api_key');
      source = 'ai_user_key';
    } else if (config.keyMode == 'app_default') {
      apiKey = const String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isEmpty) return (result: null, wasAttempted: false);

      // Codex C4 fix: atomic reserve (check + increment 단일 UPDATE) 로 race 방지.
      // reserve 성공 시 +1 됨 → API 실패해도 quota 차감 (AI 호출 비용은 already incurred).
      final reserved = input.hasImage
          ? await _aiConfigRepo.reserveAppImage()
          : await _aiConfigRepo.reserveAppText();
      if (!reserved) {
        return (result: null, wasAttempted: false);
      }
      source = 'ai_app_key';
    } else {
      return (result: null, wasAttempted: false);
    }

    if (apiKey == null || apiKey.isEmpty) {
      return (result: null, wasAttempted: false);
    }

    // 여기서부터 실제 API 호출 — wasAttempted = true
    try {
      final parser = GeminiTextParser(
        _geminiClient,
        defaultQuantityUnit: _localParser.defaultQuantityUnit,
        sixHourCutoffEnabled: _localParser.sixHourCutoffEnabled,
      );
      final result = await parser.parse(
        input: input,
        apiKey: apiKey,
        model: config.selectedModel,
        source: source,
        cancelToken: cancelToken,
      );

      // 사용량 증가 (user 키만 — app 키는 reserveApp* 에서 이미 +1)
      if (config.keyMode == 'user_provided') {
        if (input.hasImage) {
          await _aiConfigRepo.incrementImageCount(isUserKey: true);
        } else {
          await _aiConfigRepo.incrementTextCount(isUserKey: true);
        }
      }

      return (
        result: _AiParseResult(
          result: result,
          parserUsed: config.selectedModel,
        ),
        wasAttempted: true,
      );
    } catch (e) {
      if (cancelToken?.isCancelled == true ||
          (e is DioException && e.type == DioExceptionType.cancel)) {
        // Codex F2 fix (2026-05-26): 사용자 취소 시 app 키 quota rollback.
        // 취소는 실제 API 호출 비용이 발생하지 않은 경우 — reserve 된 카운트 환원.
        // (일반 AI 실패는 호출 발생 후이므로 차감 유지.)
        if (config.keyMode == 'app_default') {
          if (input.hasImage) {
            await _aiConfigRepo.decrementAppImage();
          } else {
            await _aiConfigRepo.decrementAppText();
          }
        }
        rethrow;
      }
      // AI 실패 → fallback to local. 타입화된 에러로 분류하지만 throw 하지 않음.
      final error = _classifyAiError(e);
      await _aiConfigRepo.update(
        (await _aiConfigRepo.get()).copyWith(
          lastErrorMessage: error.userMessage,
        ),
      );
      return (result: null, wasAttempted: true);
    }
  }

  /// AI 파싱 중 발생한 예외를 [AppError] 계층으로 분류한다.
  /// 호출자(_tryAiParse)는 fallback 을 위해 throw 하지 않고 메시지만 저장한다.
  ///
  /// PII 보호: `DioException.message` / `e.toString()` 인터폴레이션 금지 — Dio 5.x
  /// 일부 경로에서 request URL (API key 포함) 또는 응답 body 일부가 포함될 수 있다.
  /// status code 별 정적 한국어 메시지만 노출. 원인은 `cause` 에 보존 (DB 저장 X).
  AppError _classifyAiError(Object e) {
    if (e is DioException) {
      final msg = switch (e.response?.statusCode) {
        401 => 'API 키가 유효하지 않습니다',
        429 => 'API 할당량을 초과했습니다',
        500 || 502 || 503 || 504 => 'AI 서버가 일시적으로 응답하지 못했습니다',
        _ => e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout
            ? '네트워크 연결 시간 초과'
            : 'AI 분석에 실패했습니다 (네트워크 오류)',
      };
      return NetworkError(msg, cause: e, statusCode: e.response?.statusCode);
    }
    return ParseError('AI 분석에 실패했습니다', cause: e);
  }

  String _sourceType(ParseInput input) {
    if (!input.hasImage) return 'text_only';
    return input.text.trim().isEmpty ? 'image_only' : 'text_plus_image';
  }
}

class _AiParseResult {
  final ParseResult result;
  final String parserUsed;

  _AiParseResult({required this.result, required this.parserUsed});
}

class OrchestrateResult {
  final ParseResult parseResult;
  final int parseJobId;

  /// AI 실제 호출 여부. `parseResult.source == 'local_parser'` 이면서 true 면 AI 실패 fallback.
  /// 뷰에서 "AI 실패" 배너 분기에 사용.
  final bool wasAiAttempted;

  OrchestrateResult({
    required this.parseResult,
    required this.parseJobId,
    this.wasAiAttempted = false,
  });
}

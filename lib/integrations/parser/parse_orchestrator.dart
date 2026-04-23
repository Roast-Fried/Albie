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
  })  : _localParser = localParser,
        _aiConfigRepo = aiConfigRepo,
        _parseJobRepo = parseJobRepo,
        _geminiClient = geminiClient ?? GeminiClient(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<OrchestrateResult> process(ParseInput input) async {
    final stopwatch = Stopwatch()..start();
    ParseResult result;
    String parserUsed;
    bool wasAiAttempted = false;

    if (input.hasImage) {
      // 이미지는 AI만 가능 — R1.5
      result = ParseResult.empty(
        source: 'local_parser',
        warnings: ['이미지 분석은 AI 연결이 필요합니다. 텍스트로 입력해주세요.'],
      );
      parserUsed = 'local_parser';
    } else {
      // 텍스트: AI 시도 → 실패 시 로컬 fallback
      final ai = await _tryAiParse(input);
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

    final jobId = await _parseJobRepo.insert(ParseJob(
      sourceType: input.hasImage ? 'text_plus_image' : 'text_only',
      parserUsed: parserUsed,
      status: result.entries.isEmpty ? 'failed' : 'success',
      rawRequest: input.text,
      durationMs: stopwatch.elapsedMilliseconds,
    ));

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
      ParseInput input) async {
    final config = await _aiConfigRepo.get();
    if (!config.isEnabled) return (result: null, wasAttempted: false);

    String? apiKey;
    String source;

    if (config.keyMode == 'user_provided') {
      apiKey = await _secureStorage.read(key: 'gemini_api_key');
      source = 'ai_user_key';
    } else if (config.keyMode == 'app_default') {
      // 기본 키: quota 체크
      final quota = await _aiConfigRepo.getQuotaToday();
      if (!quota.canUseAppText) return (result: null, wasAttempted: false);

      apiKey = const String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isEmpty) return (result: null, wasAttempted: false);
      source = 'ai_app_key';
    } else {
      return (result: null, wasAttempted: false);
    }

    if (apiKey == null || apiKey.isEmpty) {
      return (result: null, wasAttempted: false);
    }

    // 여기서부터 실제 API 호출 — wasAttempted = true
    try {
      final parser = GeminiTextParser(_geminiClient);
      final result = await parser.parse(
        input: input,
        apiKey: apiKey,
        model: config.selectedModel,
        source: source,
      );

      // 사용량 증가
      await _aiConfigRepo.incrementTextCount(
        isUserKey: config.keyMode == 'user_provided',
      );

      return (
        result: _AiParseResult(result: result, parserUsed: config.selectedModel),
        wasAttempted: true,
      );
    } catch (e) {
      // AI 실패 → fallback to local. 타입화된 에러로 분류하지만 throw 하지 않음.
      final error = _classifyAiError(e);
      await _aiConfigRepo.update(
        (await _aiConfigRepo.get()).copyWith(lastErrorMessage: error.userMessage),
      );
      return (result: null, wasAttempted: true);
    }
  }

  /// AI 파싱 중 발생한 예외를 [AppError] 계층으로 분류한다.
  /// 호출자(_tryAiParse)는 fallback 을 위해 throw 하지 않고 메시지만 저장한다.
  AppError _classifyAiError(Object e) {
    if (e is DioException) {
      final msg = switch (e.response?.statusCode) {
        401 => 'API 키가 유효하지 않습니다',
        429 => 'API 할당량을 초과했습니다',
        _ => e.type == DioExceptionType.connectionTimeout
            ? '네트워크 연결 시간 초과'
            : 'AI 분석 실패: ${e.message}',
      };
      return NetworkError(msg, cause: e, statusCode: e.response?.statusCode);
    }
    return ParseError('AI 분석 실패', cause: e);
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

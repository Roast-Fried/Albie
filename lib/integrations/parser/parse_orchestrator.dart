import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

    if (input.hasImage) {
      // 이미지는 AI만 가능 — R1.5
      result = ParseResult.empty(
        source: 'local_parser',
        warnings: ['이미지 분석은 AI 연결이 필요합니다. 텍스트로 입력해주세요.'],
      );
      parserUsed = 'local_parser';
    } else {
      // 텍스트: AI 시도 → 실패 시 로컬 fallback
      final aiResult = await _tryAiParse(input);
      if (aiResult != null) {
        result = aiResult.result;
        parserUsed = aiResult.parserUsed;
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

    return OrchestrateResult(parseResult: result, parseJobId: jobId);
  }

  Future<_AiParseResult?> _tryAiParse(ParseInput input) async {
    try {
      final config = await _aiConfigRepo.get();
      if (!config.isEnabled) return null;

      String? apiKey;
      String source;

      if (config.keyMode == 'user_provided') {
        apiKey = await _secureStorage.read(key: 'gemini_api_key');
        source = 'ai_user_key';
      } else if (config.keyMode == 'app_default') {
        // 기본 키: quota 체크
        final quota = await _aiConfigRepo.getQuotaToday();
        if (!quota.canUseAppText) return null;

        apiKey = const String.fromEnvironment('GEMINI_API_KEY');
        if (apiKey.isEmpty) return null;
        source = 'ai_app_key';
      } else {
        return null;
      }

      if (apiKey == null || apiKey.isEmpty) return null;

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

      return _AiParseResult(result: result, parserUsed: config.selectedModel);
    } catch (e) {
      // AI 실패 → fallback to local (에러 무시)
      await _aiConfigRepo.update(
        (await _aiConfigRepo.get()).copyWith(lastErrorMessage: e.toString()),
      );
      return null;
    }
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

  OrchestrateResult({required this.parseResult, required this.parseJobId});
}

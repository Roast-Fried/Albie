import '../../data/ai_config_repository.dart';
import '../../data/parse_job_repository.dart';
import '../../domain/entities/parse_job.dart';
import 'local_rule_parser.dart';
import 'parse_result.dart';

class ParseOrchestrator {
  final LocalRuleParser _localParser;
  final AiConfigRepository _aiConfigRepo; // ignore: unused_field — Phase 6에서 AI 전략 선택 시 사용
  final ParseJobRepository _parseJobRepo;

  ParseOrchestrator({
    required LocalRuleParser localParser,
    required AiConfigRepository aiConfigRepo,
    required ParseJobRepository parseJobRepo,
  })  : _localParser = localParser,
        _aiConfigRepo = aiConfigRepo,
        _parseJobRepo = parseJobRepo;

  Future<OrchestrateResult> process(ParseInput input) async {
    final stopwatch = Stopwatch()..start();
    ParseResult result;
    String parserUsed;

    // 이미지가 있으면 AI만 가능 (Phase 6에서 구현)
    if (input.hasImage) {
      result = ParseResult.empty(
        source: 'local_parser',
        warnings: ['이미지 분석은 AI 연결이 필요합니다. 텍스트로 입력해주세요.'],
      );
      parserUsed = 'local_parser';
    } else {
      // TODO: Phase 6에서 AI 파서 연결
      // 지금은 항상 로컬 파서 사용
      result = await _localParser.parse(input);
      parserUsed = 'local_parser';
    }

    stopwatch.stop();

    // 파싱 작업 로그 저장
    final jobId = await _parseJobRepo.insert(ParseJob(
      sourceType: input.hasImage ? 'text_plus_image' : 'text_only',
      parserUsed: parserUsed,
      status: result.entries.isEmpty ? 'failed' : 'success',
      rawRequest: input.text,
      durationMs: stopwatch.elapsedMilliseconds,
    ));

    return OrchestrateResult(parseResult: result, parseJobId: jobId);
  }
}

/// Orchestrator 반환값 — ParseResult + job ID (저장 시 연결용)
class OrchestrateResult {
  final ParseResult parseResult;
  final int parseJobId;

  OrchestrateResult({required this.parseResult, required this.parseJobId});
}

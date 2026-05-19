import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/tasting_note.dart';
import '../integrations/parser/gemini_tasting_note_assistant.dart';
import 'achievements_viewmodel.dart';

final tastingNoteEnhancementOrchestratorProvider =
    Provider<TastingNoteEnhancementOrchestrator>((ref) {
      return TastingNoteEnhancementOrchestrator(
        aiConfigRepo: ref.watch(aiConfigRepoProvider),
        parseJobRepo: ref.watch(parseJobRepoProvider),
      );
    });

Future<void> saveTastingNote(WidgetRef ref, TastingNote note) async {
  final repo = ref.read(tastingNoteRepoProvider);
  await repo.save(note);
  ref.invalidate(tastingNoteByEntryProvider(note.entryId));
  // 업적 "테이스팅 메모리" 조건이 노트 수 의존이라 invalidate 필요.
  ref.invalidate(achievementsProvider);
}

class TastingNoteDraft {
  final String? nose;
  final String? palate;
  final String? finish;
  final String? note;

  const TastingNoteDraft({this.nose, this.palate, this.finish, this.note});

  TastingNoteSuggestion toSuggestion() {
    return TastingNoteSuggestion(
      nose: nose,
      palate: palate,
      finish: finish,
      note: note,
    );
  }

  factory TastingNoteDraft.fromSuggestion(TastingNoteSuggestion suggestion) {
    return TastingNoteDraft(
      nose: suggestion.nose,
      palate: suggestion.palate,
      finish: suggestion.finish,
      note: suggestion.note,
    );
  }
}

class TastingNoteEnhanceController {
  CancelToken? _token;

  CancelToken begin() {
    cancel();
    return _token = CancelToken();
  }

  void complete(CancelToken token) {
    if (_token == token) _token = null;
  }

  void cancel() {
    _token?.cancel('사용자가 AI 테이스팅 노트 보완을 취소했습니다');
    _token = null;
  }
}

/// View 가 직접 분기 가능한 reason — integration 의 enum 을 viewmodel layer 에
/// 노출하기 위한 view-facing enum (ARCH-001 의존성 방향 fix).
///
/// View → ViewModel 만 import 하도록 integrations enum 을 직접 참조하지 않음.
enum TastingEnhanceReason {
  success,
  quotaExceeded,
  aiDisabled,
  failed,
  cancelled,
}

/// Sheet 가 reason 별 메시지 분기 가능하도록 reason + draft 반환.
class TastingNoteEnhanceOutcome {
  final TastingEnhanceReason reason;
  final TastingNoteDraft? draft;

  const TastingNoteEnhanceOutcome({required this.reason, this.draft});

  bool get cancelled => reason == TastingEnhanceReason.cancelled;
}

/// integration → viewmodel enum mapping (View 비노출)
TastingEnhanceReason _mapReason(TastingNoteEnhanceReason r) => switch (r) {
      TastingNoteEnhanceReason.success => TastingEnhanceReason.success,
      TastingNoteEnhanceReason.quotaExceeded =>
        TastingEnhanceReason.quotaExceeded,
      TastingNoteEnhanceReason.aiDisabled => TastingEnhanceReason.aiDisabled,
      TastingNoteEnhanceReason.failed => TastingEnhanceReason.failed,
    };

Future<TastingNoteEnhanceOutcome> enhanceTastingNote(
  WidgetRef ref,
  TastingNoteDraft draft, {
  TastingNoteEnhanceController? controller,
}) async {
  final orchestrator = ref.read(tastingNoteEnhancementOrchestratorProvider);
  final token = controller?.begin() ?? CancelToken();
  try {
    final result = await orchestrator.enhance(
      draft: draft.toSuggestion(),
      cancelToken: token,
    );
    return TastingNoteEnhanceOutcome(
      reason: _mapReason(result.reason),
      draft: result.suggestion == null
          ? null
          : TastingNoteDraft.fromSuggestion(result.suggestion!),
    );
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) {
      return const TastingNoteEnhanceOutcome(
          reason: TastingEnhanceReason.cancelled);
    }
    rethrow;
  } finally {
    controller?.complete(token);
  }
}

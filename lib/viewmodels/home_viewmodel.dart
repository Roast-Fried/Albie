import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/drink_log.dart';
import '../integrations/parser/local_rule_parser.dart';
import '../integrations/parser/parse_orchestrator.dart';
import '../integrations/parser/parse_result.dart';

// --- Providers ---

final localParserProvider = Provider<LocalRuleParser>((ref) {
  final repo = ref.watch(liquorMasterRepoProvider);
  return LocalRuleParser(repo);
});

final orchestratorProvider = Provider<ParseOrchestrator>((ref) {
  return ParseOrchestrator(
    localParser: ref.watch(localParserProvider),
    aiConfigRepo: ref.watch(aiConfigRepoProvider),
    parseJobRepo: ref.watch(parseJobRepoProvider),
  );
});

/// 최근 기록 (홈 위젯용)
final recentLogsProvider = FutureProvider<List<DrinkLog>>((ref) async {
  final repo = ref.watch(drinkLogRepoProvider);
  return repo.getAll(limit: 5);
});

/// 전체 기록 수 (홈 통계 카드용)
final logCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(drinkLogRepoProvider);
  return repo.count();
});

// --- ViewModel ---

class HomeViewModel extends StateNotifier<HomeState> {
  final ParseOrchestrator _orchestrator;

  HomeViewModel(this._orchestrator) : super(const HomeState());

  void updateInput(String text) {
    state = state.copyWith(inputText: text);
  }

  Future<OrchestrateResult?> generateDraft() async {
    if (state.inputText.trim().isEmpty) return null;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _orchestrator.process(
        ParseInput(text: state.inputText.trim()),
      );
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  void clearInput() {
    state = const HomeState();
  }
}

class HomeState {
  final String inputText;
  final bool isLoading;
  final String? error;

  const HomeState({
    this.inputText = '',
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({String? inputText, bool? isLoading, String? error}) {
    return HomeState(
      inputText: inputText ?? this.inputText,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  return HomeViewModel(ref.watch(orchestratorProvider));
});

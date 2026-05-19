import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/providers.dart';
import '../integrations/parser/local_rule_parser.dart';
import '../integrations/parser/parse_orchestrator.dart';
import '../integrations/parser/parse_result.dart';
import 'app_settings_viewmodel.dart';

// --- Providers ---

final localParserProvider = Provider<LocalRuleParser>((ref) {
  final repo = ref.watch(liquorMasterRepoProvider);
  final settings =
      ref.watch(appSettingsProvider).valueOrNull ?? const AppSettingsState();
  return LocalRuleParser(
    repo,
    defaultQuantityUnit: settings.defaultQuantityUnit,
    sixHourCutoffEnabled: settings.sixHourCutoffEnabled,
  );
});

final orchestratorProvider = Provider<ParseOrchestrator>((ref) {
  return ParseOrchestrator(
    localParser: ref.watch(localParserProvider),
    aiConfigRepo: ref.watch(aiConfigRepoProvider),
    parseJobRepo: ref.watch(parseJobRepoProvider),
  );
});

// --- ViewModel ---

class HomeViewModel extends StateNotifier<HomeState> {
  final ParseOrchestrator? _orchestrator;
  final ImagePicker _picker;
  CancelToken? _activeCancelToken;

  HomeViewModel(ParseOrchestrator orchestrator)
    : _orchestrator = orchestrator,
      _picker = ImagePicker(),
      super(const HomeState());

  /// 테스트 전용 — orchestrator 없이 생성
  HomeViewModel.forTest()
    : _orchestrator = null,
      _picker = ImagePicker(),
      super(const HomeState());

  void updateInput(String text) {
    state = state.copyWith(inputText: text);
  }

  Future<void> pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      state = state.copyWith(
        imagePath: picked.path,
        imageName: picked.name,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: '사진을 불러오지 못했습니다: $e');
    }
  }

  void removeImage() {
    state = state.copyWith(clearImage: true);
  }

  Future<OrchestrateResult?> generateDraft() async {
    if (state.inputText.trim().isEmpty && state.imagePath == null) return null;
    final orchestrator = _orchestrator;
    if (orchestrator == null) return null;

    // imagePath 검증 — 갤러리 사진 선택 후 사용자가 OS 에서 삭제했을 가능성.
    // crash 대신 안내 메시지 + imagePath clear (text 만으로라도 진행 가능하게).
    String? imagePath = state.imagePath;
    if (imagePath != null && !File(imagePath).existsSync()) {
      state = state.copyWith(
        clearImage: true,
        error: '선택한 이미지를 찾을 수 없습니다. 다시 선택해 주세요.',
      );
      if (state.inputText.trim().isEmpty) return null;
      imagePath = null;
    }

    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await orchestrator.process(
        ParseInput(text: state.inputText.trim(), imagePath: imagePath),
        cancelToken: cancelToken,
      );
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        state = state.copyWith(isLoading: false, error: null);
        return null;
      }
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    } finally {
      if (_activeCancelToken == cancelToken) _activeCancelToken = null;
    }
  }

  void cancelGenerate() {
    _activeCancelToken?.cancel('사용자가 AI 분석을 취소했습니다');
    _activeCancelToken = null;
    state = state.copyWith(isLoading: false, error: null);
  }

  void clearInput() {
    _activeCancelToken?.cancel('입력 초기화');
    _activeCancelToken = null;
    state = const HomeState();
  }
}

class HomeState {
  final String inputText;
  final String? imagePath;
  final String? imageName;
  final bool isLoading;
  final String? error;

  const HomeState({
    this.inputText = '',
    this.imagePath,
    this.imageName,
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({
    String? inputText,
    String? imagePath,
    String? imageName,
    bool? isLoading,
    String? error,
    bool clearImage = false,
  }) {
    return HomeState(
      inputText: inputText ?? this.inputText,
      imagePath: clearImage ? null : imagePath ?? this.imagePath,
      imageName: clearImage ? null : imageName ?? this.imageName,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final homeViewModelProvider = StateNotifierProvider<HomeViewModel, HomeState>((
  ref,
) {
  return HomeViewModel(ref.watch(orchestratorProvider));
});

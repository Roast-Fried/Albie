import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/drink_log.dart';
import '../integrations/parser/parse_result.dart';
import 'log_list_viewmodel.dart';

// --- ViewModel ---

class DraftReviewViewModel extends StateNotifier<DraftReviewState> {
  DraftReviewViewModel(super.initial);

  void updateEntry(int index, DraftEntry entry) {
    final entries = [...state.entries];
    if (index >= 0 && index < entries.length) {
      entries[index] = entry;
      state = state.copyWith(entries: entries);
    }
  }

  void addEntry() {
    state = state.copyWith(
      entries: [...state.entries, DraftEntry(liquorNameRaw: '')],
    );
  }

  void removeEntry(int index) {
    if (state.entries.length <= 1) return; // 최소 1개 유지
    final entries = [...state.entries]..removeAt(index);
    state = state.copyWith(entries: entries);
  }

  void updatePlace(String? place) {
    state = state.copyWith(place: place);
  }

  void updateMemo(String? memo) {
    state = state.copyWith(overallMemo: memo);
  }

  void updateDrankAt(DateTime drankAt) {
    state = state.copyWith(drankAt: drankAt);
  }

  void addFood(String food) {
    if (food.trim().isEmpty) return;
    if (state.foodItems.contains(food.trim())) return;
    state = state.copyWith(foodItems: [...state.foodItems, food.trim()]);
  }

  void removeFood(int index) {
    final foods = [...state.foodItems]..removeAt(index);
    state = state.copyWith(foodItems: foods);
  }

  /// AI 실패 배너 닫기 — `wasAiAttempted=false` 로 플래그만 내려 배너 숨김.
  void dismissAiFailBanner() {
    state = state.copyWith(wasAiAttempted: false);
  }

  /// ParseResult → DB 저장 가능한 DrinkLog로 변환
  DrinkLog toSaveable() {
    return DrinkLog(
      rawInputText: state.rawInputText,
      parseSource: state.source,
      place: state.place,
      overallMemo: state.overallMemo,
      drankAt: state.drankAt,
      userConfirmedAt: DateTime.now(),
      entries: state.entries
          .where((e) => e.liquorNameRaw.isNotEmpty)
          .map((e) => DrinkEntry(
                id: e.id,
                liquorMasterId: e.liquorMasterId,
                liquorNameRaw: e.liquorNameRaw,
                liquorCategory: e.liquorCategory,
                ageStatement: e.ageStatement,
                quantityValue: e.quantityValue,
                quantityUnit: e.quantityUnit,
                isEstimated: e.isEstimated,
                alcoholPercent: e.alcoholPercent,
              ))
          .toList(),
      foodItems: state.foodItems,
    );
  }

  /// 저장 (신규/수정 모두 처리) — View에서 Repository 직접 호출 제거
  Future<void> saveToDb(WidgetRef ref) async {
    final log = toSaveable();
    final repo = ref.read(drinkLogRepoProvider);

    if (state.isEditing) {
      await repo.update(log.copyWith(id: state.editingLogId));
    } else {
      final logId = await repo.save(log);
      if (state.parseJobId != null) {
        final jobRepo = ref.read(parseJobRepoProvider);
        await jobRepo.linkToLog(state.parseJobId!, logId);
      }
    }

    // 관련 provider 일괄 갱신
    ref.invalidate(recentLogsProvider);
    ref.invalidate(logCountProvider);
    ref.invalidate(logListProvider);
  }
}

class DraftReviewState {
  final String source;
  final double confidence;
  final List<String> parseWarnings;
  final List<DraftEntry> entries;
  final List<String> foodItems;
  final String? place;
  final String? overallMemo;
  final DateTime drankAt;
  final String? rawInputText;
  final int? parseJobId;
  final int? editingLogId; // null이면 신규, 값이면 수정 모드

  /// AI 네트워크 호출이 실제로 있었는데 로컬 파서로 fallback 된 경우 true.
  /// AI 비활성/키 없음/쿼터 초과는 false — 배너 미표시.
  final bool wasAiAttempted;

  DraftReviewState({
    required this.source,
    this.confidence = 0.5,
    this.parseWarnings = const [],
    this.entries = const [],
    this.foodItems = const [],
    this.place,
    this.overallMemo,
    required this.drankAt,
    this.rawInputText,
    this.parseJobId,
    this.editingLogId,
    this.wasAiAttempted = false,
  });

  bool get isEditing => editingLogId != null;

  /// 배너 표시 조건: AI 실패 → 로컬 fallback 시에만.
  bool get showAiFailBanner =>
      wasAiAttempted && source == 'local_parser';

  factory DraftReviewState.fromParseResult(
    ParseResult result, {
    String? rawInputText,
    int? parseJobId,
    bool wasAiAttempted = false,
  }) {
    return DraftReviewState(
      source: result.source,
      confidence: result.confidence,
      parseWarnings: result.parseWarnings,
      entries: result.entries,
      foodItems: result.foodItems,
      place: result.place,
      overallMemo: result.overallMemo,
      drankAt: result.drankAt ?? DateTime.now(),
      rawInputText: rawInputText,
      parseJobId: parseJobId,
      wasAiAttempted: wasAiAttempted,
    );
  }

  /// 직접 입력 모드 (빈 폼)
  factory DraftReviewState.manual({String? rawInputText}) {
    return DraftReviewState(
      source: 'manual',
      confidence: 1.0,
      entries: [DraftEntry(liquorNameRaw: '')],
      drankAt: DateTime.now(),
      rawInputText: rawInputText,
    );
  }

  DraftReviewState copyWith({
    List<DraftEntry>? entries,
    List<String>? foodItems,
    String? place,
    String? overallMemo,
    DateTime? drankAt,
    bool? wasAiAttempted,
  }) {
    return DraftReviewState(
      source: source,
      confidence: confidence,
      parseWarnings: parseWarnings,
      entries: entries ?? this.entries,
      foodItems: foodItems ?? this.foodItems,
      place: place ?? this.place,
      overallMemo: overallMemo ?? this.overallMemo,
      drankAt: drankAt ?? this.drankAt,
      rawInputText: rawInputText,
      parseJobId: parseJobId,
      editingLogId: editingLogId,
      wasAiAttempted: wasAiAttempted ?? this.wasAiAttempted,
    );
  }
}

/// DraftReview용 provider — 화면 진입 시 override해서 사용
final draftReviewProvider =
    StateNotifierProvider<DraftReviewViewModel, DraftReviewState>((ref) {
  return DraftReviewViewModel(DraftReviewState.manual());
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/drink_log.dart';
import '../domain/entities/liquor_master.dart';
import '../integrations/parser/parse_result.dart';
import 'achievements_viewmodel.dart';
import 'archive_viewmodel.dart';
import 'log_list_viewmodel.dart';
import 'stats_viewmodel.dart';

/// 검토 화면 Entry 카드에서 매칭된 liquorMaster 표시용.
final entryDraftMasterProvider = FutureProvider.family<LiquorMaster?, int>((
  ref,
  masterId,
) async {
  return ref.watch(liquorMasterRepoProvider).getById(masterId);
});

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

  /// 2026-05-27 Sprint 1 UI-017: 직접 입력 모드에서 술 이름 변경 시 master 매칭 시도.
  /// View 가 Repository 직접 접근하지 않도록 ViewModel 메서드로 노출.
  ///
  /// Codex audit Finding 5.1: master 매칭 시 category 무조건 덮어쓰기 위험.
  /// 사용자가 드롭다운에서 명시 선택한 카테고리 (current.liquorCategory != 'other')
  /// 는 보존하고, 'other' default 일 때만 자동 채움.
  ///
  /// Finding 3.3/6.4: DraftEntry.copyWith 의 liquorMasterId 가 sentinel 패턴으로
  /// 수정되어 null clear 가능 (parse_result.dart).
  Future<void> tryMatchByName(WidgetRef ref, int index, String name) async {
    final trimmed = name.trim();
    if (trimmed.length < 2) return;
    if (index < 0 || index >= state.entries.length) return;

    final repo = ref.read(liquorMasterRepoProvider);
    final match = await repo.findByPartialMatch(trimmed);

    // race 보호 — async 사이에 entry 가 사라지거나 이름이 다시 바뀌었으면 무시.
    if (index >= state.entries.length) return;
    final current = state.entries[index];
    if (current.liquorNameRaw.trim() != trimmed) return;

    final entries = [...state.entries];
    if (match != null) {
      // 2026-05-27 Codex audit 6 (WARN): 사용자가 master matching 후 dropdown 으로
      // 카테고리 명시 변경한 entry 의 이름을 다시 수정 시 새 match.category 가
      // 사용자 선택을 덮는 회귀. masterId 조건 제거 — liquorCategory 가 'other' 가
      // 아니면 (사용자가 명시했거나 이전 매칭으로 채워진 값) 항상 보존.
      final preserveCategory = current.liquorCategory != 'other';
      entries[index] = current.copyWith(
        liquorMasterId: match.id,
        liquorCategory: preserveCategory ? null : match.category,
        // 사용자가 직접 입력한 도수가 없으면 master default 채움.
        alcoholPercent: current.alcoholPercent ?? match.defaultAbv,
      );
    } else {
      // 매칭 실패 — masterId 가 남아 있으면 제거 (이전 매칭 무효화).
      if (current.liquorMasterId != null) {
        entries[index] = current.copyWith(liquorMasterId: null);
      } else {
        return;
      }
    }
    state = state.copyWith(entries: entries);
  }

  void addEntry() {
    state = state.copyWith(
      entries: [
        ...state.entries,
        DraftEntry(liquorNameRaw: '', quantityUnit: state.defaultQuantityUnit),
      ],
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
      rawImagePath: state.rawImagePath,
      parseSource: state.source,
      place: state.place,
      overallMemo: state.overallMemo,
      drankAt: state.drankAt,
      userConfirmedAt: DateTime.now(),
      entries: state.entries
          .where((e) => e.liquorNameRaw.isNotEmpty)
          .map(
            (e) => DrinkEntry(
              id: e.id,
              liquorMasterId: e.liquorMasterId,
              liquorNameRaw: e.liquorNameRaw,
              liquorCategory: e.liquorCategory,
              ageStatement: e.ageStatement,
              quantityValue: e.quantityValue,
              quantityUnit: e.quantityUnit,
              isEstimated: e.isEstimated,
              alcoholPercent: e.alcoholPercent,
            ),
          )
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
        // Codex C6 fix: rawRequest 는 본 시점에서 처음 저장 (orphan 잔존 방지).
        await jobRepo.linkToLog(
          state.parseJobId!,
          logId,
          rawRequest: state.rawInputText,
        );
      }
    }

    // 관련 provider 일괄 갱신
    ref.invalidate(recentLogsProvider);
    ref.invalidate(logCountProvider);
    ref.invalidate(logListProvider);
    // 업적/통계는 로그 수/주류 다양성에 의존 — 저장 직후 invalidate 필요.
    ref.invalidate(achievementsProvider);
    ref.invalidate(statsProvider);
    ref.invalidate(thisMonthLogCountProvider);
    ref.invalidate(recentFrequentLiquorsProvider);
    // 아카이브 (마셔본 술 카탈로그) — 새 master/entry 가 추가되면 갱신 필요 (CDX-005)
    ref.invalidate(archiveListProvider);
  }
}

/// `copyWith` sentinel — 사용자가 `place: null` / `overallMemo: null` 로 명시적으로
/// 비울 수 있도록 "값 미지정" 과 "null 로 비우기" 를 구분한다.
const Object _kUnset = Object();

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
  final String? rawImagePath;
  final int? parseJobId;
  final int? editingLogId; // null이면 신규, 값이면 수정 모드
  final String defaultQuantityUnit;

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
    this.rawImagePath,
    this.parseJobId,
    this.editingLogId,
    this.defaultQuantityUnit = 'glass',
    this.wasAiAttempted = false,
  });

  bool get isEditing => editingLogId != null;

  /// 배너 표시 조건: AI 실패 → 로컬 fallback 시에만.
  bool get showAiFailBanner => wasAiAttempted && source == 'local_parser';

  factory DraftReviewState.fromParseResult(
    ParseResult result, {
    String? rawInputText,
    String? rawImagePath,
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
      rawImagePath: rawImagePath,
      parseJobId: parseJobId,
      wasAiAttempted: wasAiAttempted,
    );
  }

  /// 직접 입력 모드 (빈 폼)
  /// 2026-05-27 Sprint 1 UI-016: manual mode 는 사용자 명시 입력이므로 isEstimated=false.
  factory DraftReviewState.manual({
    String? rawInputText,
    String? rawImagePath,
    String defaultQuantityUnit = 'glass',
    DateTime? drankAt,
  }) {
    return DraftReviewState(
      source: 'manual',
      confidence: 1.0,
      entries: [
        DraftEntry(
          liquorNameRaw: '',
          quantityUnit: defaultQuantityUnit,
          isEstimated: false,
        ),
      ],
      drankAt: drankAt ?? DateTime.now(),
      rawInputText: rawInputText,
      rawImagePath: rawImagePath,
      defaultQuantityUnit: defaultQuantityUnit,
    );
  }

  DraftReviewState copyWith({
    List<DraftEntry>? entries,
    List<String>? foodItems,
    Object? place = _kUnset,
    Object? overallMemo = _kUnset,
    DateTime? drankAt,
    bool? wasAiAttempted,
  }) {
    return DraftReviewState(
      source: source,
      confidence: confidence,
      parseWarnings: parseWarnings,
      entries: entries ?? this.entries,
      foodItems: foodItems ?? this.foodItems,
      place: identical(place, _kUnset) ? this.place : place as String?,
      overallMemo: identical(overallMemo, _kUnset)
          ? this.overallMemo
          : overallMemo as String?,
      drankAt: drankAt ?? this.drankAt,
      rawInputText: rawInputText,
      rawImagePath: rawImagePath,
      parseJobId: parseJobId,
      editingLogId: editingLogId,
      defaultQuantityUnit: defaultQuantityUnit,
      wasAiAttempted: wasAiAttempted ?? this.wasAiAttempted,
    );
  }
}

/// DraftReview용 provider — 화면 진입 시 override해서 사용
final draftReviewProvider =
    StateNotifierProvider<DraftReviewViewModel, DraftReviewState>((ref) {
      return DraftReviewViewModel(DraftReviewState.manual());
    });

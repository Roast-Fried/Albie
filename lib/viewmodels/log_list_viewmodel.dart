import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/drink_log.dart';
import 'achievements_viewmodel.dart';
import 'archive_viewmodel.dart';
import 'calendar_viewmodel.dart';
import 'stats_viewmodel.dart';

final logListProvider =
    AsyncNotifierProvider<LogListViewModel, List<DrinkLog>>(
        LogListViewModel.new);

class LogListViewModel extends AsyncNotifier<List<DrinkLog>> {
  @override
  Future<List<DrinkLog>> build() async {
    final repo = ref.watch(drinkLogRepoProvider);
    return repo.getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(drinkLogRepoProvider).getAll());
  }

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      await refresh();
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(drinkLogRepoProvider).search(keyword));
  }

  /// 삭제 후 관련 provider 일괄 갱신.
  ///
  /// 삭제는 stats / achievements / 월 카운트 / 자주 마신 술 / 최근 목록 모두에
  /// 영향 — save 흐름 (draft_review_viewmodel.saveToDb) 의 invalidate 셋과
  /// 대칭으로 유지해야 stale UI 방지 (Codex closure audit B HIGH 처리).
  Future<void> delete(int logId) async {
    await ref.read(drinkLogRepoProvider).delete(logId);
    ref.invalidate(recentLogsProvider);
    ref.invalidate(logCountProvider);
    ref.invalidate(thisMonthLogCountProvider);
    ref.invalidate(recentFrequentLiquorsProvider);
    ref.invalidate(achievementsProvider);
    ref.invalidate(statsProvider);
    // 아카이브 (마셔본 술 카탈로그) — 마지막 1건이 삭제되면 entry 사라지므로 갱신 필수 (CDX-005)
    ref.invalidate(archiveListProvider);
    // 캘린더 마커/선택일 목록도 삭제 직후 갱신 (Codex R1 MEDIUM)
    ref.invalidate(calendarLogsByDayProvider);
    await refresh();
  }
}

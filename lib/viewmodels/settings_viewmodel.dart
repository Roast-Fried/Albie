import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import 'archive_viewmodel.dart';
import 'calendar_viewmodel.dart';
import 'log_list_viewmodel.dart';
import 'stats_viewmodel.dart';

class SettingsDataSnapshot {
  final int totalLogs;
  final int totalMasters; // 마셔본 서로 다른 주류 수 (liquorMasterId DISTINCT)

  SettingsDataSnapshot({required this.totalLogs, required this.totalMasters});
}

/// 설정 화면의 데이터 섹션 표시용.
/// 기록 0 이면 `totalMasters = 0`.
final settingsDataProvider =
    FutureProvider<SettingsDataSnapshot>((ref) async {
  final logRepo = ref.watch(drinkLogRepoProvider);
  final totalLogs = await logRepo.count();

  // 마셔본 서로 다른 주류 — 이미 archiveList 에 집계 로직 있으므로 재활용
  final items = await ref.watch(archiveListProvider.future);
  return SettingsDataSnapshot(
    totalLogs: totalLogs,
    totalMasters: items.length,
  );
});

/// 모든 기록 데이터 삭제.
///
/// drinkLog 만 지우면 FK CASCADE 로 drinkEntry, drinkLogFood, tastingNote 모두 삭제.
/// parseJob 은 `logId` 가 `SET NULL` 이라 log 만 끊어지고 로그 자체는 남음 —
/// 그러나 `parseJob.rawRequest` 에 사용자가 입력한 원문(개인정보) 이 보관되므로
/// "전체 기록 삭제" 시 parseJob 도 함께 삭제해야 한다.
Future<void> resetAllRecords(WidgetRef ref) async {
  final repo = ref.read(drinkLogRepoProvider);
  final all = await repo.getAll();
  for (final log in all) {
    if (log.id != null) await repo.delete(log.id!);
  }

  // 개인정보 보호 — parseJob 의 rawRequest 원문도 삭제.
  await ref.read(parseJobRepoProvider).deleteAll();

  // invalidations
  ref.invalidate(recentLogsProvider);
  ref.invalidate(logCountProvider);
  ref.invalidate(logListProvider);
  ref.invalidate(archiveListProvider);
  ref.invalidate(settingsDataProvider);
  ref.invalidate(statsProvider);
  ref.invalidate(calendarLogsByDayProvider);
}

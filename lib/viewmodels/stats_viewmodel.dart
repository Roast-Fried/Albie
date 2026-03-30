import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';

class StatsData {
  final int totalCount;
  final int last7DaysCount;
  final int thisMonthCount;
  final Map<String, int> categoryDistribution;
  final List<MapEntry<String, int>> topLiquors;
  final Map<String, int> monthlyTrend; // "2026-03" → count

  StatsData({
    this.totalCount = 0,
    this.last7DaysCount = 0,
    this.thisMonthCount = 0,
    this.categoryDistribution = const {},
    this.topLiquors = const [],
    this.monthlyTrend = const {},
  });
}

final statsProvider = FutureProvider<StatsData>((ref) async {
  final repo = ref.watch(drinkLogRepoProvider);
  final logs = await repo.getAll();

  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(const Duration(days: 7));
  final monthStart = DateTime(now.year, now.month, 1);

  int last7 = 0;
  int thisMonth = 0;
  final catMap = <String, int>{};
  final liquorMap = <String, int>{};
  final monthMap = <String, int>{};

  for (final log in logs) {
    if (log.drankAt.isAfter(sevenDaysAgo)) last7++;
    if (log.drankAt.isAfter(monthStart)) thisMonth++;

    final monthKey =
        '${log.drankAt.year}-${log.drankAt.month.toString().padLeft(2, '0')}';
    monthMap[monthKey] = (monthMap[monthKey] ?? 0) + 1;

    for (final entry in log.entries) {
      catMap[entry.liquorCategory] =
          (catMap[entry.liquorCategory] ?? 0) + 1;
      final name = entry.liquorNameRaw;
      if (name.isNotEmpty) {
        liquorMap[name] = (liquorMap[name] ?? 0) + 1;
      }
    }
  }

  final topLiquors = liquorMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return StatsData(
    totalCount: logs.length,
    last7DaysCount: last7,
    thisMonthCount: thisMonth,
    categoryDistribution: catMap,
    topLiquors: topLiquors.take(5).toList(),
    monthlyTrend: monthMap,
  );
});

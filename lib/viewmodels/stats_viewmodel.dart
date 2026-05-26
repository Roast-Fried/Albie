import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/utils/standard_drink_utils.dart';
import '../domain/entities/drink_log.dart';

enum StatsPeriod { thisMonth, last3Months, all }

extension StatsPeriodLabel on StatsPeriod {
  String get label => switch (this) {
        StatsPeriod.thisMonth => '이번 달',
        StatsPeriod.last3Months => '3개월',
        StatsPeriod.all => '전체',
      };
}

/// 현재 선택된 기간 필터.
///
/// `autoDispose` — 통계 화면 이탈 시 `thisMonth` 로 reset.
/// 이유: 전역 `StateProvider` 로 두면 다음 진입 시 stale 한 직전 선택이 유지되어
/// 사용자가 "왜 기본값이 thisMonth 가 아니지?" 라고 혼란.
/// Albi 의 IndexedStack 정책상 autoDispose 는 default 금지지만,
/// statsPeriod 는 단순 UI 필터라 화면 이탈 후 reset 이 자연스러움.
final statsPeriodProvider =
    StateProvider.autoDispose<StatsPeriod>((ref) => StatsPeriod.thisMonth);

class StatsData {
  final int totalCount;
  final int last7DaysCount;
  final int thisMonthCount;
  final double thisMonthStandardDrinks;
  final Map<String, int> categoryDistribution;
  final List<MapEntry<String, int>> topLiquors;
  final Map<String, int> monthlyTrend; // "2026-03" → count

  StatsData({
    this.totalCount = 0,
    this.last7DaysCount = 0,
    this.thisMonthCount = 0,
    this.thisMonthStandardDrinks = 0,
    this.categoryDistribution = const {},
    this.topLiquors = const [],
    this.monthlyTrend = const {},
  });
}

/// 음주 단위 → ml 추정 매핑 (한국 시장 평균치 + 주종 보정)
///
/// 통계용 추정치 — 실제 용량과 다를 수 있음. UI 에서 "추정" 명시.
/// 같은 단위라도 주종별 표준 용량이 다름 (CDX-001):
/// - glass: 위스키 잔(45ml) / 와인 잔(150ml) / 맥주 잔(250ml) / 그 외(200ml)
/// - bottle: 소주 360ml / 맥주 500ml / 와인 750ml / 위스키 700ml / 그 외(360ml)
double _entryVolumeMl(DrinkEntry e) {
  final cat = e.liquorCategory;
  switch (e.quantityUnit) {
    case 'ml':
      return e.quantityValue;
    case 'shot':
      return e.quantityValue * 30; // 1 샷 ≈ 30ml (모든 주종 공통)
    case 'glass':
      // 주종별 잔 표준 용량
      final mlPerGlass = switch (cat) {
        'whisky' => 45.0, // 위스키 1 샷잔 ≈ 45ml
        'wine' => 150.0,  // 와인 잔 ≈ 150ml
        'beer' => 250.0,  // 맥주 잔 ≈ 250ml
        'highball' => 250.0,
        'cocktail' => 150.0,
        'sake' => 100.0,
        _ => 200.0, // 막걸리/소주/기타 잔 ≈ 200ml
      };
      return e.quantityValue * mlPerGlass;
    case 'cup':
      return e.quantityValue * 200;
    case 'can':
      return e.quantityValue * 355; // 일반 캔 ≈ 355ml
    case 'bottle':
      final mlPerBottle = switch (cat) {
        'soju' => 360.0,
        'beer' => 500.0,
        'wine' => 750.0,
        'whisky' => 700.0,
        'sake' => 720.0,
        'makgeolli' => 750.0,
        _ => 360.0,
      };
      return e.quantityValue * mlPerBottle;
    case 'pint':
      return e.quantityValue * 473;
    default:
      return 0; // unknown — skip
  }
}

/// 선택 기간 내 집계.
///
/// `categoryDistribution` / `topLiquors` 는 선택 기간 기준,
/// `monthlyTrend` 는 최근 6개월 고정 (라인차트 전용).
/// `totalCount`, `last7DaysCount`, `thisMonthCount` 는 참조용 전체 지표.
// statsPeriodProvider 가 autoDispose 라 statsProvider 도 cascading autoDispose 필요
// (non-autoDispose 가 autoDispose 를 watch 하면 Riverpod 컴파일 에러).
final statsProvider = FutureProvider.autoDispose<StatsData>((ref) async {
  final repo = ref.watch(drinkLogRepoProvider);
  final period = ref.watch(statsPeriodProvider);
  final logs = await repo.getAll();

  final now = DateTime.now();
  // 기간 정의 (모두 inclusive 경계):
  // - "최근 7일": 현재 시각 기준 rolling 168시간 (`now - 7d` 이상). 캘린더-day 가 아님.
  // - "이번 달": 월 1일 00:00:00 이상.
  // - "최근 3개월": 3개월 전 같은 월의 1일 00:00:00 이상.
  // - "최근 6개월": monthlyTrend 라인차트 전용 (월 단위 집계).
  final sevenDaysAgo = now.subtract(const Duration(days: 7));
  final monthStart = DateTime(now.year, now.month, 1);
  final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
  final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

  // 지표 (전체 기준) — 상단 카드
  // 경계 포함 (inclusive): 월 1일 00:00:00 기록이 "이번 달" 에서 누락되지 않도록
  // `isAfter` 대신 `!isBefore` 사용.
  int last7 = 0;
  int thisMonth = 0;
  double thisMonthStdDrinks = 0;
  final monthMap = <String, int>{};
  for (final log in logs) {
    if (!log.drankAt.isBefore(sevenDaysAgo)) last7++;
    if (!log.drankAt.isBefore(monthStart)) {
      thisMonth++;
      // 이번 달 entries 의 표준잔 누적 (alcoholPercent 있는 항목만 — 추정 가능)
      for (final entry in log.entries) {
        final abv = entry.alcoholPercent;
        if (abv == null || abv <= 0) continue;
        final ml = _entryVolumeMl(entry);
        if (ml <= 0) continue;
        thisMonthStdDrinks += calcStandardDrinks(ml, abv);
      }
    }
    if (!log.drankAt.isBefore(sixMonthsAgo)) {
      final monthKey =
          '${log.drankAt.year}-${log.drankAt.month.toString().padLeft(2, '0')}';
      monthMap[monthKey] = (monthMap[monthKey] ?? 0) + 1;
    }
  }

  // 기간 필터 — 분포 / TOP5 (inclusive)
  bool inPeriod(DateTime dt) {
    return switch (period) {
      StatsPeriod.thisMonth => !dt.isBefore(monthStart),
      StatsPeriod.last3Months => !dt.isBefore(threeMonthsAgo),
      StatsPeriod.all => true,
    };
  }

  final catMap = <String, int>{};
  final liquorMap = <String, int>{};

  for (final log in logs) {
    if (!inPeriod(log.drankAt)) continue;
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
    thisMonthStandardDrinks: thisMonthStdDrinks,
    categoryDistribution: catMap,
    topLiquors: topLiquors.take(5).toList(),
    monthlyTrend: monthMap,
  );
});

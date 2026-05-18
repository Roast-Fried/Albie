import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/label_utils.dart';
import '../../viewmodels/stats_viewmodel.dart';
import '../common/error_state_widget.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static const _pieColors = [
    Color(0xFFBF7B3A),
    Color(0xFF8B5E3C),
    Color(0xFFD4A574),
    Color(0xFF6B8E7F),
    Color(0xFF9B7B9B),
    Color(0xFFB68363),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final period = ref.watch(statsPeriodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
            message: '통계를 불러올 수 없습니다',
            onRetry: () => ref.invalidate(statsProvider)),
        data: (stats) => stats.totalCount == 0
            ? const Center(child: Text('기록이 없어요'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 기간 탭
                  SegmentedButton<StatsPeriod>(
                    segments: StatsPeriod.values
                        .map((p) =>
                            ButtonSegment(value: p, label: Text(p.label)))
                        .toList(),
                    selected: {period},
                    onSelectionChanged: (s) => ref
                        .read(statsPeriodProvider.notifier)
                        .state = s.first,
                  ),
                  const SizedBox(height: 16),

                  // 지표 카드 3개 (전체 기준)
                  Row(
                    children: [
                      _StatCard(
                          label: '총 기록', value: '${stats.totalCount}건'),
                      const SizedBox(width: 8),
                      _StatCard(
                          label: '이번 달',
                          value: '${stats.thisMonthCount}건'),
                      const SizedBox(width: 8),
                      _StatCard(
                          label: '최근 7일',
                          value: '${stats.last7DaysCount}건'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 주종별 분포 — 파이차트
                  if (stats.categoryDistribution.isNotEmpty) ...[
                    Text('주종별 분포 (${period.label})',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _CategoryPieChart(
                        data: stats.categoryDistribution,
                        colors: _pieColors),
                    const SizedBox(height: 24),
                  ],

                  // TOP 5 술
                  if (stats.topLiquors.isNotEmpty) ...[
                    Text('자주 마신 술 TOP 5 (${period.label})',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    for (var i = 0; i < stats.topLiquors.length; i++)
                      _RankTile(
                        rank: i + 1,
                        name: stats.topLiquors[i].key,
                        count: stats.topLiquors[i].value,
                      ),
                    const SizedBox(height: 24),
                  ],

                  // 월별 기록 추이 — 라인차트 (최근 6개월 고정)
                  if (stats.monthlyTrend.isNotEmpty) ...[
                    Text('월별 기록 추이 (최근 6개월)',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _MonthlyTrendChart(data: stats.monthlyTrend),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;

  const _CategoryPieChart({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (s, e) => s + e.value);

    return SizedBox(
      height: 220,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  for (var i = 0; i < sorted.length; i++)
                    PieChartSectionData(
                      value: sorted[i].value.toDouble(),
                      color: colors[i % colors.length],
                      title:
                          '${(sorted[i].value / total * 100).toStringAsFixed(0)}%',
                      radius: 60,
                      // WCAG AA fix — white on pastel pie sections 2.0-3.6:1 FAIL
                      // → black87 (>5:1 on all 6 pastel colors)
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < sorted.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(categoryLabel(sorted[i].key),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 4),
                        Text('${sorted[i].value}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final int rank;
  final String name;
  final int count;

  const _RankTile(
      {required this.rank, required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: rank <= 3
                        ? Theme.of(context).colorScheme.primary
                        : null)),
          ),
          Expanded(child: Text(name)),
          Text('$count회', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  final Map<String, int> data;
  const _MonthlyTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    // 최근 6개월 key 를 시간순 정렬
    final now = DateTime.now();
    final months = List<String>.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i), 1);
      return '${m.year}-${m.month.toString().padLeft(2, '0')}';
    });

    final spots = <FlSpot>[];
    var maxY = 1.0;
    for (var i = 0; i < months.length; i++) {
      final v = (data[months[i]] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), v));
      if (v > maxY) maxY = v;
    }

    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 5,
          minY: 0,
          maxY: (maxY * 1.2).ceilToDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 3).clamp(1, double.infinity),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles:
                    SideTitles(showTitles: true, reservedSize: 28)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= months.length) {
                    return const SizedBox.shrink();
                  }
                  final month = months[idx].split('-').last;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${int.parse(month)}월',
                        style:
                            Theme.of(context).textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

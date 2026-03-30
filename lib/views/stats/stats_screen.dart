import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/stats_viewmodel.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (stats) => stats.totalCount == 0
            ? const Center(child: Text('기록이 없어요'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 숫자 카드 3개
                  Row(
                    children: [
                      _StatCard(
                          label: '총 기록', value: '${stats.totalCount}건'),
                      const SizedBox(width: 8),
                      _StatCard(
                          label: '최근 7일', value: '${stats.last7DaysCount}건'),
                      const SizedBox(width: 8),
                      _StatCard(
                          label: '이번 달', value: '${stats.thisMonthCount}건'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 주종별 분포
                  if (stats.categoryDistribution.isNotEmpty) ...[
                    Text('주종별 분포',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _CategoryBars(data: stats.categoryDistribution),
                    const SizedBox(height: 24),
                  ],

                  // TOP 5 술
                  if (stats.topLiquors.isNotEmpty) ...[
                    Text('가장 많이 마신 술',
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

class _CategoryBars extends StatelessWidget {
  final Map<String, int> data;

  const _CategoryBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isEmpty ? 1 : sorted.first.value;

    return Column(
      children: sorted.map((e) {
        final ratio = e.value / maxVal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                  width: 60,
                  child: Text(_categoryLabel(e.key),
                      style: Theme.of(context).textTheme.bodySmall)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 18,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                  width: 24,
                  child: Text('${e.value}',
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.end)),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _categoryLabel(String cat) {
    const map = {
      'whisky': '위스키', 'highball': '하이볼', 'beer': '맥주',
      'wine': '와인', 'cocktail': '칵테일', 'soju': '소주',
      'makgeolli': '막걸리', 'sake': '사케', 'other': '기타',
    };
    return map[cat] ?? cat;
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
          Text('$count회',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

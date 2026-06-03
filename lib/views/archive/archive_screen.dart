import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/app_routes.dart';
import '../../core/providers.dart';
import '../../core/utils/label_utils.dart';
import '../../viewmodels/archive_viewmodel.dart';
import '../common/error_state_widget.dart';
import '../log/widgets/star_rating.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  static const _categories = [
    (null, '전체'),
    ('whisky', '위스키'),
    ('highball', '하이볼'),
    ('beer', '맥주'),
    ('wine', '와인'),
    ('cocktail', '칵테일'),
    ('soju', '소주'),
    ('makgeolli', '막걸리'),
    ('sake', '사케'),
    ('other', '기타'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(archiveCategoryFilter);
    final archiveAsync = ref.watch(archiveListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('마셔본 술')),
      body: Column(
        children: [
          // 카테고리 필터 — 가로 스크롤, 우측 fade gradient 로 스크롤 가능 신호.
          // 2026-05-27 Sprint 2 UI-020: 360px 에서 chip 9개 가로 overflow 시
          // 마지막 chip 이 그냥 잘려 사용자가 스크롤 가능을 인지 못함.
          SizedBox(
            // a11y: 48dp 최소 터치 타겟 확보 (FilterChip 가로 스트립).
            height: 48,
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black,
                    Colors.black,
                    Colors.black.withValues(alpha: 0.0),
                  ],
                  // 2026-05-27 Codex 5 commit audit Finding 2: fade 영역 8% 가
                  // 마지막 chip 의 selected fill / ripple 을 시각적으로 흐리는
                  // 충돌. 5% 로 줄여 chip 의 selected indicator 보존 + scroll
                  // 신호 유지.
                  stops: const [0.0, 0.95, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, right: 32),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final (value, label) = _categories[i];
                  final isActive = selected == value;
                  return FilterChip(
                    label: Text(label),
                    selected: isActive,
                    onSelected: (_) =>
                        ref.read(archiveCategoryFilter.notifier).state = value,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 리스트
          Expanded(
            child: archiveAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorStateWidget(
                  message: '데이터를 불러올 수 없습니다',
                  onRetry: () => ref.invalidate(archiveListProvider)),
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyArchive(selectedCategory: selected);
                }
                final totalRecords =
                    items.fold<int>(0, (s, it) => s + it.recordCount);
                return Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${items.length}종 · 총 $totalRecords회 기록',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline)),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        itemBuilder: (context, i) =>
                            _ArchiveTile(item: items[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyArchive extends ConsumerWidget {
  final String? selectedCategory;

  const _EmptyArchive({required this.selectedCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wine_bar_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(selectedCategory == null
              ? '아직 기록이 없어요'
              : '해당 카테고리에 기록이 없어요'),
          const SizedBox(height: 4),
          Text('오늘 뭐 마셨어요? 한 줄로 알려주세요!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('첫 기록 남기기'),
            onPressed: () =>
                ref.read(appTabIndexProvider.notifier).state = 0,
          ),
        ],
      ),
    );
  }
}

class _ArchiveTile extends ConsumerWidget {
  final ArchiveItem item;

  const _ArchiveTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastDate = item.lastDrankAt != null
        ? DateFormat('M/d').format(item.lastDrankAt!)
        : '-';
    final subParts = <String>[
      subcategoryLabel(item.category, item.subcategory),
      if (item.country != null) item.country!,
      if (item.defaultAbv != null) '${item.defaultAbv}% ABV',
    ];
    final line1 = subParts.join(' · ');
    final line2 = '${item.recordCount}회 기록 · 최근 $lastDate';

    return Card(
      child: ListTile(
        title: Text(item.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                    child: Text(line2,
                        style: Theme.of(context).textTheme.bodySmall)),
                if (item.avgRating != null) ...[
                  StarRating(value: item.avgRating!, size: 12),
                  const SizedBox(width: 4),
                  Text(item.avgRating!.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: item.liquorMasterId != null
            ? IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: item.isFavorite
                      ? Theme.of(context).colorScheme.error
                      : null,
                  size: 20,
                ),
                tooltip: item.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
                onPressed: () => ref
                    .read(archiveListProvider.notifier)
                    .toggleFavorite(item.liquorMasterId!, item.isFavorite),
              )
            : null,
        onTap: () {
          if (item.liquorMasterId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('마스터 데이터가 없는 브랜드는 상세를 볼 수 없습니다'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
          Navigator.of(context).pushNamed(
            Routes.archiveDetail,
            arguments: item.liquorMasterId!,
          );
        },
      ),
    );
  }

}

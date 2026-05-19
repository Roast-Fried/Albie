import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/label_utils.dart';
import '../../viewmodels/archive_detail_viewmodel.dart';
import '../common/error_state_widget.dart';
import '../log/widgets/star_rating.dart';

/// 브랜드 상세 — 3 지표 + 기록 히스토리 + 별칭 관리.
class ArchiveDetailScreen extends ConsumerWidget {
  final int masterId;

  const ArchiveDetailScreen({super.key, required this.masterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(archiveDetailProvider(masterId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('아카이브 상세'),
        actions: [
          detailAsync.maybeWhen(
            data: (d) => IconButton(
              icon: Icon(
                d.master.isFavorite ? Icons.favorite : Icons.favorite_border,
                // Theme token — dark 모드 + brand color 일관성
                color:
                    d.master.isFavorite ? Theme.of(context).colorScheme.error : null,
              ),
              tooltip: d.master.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
              onPressed: () =>
                  toggleArchiveFavorite(ref, masterId, d.master.isFavorite),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: '상세 정보를 불러올 수 없습니다',
          onRetry: () => ref.invalidate(archiveDetailProvider(masterId)),
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 헤더
            Text(
              d.master.nameKo ?? d.master.canonicalName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle(d),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),

            const SizedBox(height: 20),

            // 3 지표
            Row(
              children: [
                _Metric(value: '${d.totalRecords}', label: '총 기록'),
                const SizedBox(width: 8),
                _Metric(
                  value: d.avgRating == null
                      ? '—'
                      : d.avgRating!.toStringAsFixed(1),
                  label: '평균 평점',
                  sublabel: d.avgRating == null ? '평점 미입력' : null,
                ),
                const SizedBox(width: 8),
                _Metric(value: '${d.totalEntries}', label: '총 항목'),
              ],
            ),

            const SizedBox(height: 24),

            // 기록 히스토리
            Text(
              '기록 히스토리',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (d.history.isEmpty)
              // WCAG AA fix — Colors.grey (~2.6:1) → onSurfaceVariant (~4.5:1+)
              Text(
                '기록이 없습니다',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final h in d.history) _HistoryTile(item: h),

            const SizedBox(height: 24),

            // 별칭
            Text(
              '별칭',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final alias in d.master.aliases)
                  Chip(
                    label: Text(alias),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('추가'),
                  onPressed: () => _addAlias(context, ref, d.master.aliases),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(ArchiveDetailData d) {
    final parts = <String>[
      if (d.master.canonicalName != d.master.nameKo) d.master.canonicalName,
      if (d.master.subcategory != null) d.master.subcategory!,
      categoryLabel(d.master.category),
      if (d.master.country != null) d.master.country!,
      if (d.master.defaultAbv != null) '${d.master.defaultAbv}%',
    ];
    return parts.join(' · ');
  }

  Future<void> _addAlias(
    BuildContext context,
    WidgetRef ref,
    List<String> existing,
  ) async {
    final ctrl = TextEditingController();
    final added = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('별칭 추가'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 벤로맥'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (added == null || added.isEmpty) return;
    if (existing.contains(added)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이미 존재하는 별칭입니다')));
      }
      return;
    }
    await addArchiveAlias(ref, masterId, added);
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final String? sublabel;

  const _Metric({required this.value, required this.label, this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            if (sublabel != null)
              Text(
                sublabel!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ArchiveHistoryItem item;

  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('M/d (E) a h:mm', 'ko').format(item.drankAt);
    final qty = item.quantityValue % 1 == 0
        ? item.quantityValue.toInt().toString()
        : item.quantityValue.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$qty ${unitLabel(item.quantityUnit)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (item.place != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '📍 ${item.place}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (item.rating != null) StarRating(value: item.rating!, size: 14),
        ],
      ),
    );
  }
}

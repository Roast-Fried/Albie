import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../domain/entities/drink_log.dart';
import '../../viewmodels/draft_review_viewmodel.dart';
import '../../viewmodels/log_list_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../integrations/parser/parse_result.dart';
import '../draft_review/draft_review_screen.dart';

class LogDetailScreen extends ConsumerWidget {
  final int logId;

  const LogDetailScreen({super.key, required this.logId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logFuture = ref.watch(_logDetailProvider(logId));

    return logFuture.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: AppBar(), body: Center(child: Text('오류: $e'))),
      data: (log) {
        if (log == null) {
          return Scaffold(
              appBar: AppBar(), body: const Center(child: Text('기록 없음')));
        }
        return _DetailBody(log: log);
      },
    );
  }
}

final _logDetailProvider =
    FutureProvider.family<DrinkLog?, int>((ref, logId) async {
  final repo = ref.watch(drinkLogRepoProvider);
  return repo.getById(logId);
});

class _DetailBody extends ConsumerWidget {
  final DrinkLog log;

  const _DetailBody({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('M월 d일 (E) a h:mm', 'ko').format(log.drankAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 날짜 + 장소
          Text(dateStr, style: Theme.of(context).textTheme.titleMedium),
          if (log.place != null) ...[
            const SizedBox(height: 4),
            Text('📍 ${log.place}',
                style: Theme.of(context).textTheme.bodyMedium),
          ],

          const SizedBox(height: 16),

          // entries
          for (final entry in log.entries) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.liquorNameRaw,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chip(context, _categoryLabel(entry.liquorCategory)),
                        if (entry.ageStatement != null)
                          _chip(context, entry.ageStatement!),
                        _chip(context,
                            '${entry.quantityValue % 1 == 0 ? entry.quantityValue.toInt() : entry.quantityValue} ${_unitLabel(entry.quantityUnit)}'),
                        if (entry.alcoholPercent != null)
                          _chip(context, '${entry.alcoholPercent}%'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 음식
          if (log.foodItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('음식',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: log.foodItems
                  .map((f) => Chip(
                      label: Text(f),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))
                  .toList(),
            ),
          ],

          // 메모
          if (log.overallMemo != null && log.overallMemo!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('메모',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(log.overallMemo!),
          ],

          // 원본 입력
          if (log.rawInputText != null && log.rawInputText!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text('원본 입력',
                  style: Theme.of(context).textTheme.labelMedium),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(log.rawInputText!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _edit(BuildContext context, WidgetRef ref) {
    final state = DraftReviewState(
      editingLogId: log.id,
      source: log.parseSource,
      entries: log.entries
          .map((e) => DraftEntry(
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
      foodItems: log.foodItems,
      place: log.place,
      overallMemo: log.overallMemo,
      drankAt: log.drankAt,
      rawInputText: log.rawInputText,
    );

    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ProviderScope(
            overrides: [
              draftReviewProvider
                  .overrideWith((_) => DraftReviewViewModel(state)),
            ],
            child: const DraftReviewScreen(),
          ),
        ))
        .then((_) {
      ref.invalidate(_logDetailProvider(log.id!));
      ref.invalidate(logListProvider);
      ref.invalidate(recentLogsProvider);
      ref.invalidate(logCountProvider);
    });
  }

  void _delete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(drinkLogRepoProvider).delete(log.id!);
              ref.invalidate(logListProvider);
              ref.invalidate(recentLogsProvider);
              ref.invalidate(logCountProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text('삭제',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
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

  String _unitLabel(String unit) {
    const map = {
      'glass': '잔', 'shot': '샷', 'bottle': '병',
      'can': '캔', 'ml': 'ml', 'unknown': '',
    };
    return map[unit] ?? '';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/utils/date_utils.dart' as dt_utils;
import '../../core/utils/label_utils.dart';
import '../../domain/entities/drink_log.dart';
import '../../domain/entities/liquor_master.dart';
import '../../integrations/parser/parse_result.dart';
import '../../viewmodels/draft_review_viewmodel.dart';
import '../../viewmodels/log_list_viewmodel.dart';
import '../common/delete_confirm_dialog.dart';
import '../common/error_state_widget.dart';
import '../draft_review/draft_review_screen.dart';
import 'widgets/tasting_note_section.dart';

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
          appBar: AppBar(),
          body: ErrorStateWidget(
              message: '기록을 불러올 수 없습니다',
              onRetry: () => ref.invalidate(_logDetailProvider(logId)))),
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
    final day = DateFormat('M월 d일 (E)', 'ko').format(log.drankAt);
    final tod = dt_utils.timeOfDayKorean(log.drankAt);
    final time = DateFormat('h:mm').format(log.drankAt);
    final dateStr = '$day $tod $time';

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
            _EntryCard(entry: entry),
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
                id: e.id,
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
      // saveToDb이 logList, recentLogs, logCount를 이미 갱신함
    });
  }

  void _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDeleteConfirmDialog(context);
    if (confirmed == true) {
      await ref.read(logListProvider.notifier).delete(log.id!);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

}

/// liquorMaster 조회 FutureProvider — Entry 카드에서 canonicalName/subcategory 조회.
final _entryMasterProvider =
    FutureProvider.family<LiquorMaster?, int>((ref, masterId) async {
  return ref.watch(liquorMasterRepoProvider).getById(masterId);
});

class _EntryCard extends ConsumerWidget {
  final DrinkEntry entry;

  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterAsync = entry.liquorMasterId != null
        ? ref.watch(_entryMasterProvider(entry.liquorMasterId!))
        : null;
    final LiquorMaster? master = masterAsync?.valueOrNull;

    final titleKo = master?.nameKo ?? entry.liquorNameRaw;
    final titleEn = master?.canonicalName;
    final subtitleParts = <String>[
      if (master?.subcategory != null)
        subcategoryLabel(master!.category, master.subcategory)
      else
        categoryLabel(entry.liquorCategory),
      if (entry.ageStatement != null) entry.ageStatement!,
      if (entry.alcoholPercent != null) '${entry.alcoholPercent}%',
    ];
    final qty =
        entry.quantityValue % 1 == 0 ? entry.quantityValue.toInt() : entry.quantityValue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(titleKo,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (titleEn != null && titleEn != titleKo) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('($titleEn)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitleParts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 6),
            Text('$qty ${unitLabel(entry.quantityUnit)}',
                style: Theme.of(context).textTheme.titleMedium),
            if (entry.id != null) TastingNoteSection(entryId: entry.id!),
          ],
        ),
      ),
    );
  }
}

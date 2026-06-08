import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/app_routes.dart';
import '../../core/utils/date_utils.dart' as dt_utils;
import '../../core/utils/label_utils.dart';
import '../../domain/entities/drink_log.dart';
import '../../domain/entities/liquor_master.dart';
import '../../integrations/parser/parse_result.dart';
import '../../viewmodels/draft_review_viewmodel.dart';
import '../../viewmodels/log_detail_viewmodel.dart';
import '../../viewmodels/log_list_viewmodel.dart';
import '../common/delete_confirm_dialog.dart';
import '../common/error_state_widget.dart';
import 'widgets/tasting_note_section.dart';

class LogDetailScreen extends ConsumerWidget {
  final int logId;

  const LogDetailScreen({super.key, required this.logId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logFuture = ref.watch(logDetailProvider(logId));

    return logFuture.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(
          message: '기록을 불러올 수 없습니다',
          onRetry: () => ref.invalidate(logDetailProvider(logId)),
        ),
      ),
      data: (log) {
        if (log == null) {
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 48,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '기록을 찾을 수 없습니다',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '삭제되었거나 접근 권한이 없어요',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _DetailBody(log: log);
      },
    );
  }
}

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
            tooltip: '기록 수정',
            onPressed: () => _edit(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '기록 삭제',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      // 2026-05-28 integration_test capture 가 IndexedStack 환경에서 active
      // screen subtree 안 RepaintBoundary 를 찾아야 PNG 생성. ListView 자체는
      // 자동 boundary 아니라 명시 wrap 필요. (log_list_screen 과 같은 패턴)
      body: RepaintBoundary(
        child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          // 날짜 + 장소
          Text(dateStr, style: Theme.of(context).textTheme.titleMedium),
          if (log.place != null) ...[
            const SizedBox(height: 4),
            Text(
              '📍 ${log.place}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],

          if (log.rawImagePath != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(log.rawImagePath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                // temp 파일이 삭제되거나 권한 변경 시 깨진 위젯 대신 안내.
                errorBuilder: (_, _, _) => Container(
                  height: 180,
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Text(
                    '이미지를 불러올 수 없습니다',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
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
            Text(
              '음식',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: log.foodItems
                  .map(
                    (f) => Chip(
                      label: Text(f),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],

          // 메모
          if (log.overallMemo != null && log.overallMemo!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '메모',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(log.overallMemo!),
          ],

          // 원본 입력
          if (log.rawInputText != null && log.rawInputText!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text(
                '원본 입력',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    log.rawInputText!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  void _edit(BuildContext context, WidgetRef ref) {
    final state = DraftReviewState(
      editingLogId: log.id,
      source: log.parseSource,
      entries: log.entries
          .map(
            (e) => DraftEntry(
              id: e.id,
              liquorMasterId: e.liquorMasterId,
              liquorNameRaw: e.liquorNameRaw,
              liquorCategory: e.liquorCategory,
              ageStatement: e.ageStatement,
              quantityValue: e.quantityValue,
              quantityUnit: e.quantityUnit,
              isEstimated: e.isEstimated,
              alcoholPercent: e.alcoholPercent,
            ),
          )
          .toList(),
      foodItems: log.foodItems,
      place: log.place,
      overallMemo: log.overallMemo,
      drankAt: log.drankAt,
      rawInputText: log.rawInputText,
      rawImagePath: log.rawImagePath,
    );

    Navigator.of(context)
        .pushNamed(Routes.draftReview, arguments: state)
        .then((_) {
          ref.invalidate(logDetailProvider(log.id!));
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

class _EntryCard extends ConsumerWidget {
  final DrinkEntry entry;

  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterAsync = entry.liquorMasterId != null
        ? ref.watch(entryMasterProvider(entry.liquorMasterId!))
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
    final qty = entry.quantityValue % 1 == 0
        ? entry.quantityValue.toInt()
        : entry.quantityValue;

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
                  child: Text(
                    titleKo,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (titleEn != null && titleEn != titleKo) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '($titleEn)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitleParts.join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$qty ${unitLabel(entry.quantityUnit)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (entry.id != null) TastingNoteSection(entryId: entry.id!),
          ],
        ),
      ),
    );
  }
}

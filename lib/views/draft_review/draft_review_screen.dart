import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/draft_review_viewmodel.dart';
import '../../core/providers.dart';
import '../../viewmodels/home_viewmodel.dart';
import 'widgets/entry_card_widget.dart';
import 'widgets/food_chips_widget.dart';
import 'widgets/source_badge_widget.dart';

class DraftReviewScreen extends ConsumerStatefulWidget {
  const DraftReviewScreen({super.key});

  @override
  ConsumerState<DraftReviewScreen> createState() => _DraftReviewScreenState();
}

class _DraftReviewScreenState extends ConsumerState<DraftReviewScreen> {
  late final TextEditingController _placeController;
  late final TextEditingController _memoController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(draftReviewProvider);
    _placeController = TextEditingController(text: state.place ?? '');
    _memoController = TextEditingController(text: state.overallMemo ?? '');
  }

  @override
  void dispose() {
    _placeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(draftReviewProvider);
    final vm = ref.read(draftReviewProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 검토'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(context, ref),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 출처 + confidence
          SourceBadgeWidget(
            source: state.source,
            confidence: state.confidence,
          ),

          // 경고
          if (state.parseWarnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final w in state.parseWarnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 16,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(w,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 16),

          // 날짜
          _DateRow(
            drankAt: state.drankAt,
            onChanged: (dt) => vm.updateDrankAt(dt),
          ),

          const SizedBox(height: 12),

          // 장소
          TextField(
            controller: _placeController,
            decoration: const InputDecoration(
              labelText: '장소',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            onChanged: (v) => vm.updatePlace(v.isEmpty ? null : v),
          ),

          const SizedBox(height: 16),

          // 항목들
          Text('항목',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < state.entries.length; i++) ...[
            EntryCardWidget(
              index: i,
              entry: state.entries[i],
              canDelete: state.entries.length > 1,
              lowConfidence: state.confidence < 0.7,
              onChanged: (e) => vm.updateEntry(i, e),
              onDelete: () => vm.removeEntry(i),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => vm.addEntry(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('항목 추가'),
          ),

          const SizedBox(height: 16),

          // 음식
          FoodChipsWidget(
            foods: state.foodItems,
            onAdd: (f) => vm.addFood(f),
            onRemove: (i) => vm.removeFood(i),
          ),

          const SizedBox(height: 16),

          // 메모
          TextField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: '메모',
              prefixIcon: Icon(Icons.note_outlined),
            ),
            maxLines: 3,
            minLines: 1,
            onChanged: (v) => vm.updateMemo(v.isEmpty ? null : v),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    setState(() => _saving = true);
    try {
      final vm = ref.read(draftReviewProvider.notifier);
      final state = ref.read(draftReviewProvider);
      final log = vm.toSaveable();
      final repo = ref.read(drinkLogRepoProvider);
      final logId = await repo.save(log);

      // parseJob 연결
      if (state.parseJobId != null) {
        final jobRepo = ref.read(parseJobRepoProvider);
        await jobRepo.linkToLog(state.parseJobId!, logId);
      }

      // 홈 화면 데이터 갱신
      ref.invalidate(recentLogsProvider);
      ref.invalidate(logCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장했습니다'), duration: Duration(seconds: 2)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DateRow extends StatelessWidget {
  final DateTime drankAt;
  final ValueChanged<DateTime> onChanged;

  const _DateRow({required this.drankAt, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('M월 d일 (E) a h:mm', 'ko').format(drankAt);

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: drankAt,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (date == null) return;

        if (!context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(drankAt),
        );

        final newDt = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? drankAt.hour,
          time?.minute ?? drankAt.minute,
        );
        onChanged(newDt);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(dateStr, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text('변경', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

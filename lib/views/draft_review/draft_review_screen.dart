import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../viewmodels/draft_review_viewmodel.dart';
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
  bool _saved = false;

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

    return PopScope(
      canPop: _saved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('작성 취소'),
            content: const Text('저장하지 않고 나가시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('계속 작성'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('나가기'),
              ),
            ],
          ),
        );
        if (shouldLeave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('기록 검토'),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => _save(context, ref),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('저장'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // AI 실패 → 로컬 fallback 시 경고 배너 (Theme token 적용)
            if (state.showAiFailBanner) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    'AI 실패 — 로컬 파서 결과예요. 내용을 확인해주세요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    onPressed: vm.dismissAiFailBanner,
                  ),
                  dense: true,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 출처 + confidence
            SourceBadgeWidget(
              source: state.source,
              confidence: state.confidence,
            ),

            if (state.rawImagePath != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(state.rawImagePath!),
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

            // 경고
            if (state.parseWarnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final w in state.parseWarnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          w,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
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
            Text(
              '항목',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
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
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    // 0-entry 저장 차단 (Round 5 finding #18 — 항목 없는 기록은 무의미)
    final state = ref.read(draftReviewProvider);
    final validEntries =
        state.entries.where((e) => e.liquorNameRaw.trim().isNotEmpty).toList();
    if (validEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('술 이름이 있는 항목을 최소 1개 추가해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Day 1 reward — 첫 기록 저장 시 다른 message (Round 6 P2 fix)
      final isEditing = state.isEditing;
      final prevCount =
          isEditing ? -1 : await ref.read(logCountProvider.future);
      final isFirstRecord = prevCount == 0;

      final vm = ref.read(draftReviewProvider.notifier);
      await vm.saveToDb(ref);

      if (context.mounted) {
        final message = isFirstRecord
            ? '🎉 첫 기록이 저장되었어요!'
            : '저장했습니다';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: isFirstRecord ? 3 : 2),
          ),
        );
        setState(() => _saved = true);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
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

    return Semantics(
      button: true,
      label: '음주 일시 변경. 현재 $dateStr',
      child: InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: drankAt.isAfter(DateTime.now()) ? DateTime.now() : drankAt,
          firstDate: DateTime(2020),
          // 미래 날짜 입력 차단 (Round 5 Codex Finding 6)
          lastDate: DateTime.now(),
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
        // a11y: 48dp 최소 터치 타겟 확보 (vertical 14 + 콘텐츠 ≈ 50).
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(dateStr, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text('변경', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
      ),
    );
  }
}

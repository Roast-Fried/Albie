import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import 'star_rating.dart';
import 'tasting_note_edit_sheet.dart';

/// 기록 상세의 entry 카드 아래에 붙는 테이스팅 노트 섹션.
///
/// 노트 없을 때: "테이스팅 노트 작성" CTA
/// 노트 있을 때: 향/맛/피니시/별점/메모 + 편집 아이콘
class TastingNoteSection extends ConsumerWidget {
  final int entryId;

  const TastingNoteSection({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(tastingNoteByEntryProvider(entryId));

    return noteAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (note) {
        if (note == null) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('테이스팅 노트 작성'),
              onPressed: () => TastingNoteEditSheet.show(
                context,
                entryId: entryId,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('테이스팅 노트',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (note.rating != null) ...[
                      StarRating(value: note.rating!, size: 16),
                      const SizedBox(width: 6),
                      Text(note.rating!.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(width: 6),
                    ],
                    IconButton(
                      onPressed: () => TastingNoteEditSheet.show(
                        context,
                        entryId: entryId,
                        initial: note,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      iconSize: 18,
                      tooltip: '테이스팅 노트 수정',
                      // a11y: 48dp 최소 터치 타겟 (시각 아이콘은 18 유지).
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (note.nose != null && note.nose!.isNotEmpty)
                  _Row(label: '향', value: note.nose!),
                if (note.palate != null && note.palate!.isNotEmpty)
                  _Row(label: '맛', value: note.palate!),
                if (note.finish != null && note.finish!.isNotEmpty)
                  _Row(label: '피니시', value: note.finish!),
                if (note.note != null && note.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(note.note!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppPalette.accentText(Theme.of(context).brightness))),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../domain/entities/tasting_note.dart';
import 'star_rating.dart';

/// 테이스팅 노트 작성/편집 ModalBottomSheet.
///
/// 저장 시 `TastingNoteRepository.save()` 로 upsert 후
/// `tastingNoteByEntryProvider(entryId)` 를 invalidate 한다.
class TastingNoteEditSheet extends ConsumerStatefulWidget {
  final int entryId;
  final TastingNote? initial;

  const TastingNoteEditSheet({
    super.key,
    required this.entryId,
    this.initial,
  });

  static Future<void> show(
    BuildContext context, {
    required int entryId,
    TastingNote? initial,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TastingNoteEditSheet(entryId: entryId, initial: initial),
    );
  }

  @override
  ConsumerState<TastingNoteEditSheet> createState() =>
      _TastingNoteEditSheetState();
}

class _TastingNoteEditSheetState extends ConsumerState<TastingNoteEditSheet> {
  late final TextEditingController _noseCtrl;
  late final TextEditingController _palateCtrl;
  late final TextEditingController _finishCtrl;
  late final TextEditingController _memoCtrl;
  late double _rating;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final n = widget.initial;
    _noseCtrl = TextEditingController(text: n?.nose ?? '');
    _palateCtrl = TextEditingController(text: n?.palate ?? '');
    _finishCtrl = TextEditingController(text: n?.finish ?? '');
    _memoCtrl = TextEditingController(text: n?.note ?? '');
    _rating = n?.rating ?? 0.0;
  }

  @override
  void dispose() {
    _noseCtrl.dispose();
    _palateCtrl.dispose();
    _finishCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 16, bottom: 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.initial == null ? '테이스팅 노트 작성' : '테이스팅 노트 수정',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 평점
            Row(
              children: [
                Text('평점', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 12),
                StarRating(
                  value: _rating,
                  size: 28,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(width: 8),
                Text(_rating == 0 ? '미입력' : _rating.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _noseCtrl,
              decoration: const InputDecoration(
                labelText: '향 (Nose)',
                hintText: '예: 바닐라, 오크',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _palateCtrl,
              decoration: const InputDecoration(
                labelText: '맛 (Palate)',
                hintText: '예: 부드럽고 스파이시',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _finishCtrl,
              decoration: const InputDecoration(
                labelText: '피니시 (Finish)',
                hintText: '예: 길고 따뜻',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: '한 줄 감상'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
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
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(tastingNoteRepoProvider);
    final note = TastingNote(
      id: widget.initial?.id,
      entryId: widget.entryId,
      nose: _noseCtrl.text.trim().isEmpty ? null : _noseCtrl.text.trim(),
      palate: _palateCtrl.text.trim().isEmpty ? null : _palateCtrl.text.trim(),
      finish: _finishCtrl.text.trim().isEmpty ? null : _finishCtrl.text.trim(),
      rating: _rating == 0 ? null : _rating,
      note: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      createdAt: widget.initial?.createdAt,
    );
    await repo.save(note);
    if (!mounted) return;
    ref.invalidate(tastingNoteByEntryProvider(widget.entryId));
    Navigator.of(context).pop();
  }
}

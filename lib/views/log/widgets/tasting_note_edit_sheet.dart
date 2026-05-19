import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/tasting_note.dart';
import '../../../viewmodels/tasting_note_viewmodel.dart';
import 'star_rating.dart';

/// 테이스팅 노트 작성/편집 ModalBottomSheet.
///
/// 저장 시 ViewModel 계층을 통해 upsert 후 관련 provider 를 invalidate 한다.
class TastingNoteEditSheet extends ConsumerStatefulWidget {
  final int entryId;
  final TastingNote? initial;

  const TastingNoteEditSheet({super.key, required this.entryId, this.initial});

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
  final _enhanceController = TastingNoteEnhanceController();
  late double _rating;
  bool _saving = false;
  bool _enhancing = false;

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
    _enhanceController.cancel();
    _noseCtrl.dispose();
    _palateCtrl.dispose();
    _finishCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // 8-grid alignment: 24 horizontal + 16 vertical
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: 16 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 drag handle — Material 3 BottomSheet 표준 indicator
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  widget.initial == null ? '테이스팅 노트 작성' : '테이스팅 노트 수정',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _saving || _enhancing ? null : _enhance,
                  icon: _enhancing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('AI 보완'),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: _close),
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
                  onPressed: _saving ? null : _close,
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
    try {
      await saveTastingNote(ref, note);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      // CLAUDE.md rule 4 (failure path first): 저장 실패 시 _saving 고착 방지
      // + 사용자 피드백 noted SnackBar surface.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테이스팅 노트 저장에 실패했습니다')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _close() {
    _enhanceController.cancel();
    Navigator.of(context).pop();
  }

  Future<void> _enhance() async {
    setState(() => _enhancing = true);
    try {
      final outcome = await enhanceTastingNote(
        ref,
        TastingNoteDraft(
          nose: _noseCtrl.text.trim().isEmpty ? null : _noseCtrl.text.trim(),
          palate: _palateCtrl.text.trim().isEmpty
              ? null
              : _palateCtrl.text.trim(),
          finish: _finishCtrl.text.trim().isEmpty
              ? null
              : _finishCtrl.text.trim(),
          note: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        ),
        controller: _enhanceController,
      );
      if (!mounted) return;
      if (outcome.cancelled) return; // 사용자 취소 — 메시지 불필요
      // reason 별 사용자 메시지 분기 (Codex closure D MEDIUM 처리)
      // ViewModel layer 의 TastingEnhanceReason 사용 — View 가 integrations layer
      // 직접 import 안 함 (ARCH-001 의존성 방향 fix).
      final suggestion = outcome.draft;
      switch (outcome.reason) {
        case TastingEnhanceReason.success:
          if (suggestion != null) {
            _noseCtrl.text = suggestion.nose ?? _noseCtrl.text;
            _palateCtrl.text = suggestion.palate ?? _palateCtrl.text;
            _finishCtrl.text = suggestion.finish ?? _finishCtrl.text;
            _memoCtrl.text = suggestion.note ?? _memoCtrl.text;
          }
          return;
        case TastingEnhanceReason.quotaExceeded:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오늘 AI 보완 사용량을 모두 사용했습니다')),
          );
          return;
        case TastingEnhanceReason.aiDisabled:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI 보완이 비활성화되어 있습니다 (설정에서 활성화 가능)')),
          );
          return;
        case TastingEnhanceReason.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI 보완에 실패했습니다. 잠시 후 다시 시도해 주세요.')),
          );
          return;
        case TastingEnhanceReason.cancelled:
          // 사용자 취소 — 메시지 없이 silent
          return;
      }
    } catch (e) {
      // CLAUDE.md rule 4: AI 호출 실패 시 _enhancing 고착 방지 + 안내.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 보완 중 오류가 발생했습니다')),
      );
    } finally {
      if (mounted) setState(() => _enhancing = false);
    }
  }
}

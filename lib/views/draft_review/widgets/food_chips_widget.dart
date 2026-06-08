import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../viewmodels/ai_settings_viewmodel.dart';
import '../../../viewmodels/food_photo_viewmodel.dart';
import '../../home/widgets/ai_key_guide_sheet.dart';

class FoodChipsWidget extends ConsumerStatefulWidget {
  final List<String> foods;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;

  const FoodChipsWidget({
    super.key,
    required this.foods,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  ConsumerState<FoodChipsWidget> createState() => _FoodChipsWidgetState();
}

class _FoodChipsWidgetState extends ConsumerState<FoodChipsWidget> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  bool _analyzing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _controller.clear();
  }

  /// 음식 사진을 골라 AI(Gemini 비전)로 음식명을 자동 추출해 칩으로 추가.
  Future<void> _addByPhoto() async {
    final messenger = ScaffoldMessenger.of(context);

    // AI 키 게이트 — 미연결이면 연결 가이드부터.
    final aiState = ref.read(aiConfigProvider).valueOrNull;
    final aiReady =
        aiState != null && aiState.hasUserKey && aiState.config.isEnabled;
    if (!aiReady) {
      final action = await AiKeyGuideSheet.show(
        context,
        hasKey: aiState?.hasUserKey ?? false,
        showManualOption: false,
      );
      if (action != AiKeyGuideAction.registered) return;
      // 연결됨 → 계속 진행
    }

    // 이미지 선택
    final XFile? picked;
    try {
      picked = await _picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했습니다')),
      );
      return;
    }
    if (picked == null) return;

    if (!mounted) return;
    setState(() => _analyzing = true);
    try {
      final result = await extractFoodsFromPhoto(ref, picked.path);
      if (!mounted) return;
      switch (result.reason) {
        case FoodPhotoUiReason.success:
          for (final f in result.foods) {
            widget.onAdd(f);
          }
          messenger.showSnackBar(
            SnackBar(content: Text('음식 ${result.foods.length}개를 추가했어요')),
          );
        case FoodPhotoUiReason.empty:
          messenger.showSnackBar(
            const SnackBar(content: Text('사진에서 음식을 찾지 못했어요')),
          );
        case FoodPhotoUiReason.aiDisabled:
          messenger.showSnackBar(
            const SnackBar(content: Text('AI가 연결되어 있지 않아요 (설정에서 키 등록)')),
          );
        case FoodPhotoUiReason.failed:
          messenger.showSnackBar(
            const SnackBar(content: Text('음식 인식에 실패했어요. 잠시 후 다시 시도해 주세요.')),
          );
        case FoodPhotoUiReason.cancelled:
          break; // 사용자 취소 — silent
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('음식 인식 중 오류가 발생했어요')),
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('음식',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var i = 0; i < widget.foods.length; i++)
              // Round 6 X3 — shrinkWrap 제거하여 tap target 48dp 확보
              Chip(
                label: Text(widget.foods[i]),
                onDeleted: () => widget.onRemove(i),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '음식 추가',
                  isDense: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _add,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 음식 사진 → AI 자동 인식
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _analyzing ? null : _addByPhoto,
            icon: _analyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(_analyzing ? 'AI가 음식 인식 중...' : '사진으로 추가 (AI)'),
          ),
        ),
      ],
    );
  }
}

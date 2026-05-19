import 'package:flutter/material.dart';

class InputSectionWidget extends StatefulWidget {
  final List<String> placeholders;
  final String inputText;
  final String? imagePath;
  final String? imageName;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onGenerateDraft;
  final VoidCallback onCancelGenerate;
  final VoidCallback onManualInput;

  const InputSectionWidget({
    super.key,
    required this.placeholders,
    required this.inputText,
    this.imagePath,
    this.imageName,
    required this.isLoading,
    required this.onChanged,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onGenerateDraft,
    required this.onCancelGenerate,
    required this.onManualInput,
  });

  @override
  State<InputSectionWidget> createState() => _InputSectionWidgetState();
}

class _InputSectionWidgetState extends State<InputSectionWidget> {
  late final TextEditingController _controller;
  late final String _placeholder;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.inputText);
    _placeholder = widget.placeholders.first;
  }

  @override
  void didUpdateWidget(InputSectionWidget old) {
    super.didUpdateWidget(old);
    if (widget.inputText != _controller.text) {
      _controller.text = widget.inputText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasInput = widget.inputText.trim().isNotEmpty;
    final hasImage = widget.imagePath != null;
    final canGenerate = hasInput || hasImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 입력창
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          maxLines: 2,
          minLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (hasInput) widget.onGenerateDraft();
          },
          decoration: InputDecoration(
            hintText: _placeholder,
            hintMaxLines: 2,
            suffixIcon: hasInput
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                    },
                  )
                : null,
          ),
        ),

        const SizedBox(height: 8),

        if (hasImage)
          InputChip(
            avatar: const Icon(Icons.image_outlined, size: 18),
            label: Text(widget.imageName ?? '첨부 이미지'),
            onDeleted: widget.isLoading ? null : widget.onRemoveImage,
            deleteIcon: const Icon(Icons.close, size: 18),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.isLoading ? null : widget.onPickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('사진 첨부'),
            ),
          ),

        const SizedBox(height: 12),

        // 액션 버튼
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.isLoading
                    ? widget.onCancelGenerate
                    : canGenerate
                    ? widget.onGenerateDraft
                    : null,
                icon: widget.isLoading
                    ? const Icon(Icons.close, size: 18)
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(widget.isLoading ? '취소' : 'AI로 생성'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.isLoading ? null : widget.onManualInput,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('직접 입력'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

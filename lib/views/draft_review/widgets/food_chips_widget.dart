import 'package:flutter/material.dart';

class FoodChipsWidget extends StatefulWidget {
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
  State<FoodChipsWidget> createState() => _FoodChipsWidgetState();
}

class _FoodChipsWidgetState extends State<FoodChipsWidget> {
  final _controller = TextEditingController();

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
              Chip(
                label: Text(widget.foods[i]),
                onDeleted: () => widget.onRemove(i),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      ],
    );
  }
}

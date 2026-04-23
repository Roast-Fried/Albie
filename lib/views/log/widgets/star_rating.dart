import 'package:flutter/material.dart';

/// 0~5 (0.5 단위) 별점 위젯.
///
/// `onChanged == null` 이면 표시 전용, 있으면 편집 가능 (각 별의 왼/오른쪽 반 터치 구분).
class StarRating extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? Colors.amber.shade600;
    final inactive = inactiveColor ?? Theme.of(context).colorScheme.outlineVariant;
    final interactive = onChanged != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1.0;
        final fillLevel = (value - i).clamp(0.0, 1.0);
        final icon = fillLevel >= 1.0
            ? Icons.star_rounded
            : fillLevel >= 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded;
        final color = fillLevel > 0 ? active : inactive;

        Widget star = Icon(icon, size: size, color: color);

        if (!interactive) return star;

        // interactive: 별 하나를 좌/우 반으로 나눠 0.5 단위 탭
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                Positioned.fill(child: star),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged!(starValue - 0.5),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged!(starValue),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      }),
    );
  }
}

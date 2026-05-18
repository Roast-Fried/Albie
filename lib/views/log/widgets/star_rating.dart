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

    final row = Row(
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
        // a11y — 각 반 별로 명시적 button semantics (Round 6 Agent X1)
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Positioned.fill(child: star),
              Row(children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: '${starValue - 0.5}점 선택',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged!(starValue - 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: '${starValue.toInt()}점 선택',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged!(starValue),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    );

    // 표시 모드 — 전체 Row 에 단일 별점 announce 적용
    if (!interactive) {
      return Semantics(
        label: '별점 $value점',
        excludeSemantics: true,
        child: row,
      );
    }
    return row;
  }
}

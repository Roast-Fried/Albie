import 'dart:async';
import 'package:flutter/material.dart';

/// AI 생성 중 상세 로딩 표시 — 단계 메시지 순환 + 진행 바 + 경과 시간.
/// 취소는 상단 입력 영역의 '취소' 버튼으로 한다 (여기선 안내만).
class AiLoadingCard extends StatefulWidget {
  final bool hasImage;
  const AiLoadingCard({super.key, this.hasImage = false});

  @override
  State<AiLoadingCard> createState() => _AiLoadingCardState();
}

class _AiLoadingCardState extends State<AiLoadingCard> {
  Timer? _timer;
  int _elapsed = 0; // 초
  int _stage = 0;

  List<String> get _stages => widget.hasImage
      ? const [
          '이미지를 분석하고 있어요',
          '술 라벨·메뉴를 읽고 있어요',
          '초안을 정리하고 있어요',
        ]
      : const [
          '입력을 읽고 있어요',
          '술 정보를 찾고 있어요',
          '초안을 정리하고 있어요',
        ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed += 1;
        // 2초마다 다음 단계로 진행 (마지막 단계에서 멈춤)
        _stage = (_elapsed ~/ 2).clamp(0, _stages.length - 1);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _stages[_stage],
                      key: ValueKey<int>(_stage),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Text(
                  '${_elapsed}s',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 단계 진행 바 3칸
            Row(
              children: [
                for (var i = 0; i < _stages.length; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _stage
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < _stages.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'AI가 분석하는 동안 잠시만 기다려 주세요. 취소하려면 위의 버튼을 누르세요.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

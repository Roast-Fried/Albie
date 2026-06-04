import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

class SourceBadgeWidget extends StatelessWidget {
  final String source;
  final double confidence;

  const SourceBadgeWidget({
    super.key,
    required this.source,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    // 색은 AppPalette.source* SoT (WCAG AA 검증값 — light contrast ≥4.5:1).
    final (label, color) = switch (source) {
      'ai_user_key' => ('AI (사용자 키)', AppPalette.sourceAiUserKey),
      'ai_app_key' => ('AI (기본 키)', AppPalette.sourceAiAppKey),
      'local_parser' => ('로컬 파서', AppPalette.sourceLocalParser),
      'manual' => ('직접 입력', AppPalette.sourceManual),
      _ => ('알 수 없음', AppPalette.sourceManual),
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        if (source != 'manual')
          Text('신뢰도 ${(confidence * 100).toInt()}%',
              style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

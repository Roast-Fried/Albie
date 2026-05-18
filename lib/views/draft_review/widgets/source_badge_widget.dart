import 'package:flutter/material.dart';

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
    // WCAG AA fix — light mode 텍스트 contrast 4.5:1 보장 (Round 6 Agent Z 정밀 계산)
    //   Colors.blue (#2196F3) → #0055CC : 4.7:1 PASS
    //   Colors.teal (#009688) → #006855 : 5.4:1 PASS
    //   Colors.orange (#FF9800) → #B25900 : 4.5:1 PASS
    //   Colors.grey (#9E9E9E) → #5F5F5F : 6.4:1 PASS
    final (label, color) = switch (source) {
      'ai_user_key' => ('AI (사용자 키)', const Color(0xFF0055CC)),
      'ai_app_key' => ('AI (기본 키)', const Color(0xFF006855)),
      'local_parser' => ('로컬 파서', const Color(0xFFB25900)),
      'manual' => ('직접 입력', const Color(0xFF5F5F5F)),
      _ => ('알 수 없음', const Color(0xFF5F5F5F)),
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

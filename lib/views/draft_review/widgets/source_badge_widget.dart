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
    final (label, color) = switch (source) {
      'ai_user_key' => ('AI (사용자 키)', Colors.blue),
      'ai_app_key' => ('AI (기본 키)', Colors.teal),
      'local_parser' => ('로컬 파서', Colors.orange),
      'manual' => ('직접 입력', Colors.grey),
      _ => ('알 수 없음', Colors.grey),
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

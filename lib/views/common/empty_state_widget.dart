import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'brand_illustration.dart';

/// 공통 빈 상태 위젯 — 브랜드 일러스트 + 안내 + 선택 CTA.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final AlbiIllustration illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandIllustration(variant: illustration, size: 128),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                textAlign: TextAlign.center,
                style: text.titleMedium),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

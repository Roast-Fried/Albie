import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../viewmodels/ai_settings_viewmodel.dart';
import '../../common/ai_key_connect_form.dart';

/// "AI로 생성" 을 눌렀지만 AI 를 쓸 수 없을 때(키 미등록 또는 AI 미사용) 표시하는
/// 연결 가이드 바텀시트. 키 발급(브라우저)→붙여넣기→검증·저장 까지 시트 안에서 완결한다.
enum AiKeyGuideAction { registered, manualInput }

class AiKeyGuideSheet {
  const AiKeyGuideSheet._();

  /// [hasKey] true 면 "키는 있으나 AI 가 꺼져 있음" → AI 켜기, false 면 키 연결 폼.
  /// [showManualOption] false 면 "직접 입력으로 기록" 보조 버튼 숨김(온보딩용).
  static Future<AiKeyGuideAction?> show(
    BuildContext context, {
    required bool hasKey,
    bool showManualOption = true,
  }) {
    return showModalBottomSheet<AiKeyGuideAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AiKeyGuideContent(
        hasKey: hasKey,
        showManualOption: showManualOption,
      ),
    );
  }
}

class _AiKeyGuideContent extends ConsumerWidget {
  final bool hasKey;
  final bool showManualOption;

  const _AiKeyGuideContent({
    required this.hasKey,
    required this.showManualOption,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    hasKey ? Icons.toggle_off_outlined : Icons.auto_awesome,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasKey ? 'AI가 꺼져 있어요' : 'AI 분석을 쓰려면 키 연결이 필요해요',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (hasKey) ...[
                Text(
                  "키는 등록돼 있어요. 'AI 켜기' 를 누르면 자동 분석을 사용합니다.",
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(aiConfigProvider.notifier)
                        .toggleEnabled(true);
                    if (context.mounted) {
                      Navigator.of(context).pop(AiKeyGuideAction.registered);
                    }
                  },
                  icon: const Icon(Icons.power_settings_new, size: 18),
                  label: const Text('AI 켜기'),
                ),
              ] else ...[
                Text(
                  'Gemini API 키를 연결하면 자연어를 AI가 분석해 자동으로 초안을 만들어줘요.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                AiKeyConnectForm(
                  onRegistered: () =>
                      Navigator.of(context).pop(AiKeyGuideAction.registered),
                ),
              ],

              if (showManualOption) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(AiKeyGuideAction.manualInput),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('직접 입력으로 기록'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

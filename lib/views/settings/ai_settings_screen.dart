import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/ai_settings_viewmodel.dart';
import '../../domain/entities/usage_quota.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _keyCtrl = TextEditingController();
  bool _keyVisible = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(aiConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 연결 설정')),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // AI 사용 토글
            SwitchListTile(
              title: const Text('AI 사용'),
              value: state.config.isEnabled,
              onChanged: (v) =>
                  ref.read(aiConfigProvider.notifier).toggleEnabled(v),
            ),
            const Divider(),

            // 연결 모드
            const _SectionHeader('연결 모드'),
            RadioListTile<String>(
              title: const Text('기본 제한형'),
              subtitle: Text(
                  '일 ${UsageQuota.maxAppTextPerDay}회 텍스트, ${UsageQuota.maxAppImagePerDay}회 이미지'),
              value: 'app_default',
              groupValue: state.config.keyMode,
              onChanged: (v) =>
                  ref.read(aiConfigProvider.notifier).setKeyMode(v!),
            ),
            RadioListTile<String>(
              title: const Text('내 API Key 사용'),
              subtitle: const Text('제한 없음 (본인 Gemini 할당량 내)'),
              value: 'user_provided',
              groupValue: state.config.keyMode,
              onChanged: (v) =>
                  ref.read(aiConfigProvider.notifier).setKeyMode(v!),
            ),
            const Divider(),

            // API Key 입력 (user_provided 모드일 때)
            if (state.config.keyMode == 'user_provided') ...[
              const _SectionHeader('API Key'),
              if (state.hasUserKey)
                ListTile(
                  title: const Text('키 등록됨'),
                  subtitle: state.config.lastValidatedAt != null
                      ? Text(
                          '마지막 검증: ${DateFormat('M/d HH:mm').format(state.config.lastValidatedAt!)}')
                      : null,
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(aiConfigProvider.notifier).deleteApiKey(),
                    child: const Text('삭제'),
                  ),
                )
              else ...[
                TextField(
                  controller: _keyCtrl,
                  obscureText: !_keyVisible,
                  decoration: InputDecoration(
                    hintText: 'Gemini API Key',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_keyVisible
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _keyVisible = !_keyVisible),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () => _saveKey(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '⚠️ 무료 Gemini API 사용 시 입력 내용이 Google 제품 개선에 사용될 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline),
                ),
              ],
              const Divider(),
            ],

            // 모델 선택
            const _SectionHeader('모델'),
            RadioListTile<String>(
              title: const Text('Flash Lite (빠름)'),
              subtitle: const Text('gemini-2.5-flash-lite'),
              value: 'gemini-2.5-flash-lite',
              groupValue: state.config.selectedModel,
              onChanged: (v) =>
                  ref.read(aiConfigProvider.notifier).selectModel(v!),
            ),
            RadioListTile<String>(
              title: const Text('Flash (더 정확)'),
              subtitle: const Text('gemini-2.5-flash'),
              value: 'gemini-2.5-flash',
              groupValue: state.config.selectedModel,
              onChanged: (v) =>
                  ref.read(aiConfigProvider.notifier).selectModel(v!),
            ),
            const Divider(),

            // 오늘 사용량
            const _SectionHeader('오늘 사용량'),
            ListTile(
              title: const Text('텍스트'),
              trailing: Text(
                  '${state.quota.appDefaultTextCount + state.quota.userKeyTextCount}회'),
            ),
            ListTile(
              title: const Text('이미지'),
              trailing: Text(
                  '${state.quota.appDefaultImageCount + state.quota.userKeyImageCount}회'),
            ),

            // 마지막 에러
            if (state.config.lastErrorMessage != null) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('마지막 오류'),
                subtitle: Text(state.config.lastErrorMessage!,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveKey() async {
    final error =
        await ref.read(aiConfigProvider.notifier).saveApiKey(_keyCtrl.text);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      _keyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API Key가 등록되었습니다')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/usage_quota.dart';
import '../../viewmodels/ai_settings_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../common/delete_confirm_dialog.dart';
import 'ai_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiAsync = ref.watch(aiConfigProvider);
    final dataAsync = ref.watch(settingsDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // ── AI 연결 ──
          const _SectionHeader('AI 연결'),
          aiAsync.when(
            loading: () => const ListTile(
              leading: Icon(Icons.smart_toy_outlined),
              title: Text('AI 사용'),
              subtitle: Text('로딩 중...'),
            ),
            error: (_, _) => const ListTile(
              leading: Icon(Icons.smart_toy_outlined),
              title: Text('AI 사용'),
              subtitle: Text('로드 실패'),
            ),
            data: (state) {
              final quota = state.quota;
              final total = quota.appDefaultTextCount +
                  quota.userKeyTextCount;
              return Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.smart_toy_outlined),
                    title: const Text('AI 사용'),
                    subtitle: Text(
                      state.config.isEnabled ? 'AI 파싱 활성화됨' : '로컬 파서만 사용',
                    ),
                    value: state.config.isEnabled,
                    onChanged: (v) =>
                        ref.read(aiConfigProvider.notifier).toggleEnabled(v),
                  ),
                  if (state.config.keyMode == 'app_default')
                    ListTile(
                      leading: const Icon(Icons.speed_outlined),
                      title: const Text('오늘 사용량'),
                      subtitle: Text(
                          '텍스트 $total / ${UsageQuota.maxAppTextPerDay}회'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.tune_outlined),
                    title: const Text('AI 설정 상세'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AiSettingsScreen())),
                  ),
                ],
              );
            },
          ),

          const Divider(),

          // ── 데이터 ──
          const _SectionHeader('데이터'),
          dataAsync.when(
            loading: () => const ListTile(
                leading: Icon(Icons.inventory_2_outlined),
                title: Text('로딩 중...')),
            error: (_, _) => const ListTile(
                leading: Icon(Icons.inventory_2_outlined),
                title: Text('데이터 로드 실패')),
            data: (snap) => Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('전체 기록 수'),
                  trailing: Text('${snap.totalLogs}건'),
                ),
                ListTile(
                  leading: const Icon(Icons.wine_bar_outlined),
                  title: const Text('마셔본 술'),
                  trailing: Text('${snap.totalMasters}종'),
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever,
                      color: Theme.of(context).colorScheme.error),
                  title: Text('데이터 초기화',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  onTap: () => _confirmReset(context, ref),
                ),
              ],
            ),
          ),

          const Divider(),

          // ── 정보 ──
          const _SectionHeader('정보'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('버전'),
            subtitle: Text('0.1.0'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDeleteConfirmDialog(
      context,
      title: '데이터 초기화',
      content:
          '모든 음주 기록과 테이스팅 노트가 삭제됩니다.\n복구할 수 없습니다.\n계속하시겠습니까?',
    );
    if (ok != true) return;
    await resetAllRecords(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('모든 기록이 삭제되었습니다')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

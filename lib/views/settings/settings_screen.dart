import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/app_settings_viewmodel.dart';
import '../../viewmodels/ai_settings_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/theme_mode_viewmodel.dart';
import '../common/delete_confirm_dialog.dart';
import 'ai_settings_screen.dart';
import 'notification_settings_screen.dart';

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
                  ListTile(
                    leading: const Icon(Icons.tune_outlined),
                    title: const Text('AI 설정 상세'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiSettingsScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('알림'),
                    subtitle: const Text('재방문 reminder + 주간 요약 + 건강 신호'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const Divider(),

          // ── 일반 ──
          const _SectionHeader('일반'),
          Consumer(
            builder: (context, ref, _) {
              final modeAsync = ref.watch(themeModeProvider);
              final mode = modeAsync.valueOrNull ?? ThemeMode.system;
              return ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('다크 모드'),
                subtitle: Text(themeModeLabel(mode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context, ref, mode),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final settings =
                  ref.watch(appSettingsProvider).valueOrNull ??
                  const AppSettingsState();
              return ListTile(
                leading: const Icon(Icons.local_bar_outlined),
                title: const Text('기본 수량 단위'),
                subtitle: Text(quantityUnitLabel(settings.defaultQuantityUnit)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _showUnitDialog(context, ref, settings.defaultQuantityUnit),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final settings =
                  ref.watch(appSettingsProvider).valueOrNull ??
                  const AppSettingsState();
              return SwitchListTile(
                secondary: const Icon(Icons.schedule_outlined),
                title: const Text('6시 컷오프'),
                subtitle: const Text('새벽 기록을 전날 음주로 분류'),
                value: settings.sixHourCutoffEnabled,
                onChanged: (v) => ref
                    .read(appSettingsProvider.notifier)
                    .setSixHourCutoffEnabled(v),
              );
            },
          ),

          const Divider(),

          // ── 데이터 ──
          const _SectionHeader('데이터'),
          dataAsync.when(
            loading: () => const ListTile(
              leading: Icon(Icons.inventory_2_outlined),
              title: Text('로딩 중...'),
            ),
            error: (_, _) => const ListTile(
              leading: Icon(Icons.inventory_2_outlined),
              title: Text('데이터 로드 실패'),
            ),
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
                  leading: Icon(
                    Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    '데이터 초기화',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('오픈소스 라이선스'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '알비',
              applicationVersion: '0.1.0',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('다크 모드'),
        children: ThemeMode.values
            .map(
              (m) => RadioListTile<ThemeMode>(
                title: Text(themeModeLabel(m)),
                value: m,
                groupValue: current,
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      await ref.read(themeModeProvider.notifier).setMode(selected);
    }
  }

  Future<void> _showUnitDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    const units = ['glass', 'shot', 'bottle', 'can', 'ml', 'unknown'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('기본 수량 단위'),
        children: units
            .map(
              (u) => RadioListTile<String>(
                title: Text(quantityUnitLabel(u)),
                value: u,
                groupValue: current,
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      await ref
          .read(appSettingsProvider.notifier)
          .setDefaultQuantityUnit(selected);
    }
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDeleteConfirmDialog(
      context,
      title: '데이터 초기화',
      content: '모든 음주 기록과 테이스팅 노트가 삭제됩니다.\n복구할 수 없습니다.\n계속하시겠습니까?',
    );
    if (ok != true) return;
    await resetAllRecords(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('모든 기록이 삭제되었습니다')));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

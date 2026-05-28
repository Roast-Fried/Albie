import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/notification_settings_viewmodel.dart';

/// Phase C2 알림 설정 화면 — Settings 의 "알림" 항목에서 진입.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('설정을 불러올 수 없습니다: $e')),
        data: (s) {
          final vm = ref.read(notificationSettingsProvider.notifier);
          final disabled = !s.masterEnabled || !s.permissionGranted;

          return ListView(
            children: [
              SwitchListTile(
                title: const Text('알림 사용'),
                subtitle: Text(
                  s.permissionGranted
                      ? '재방문 reminder + 주간 요약 + 건강 신호'
                      : 'OS 권한 미허용 — 활성화 시 권한 요청',
                ),
                value: s.masterEnabled && s.permissionGranted,
                onChanged: (v) => vm.setMaster(v),
              ),
              if (!s.permissionGranted)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Text(
                    '⚠ OS 알림 권한이 꺼져있어요. 시스템 설정에서 권한을 허용해야 알림을 받을 수 있어요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                  ),
                ),
              const Divider(),
              SwitchListTile(
                title: const Text('주간 요약'),
                subtitle: const Text('매주 일요일 21시 — 이번 주 기록 N건'),
                value: s.weeklySummary,
                onChanged: disabled ? null : (v) => vm.setWeekly(v),
              ),
              SwitchListTile(
                title: const Text('재방문 reminder'),
                subtitle: const Text('3일 이상 미기록 시 — 한 동안 기록이 없어요'),
                value: s.atRiskReminder,
                onChanged: disabled ? null : (v) => vm.setAtRisk(v),
              ),
              SwitchListTile(
                title: const Text('새벽 음주 follow-up'),
                subtitle:
                    const Text('새벽 음주 → 같은 날 오후 — 추가로 기록할 것 있나요?'),
                value: s.lateNightFollowup,
                onChanged: disabled ? null : (v) => vm.setLateNight(v),
              ),
              SwitchListTile(
                title: const Text('주간 건강 신호'),
                subtitle:
                    const Text('주간 표준잔 14잔 초과 시 일요일 19시 — 휴식 권장'),
                value: s.healthSignal,
                onChanged: disabled ? null : (v) => vm.setHealth(v),
              ),
            ],
          );
        },
      ),
    );
  }
}

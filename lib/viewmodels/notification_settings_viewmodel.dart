import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integrations/notification/notification_service.dart';

/// Phase C2 알림 설정 — type 별 on/off toggle + 권한 상태.
///
/// SharedPreferences 저장. 전체 master toggle + 4 시나리오 별 toggle.
class NotificationSettingsState {
  /// 마스터 — 모두 비활성화하면 전체 schedule 취소.
  final bool masterEnabled;
  final bool weeklySummary;
  final bool atRiskReminder;
  final bool lateNightFollowup;
  final bool healthSignal;

  /// device 권한 (Android 13+ / iOS) — 실제 OS 권한.
  final bool permissionGranted;

  const NotificationSettingsState({
    this.masterEnabled = true,
    this.weeklySummary = true,
    this.atRiskReminder = true,
    this.lateNightFollowup = true,
    this.healthSignal = true,
    this.permissionGranted = false,
  });

  NotificationSettingsState copyWith({
    bool? masterEnabled,
    bool? weeklySummary,
    bool? atRiskReminder,
    bool? lateNightFollowup,
    bool? healthSignal,
    bool? permissionGranted,
  }) {
    return NotificationSettingsState(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      weeklySummary: weeklySummary ?? this.weeklySummary,
      atRiskReminder: atRiskReminder ?? this.atRiskReminder,
      lateNightFollowup: lateNightFollowup ?? this.lateNightFollowup,
      healthSignal: healthSignal ?? this.healthSignal,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }

  /// 어떤 시나리오라도 활성이면 true — schedule 운영 여부.
  bool get anyTypeActive =>
      masterEnabled &&
      (weeklySummary || atRiskReminder || lateNightFollowup || healthSignal);
}

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettingsState> {
  static const _kMaster = 'notif_master_enabled';
  static const _kWeekly = 'notif_weekly_summary';
  static const _kAtRisk = 'notif_at_risk';
  static const _kLateNight = 'notif_late_night';
  static const _kHealth = 'notif_health_signal';

  @override
  Future<NotificationSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final perm = await NotificationService.instance.isPermissionGranted();

    return NotificationSettingsState(
      masterEnabled: prefs.getBool(_kMaster) ?? true,
      weeklySummary: prefs.getBool(_kWeekly) ?? true,
      atRiskReminder: prefs.getBool(_kAtRisk) ?? true,
      lateNightFollowup: prefs.getBool(_kLateNight) ?? true,
      healthSignal: prefs.getBool(_kHealth) ?? true,
      permissionGranted: perm,
    );
  }

  Future<void> _save(NotificationSettingsState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMaster, s.masterEnabled);
    await prefs.setBool(_kWeekly, s.weeklySummary);
    await prefs.setBool(_kAtRisk, s.atRiskReminder);
    await prefs.setBool(_kLateNight, s.lateNightFollowup);
    await prefs.setBool(_kHealth, s.healthSignal);
    state = AsyncData(s);

    // master off 또는 모든 type off 면 schedule 취소.
    if (!s.anyTypeActive) {
      await NotificationService.instance.cancelAll();
    }
  }

  Future<void> setMaster(bool v) async {
    final cur = state.valueOrNull ?? const NotificationSettingsState();
    if (v && !cur.permissionGranted) {
      final granted = await NotificationService.instance.requestPermission();
      await _save(cur.copyWith(masterEnabled: v, permissionGranted: granted));
    } else {
      await _save(cur.copyWith(masterEnabled: v));
    }
  }

  Future<void> setWeekly(bool v) async {
    final cur = state.valueOrNull ?? const NotificationSettingsState();
    await _save(cur.copyWith(weeklySummary: v));
  }

  Future<void> setAtRisk(bool v) async {
    final cur = state.valueOrNull ?? const NotificationSettingsState();
    await _save(cur.copyWith(atRiskReminder: v));
  }

  Future<void> setLateNight(bool v) async {
    final cur = state.valueOrNull ?? const NotificationSettingsState();
    await _save(cur.copyWith(lateNightFollowup: v));
  }

  Future<void> setHealth(bool v) async {
    final cur = state.valueOrNull ?? const NotificationSettingsState();
    await _save(cur.copyWith(healthSignal: v));
  }

  Future<void> refreshPermission() async {
    final cur = state.valueOrNull ?? const NotificationSettingsState();
    final perm = await NotificationService.instance.isPermissionGranted();
    state = AsyncData(cur.copyWith(permissionGranted: perm));
  }
}

final notificationSettingsProvider = AsyncNotifierProvider<
    NotificationSettingsNotifier, NotificationSettingsState>(
  NotificationSettingsNotifier.new,
);

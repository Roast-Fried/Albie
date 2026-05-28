import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 로컬 알림 service — Phase C2 (재방문 reminder + 주간 요약 + 건강 신호).
///
/// flutter_local_notifications 기반. 서버 push (FCM) 가 아닌 device-local
/// schedule. timezone 패키지로 한국 시간 (Asia/Seoul) 기준 스케줄링.
///
/// 시나리오 ID (notification ID):
/// - 100: Day 7 weekly summary (매주 일요일 21:00)
/// - 200: Day 14 at-risk (3일 이상 미기록 시)
/// - 300: 새벽 음주 다음날 (입력 시각 0~5시 → 같은 날 14:00)
/// - 400: 주간 건강 신호 (주간 표준잔 초과 시 일요일 19:00)
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 앱 시작 시 1회 호출. timezone DB init + plugin 설정 + Android 알림 channel.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'albi_reminder',
          '알비 알림',
          description: '재방문 reminder + 주간 요약 + 건강 신호',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// 알림 권한 요청 — Android 13+ / iOS 모두 명시 권한 필요.
  /// 반환: true = 허용, false = 거부.
  Future<bool> requestPermission() async {
    if (!_initialized) await init();

    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    }

    return true; // desktop 등은 noop 으로 통과.
  }

  /// 권한 현재 상태 — UI toggle 의 초기 값 결정용.
  Future<bool> isPermissionGranted() async {
    if (!_initialized) await init();

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    // iOS 는 API 부재 — 마지막 request 결과 기반 (UI 가 별도 관리).
    return true;
  }

  // ---- 시나리오 별 스케줄러 ----

  static const int idWeeklySummary = 100;
  static const int idAtRisk = 200;
  static const int idLateNightFollowup = 300;
  static const int idHealthSignal = 400;

  static const _channelDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'albi_reminder',
      '알비 알림',
      channelDescription: '재방문 reminder + 주간 요약 + 건강 신호',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Day 7 주간 요약 — 매주 일요일 21:00.
  Future<void> scheduleWeeklySummary({int totalCount = 0}) async {
    final next = _nextWeekday(DateTime.sunday, hour: 21, minute: 0);
    final body = totalCount > 0
        ? '이번 주 $totalCount건 기록했어요. 한 잔의 기억을 정리해 볼까요?'
        : '이번 주 음주 기록이 없어요. 오늘 한 줄 남겨볼까요?';
    await _scheduleAt(
      id: idWeeklySummary,
      title: '이번 주 알비 요약',
      body: body,
      when: next,
    );
  }

  /// Day 14 at-risk — 3일 이상 미기록 시 호출 (cancel 후 재스케줄).
  Future<void> scheduleAtRiskReminder({
    required DateTime lastDrankAt,
  }) async {
    final triggerAt = lastDrankAt.add(const Duration(days: 3));
    if (triggerAt.isBefore(DateTime.now())) {
      // 이미 3일 경과 → 다음 저녁 19:00 알림.
      final tonight = _nextDailyAt(hour: 19, minute: 0);
      await _scheduleAt(
        id: idAtRisk,
        title: '오랜만이에요',
        body: '한 동안 기록이 없어요. 오늘 한 잔 드셨다면 알비에 남겨주세요.',
        when: tonight,
      );
      return;
    }
    await _scheduleAt(
      id: idAtRisk,
      title: '오랜만이에요',
      body: '마지막 기록으로부터 3일이 지났어요. 한 동안 기록이 없어요.',
      when: tz.TZDateTime.from(triggerAt, tz.local),
    );
  }

  /// 새벽 음주 (drankAt 시각 0~5시) → 같은 날 14:00 추가 기록 안내.
  Future<void> scheduleLateNightFollowup({
    required DateTime drankAt,
  }) async {
    if (drankAt.hour < 0 || drankAt.hour >= 6) return; // 새벽 아님 → skip.
    final followup = DateTime(drankAt.year, drankAt.month, drankAt.day, 14, 0);
    if (followup.isBefore(DateTime.now())) return; // 과거면 skip.
    await _scheduleAt(
      id: idLateNightFollowup,
      title: '어제 새벽 기록',
      body: '새벽에 마신 술이 있어요. 추가로 적어둘 게 있을까요?',
      when: tz.TZDateTime.from(followup, tz.local),
    );
  }

  /// 주간 건강 신호 — 일요일 19:00, 주간 표준잔 초과 시.
  Future<void> scheduleHealthSignal({
    required double weeklyStandardDrinks,
    double threshold = 14.0,
  }) async {
    if (weeklyStandardDrinks < threshold) {
      await _plugin.cancel(idHealthSignal);
      return;
    }
    final next = _nextWeekday(DateTime.sunday, hour: 19, minute: 0);
    await _scheduleAt(
      id: idHealthSignal,
      title: '한 주 알코올 점검',
      body:
          '이번 주 ${weeklyStandardDrinks.toStringAsFixed(1)} 표준잔 — 권장량 $threshold잔을 넘었어요. 휴식이 필요해요.',
      when: next,
    );
  }

  /// 즉시 발송 — 디버그/테스트 용.
  Future<void> showNow({required String title, required String body}) async {
    if (!_initialized) await init();
    await _plugin.show(0, title, body, _channelDetails);
  }

  /// 모든 schedule 취소 — Settings 의 알림 off 시.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ---- 내부 ----

  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    if (!_initialized) await init();
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _channelDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // 권한 부재 등 — 조용히 swallow + debug log.
      debugPrint('NotificationService schedule fail (id=$id): $e');
    }
  }

  tz.TZDateTime _nextWeekday(int weekday, {required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (next.weekday != weekday || !next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  tz.TZDateTime _nextDailyAt({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }
}

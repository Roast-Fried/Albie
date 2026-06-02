import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/draft_review_viewmodel.dart';
import '../views/archive/archive_detail_screen.dart';
import '../views/archive/archive_screen.dart';
import '../views/calendar/calendar_screen.dart';
import '../views/common/animations.dart';
import '../views/common/route_error_screen.dart';
import '../views/draft_review/draft_review_screen.dart';
import '../views/log/log_detail_screen.dart';
import '../views/settings/ai_settings_screen.dart';
import '../views/settings/notification_settings_screen.dart';
import '../views/settings/settings_screen.dart';
import '../views/stats/stats_screen.dart';

/// 앱 Named Route 경로 상수 — 오타 방지 + 자동완성(EffectiveNavigator 강의).
///
/// 3 탭(홈/기록/더보기)은 IndexedStack 으로 유지되므로 라우트가 아니다. 여기서는
/// 스택 push 되는 보조 화면만 등록한다.
class Routes {
  Routes._();

  static const logDetail = '/log/detail'; // arguments: int logId
  static const draftReview = '/draft-review'; // arguments: DraftReviewState
  static const archive = '/archive';
  static const archiveDetail = '/archive/detail'; // arguments: int masterId
  static const stats = '/stats';
  static const calendar = '/calendar';
  static const settings = '/settings';
  static const aiSettings = '/settings/ai';
  static const notifications = '/settings/notifications';
}

/// 중앙 라우팅 테이블 — `settings.arguments` 타입을 검증한 뒤 화면으로 연결하고,
/// 알 수 없는 경로 / 인자 불일치는 RouteErrorScreen 으로 안전 처리한다
/// (EffectiveNavigator onGenerateRoute 패턴). 화면 전환은 공통 fadeSlideRoute.
///
/// DraftReviewScreen 은 런타임 DI(ProviderScope override)가 필요하므로
/// onGenerateRoute 안에서 DraftReviewState 인자를 받아 구성한다 — onGenerateRoute
/// 의 "복잡한 생성 + 인자 검증" 강점을 보여주는 사례.
Route<dynamic> generateRoute(RouteSettings settings) {
  final args = settings.arguments;
  switch (settings.name) {
    case Routes.logDetail:
      if (args is int) {
        return fadeSlideRoute(LogDetailScreen(logId: args), settings: settings);
      }
      return _error(settings, '잘못된 기록 정보입니다');

    case Routes.draftReview:
      if (args is DraftReviewState) {
        return fadeSlideRoute(
          ProviderScope(
            overrides: [
              draftReviewProvider
                  .overrideWith((_) => DraftReviewViewModel(args)),
            ],
            child: const DraftReviewScreen(),
          ),
          settings: settings,
        );
      }
      return _error(settings, '검토할 초안 정보가 없습니다');

    case Routes.archive:
      return fadeSlideRoute(const ArchiveScreen(), settings: settings);

    case Routes.archiveDetail:
      if (args is int) {
        return fadeSlideRoute(
          ArchiveDetailScreen(masterId: args),
          settings: settings,
        );
      }
      return _error(settings, '잘못된 마스터 정보입니다');

    case Routes.stats:
      return fadeSlideRoute(const StatsScreen(), settings: settings);

    case Routes.calendar:
      return fadeSlideRoute(const CalendarScreen(), settings: settings);

    case Routes.settings:
      return fadeSlideRoute(const SettingsScreen(), settings: settings);

    case Routes.aiSettings:
      return fadeSlideRoute(const AiSettingsScreen(), settings: settings);

    case Routes.notifications:
      return fadeSlideRoute(
        const NotificationSettingsScreen(),
        settings: settings,
      );

    default:
      return _error(settings, '알 수 없는 경로입니다: ${settings.name}');
  }
}

Route<dynamic> _error(RouteSettings settings, String message) =>
    fadeSlideRoute(RouteErrorScreen(message: message), settings: settings);

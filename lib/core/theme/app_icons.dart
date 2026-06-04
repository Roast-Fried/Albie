import 'package:flutter/material.dart';

/// 알비 아이콘 토큰 — 의미별 아이콘 중앙 매핑.
///
/// 화면들이 `Icons.X` 를 산발 사용하던 것을 의미 기반으로 통일한다.
/// 값은 기존 사용 IconData 를 보존(테스트 `find.byIcon` 호환).
class AppIcons {
  AppIcons._();

  // 탭/네비게이션
  static const IconData home = Icons.local_bar_outlined;
  static const IconData logs = Icons.list_alt_outlined;
  static const IconData more = Icons.more_horiz;
  static const IconData chevron = Icons.chevron_right;
  static const IconData back = Icons.arrow_back;

  // 액션
  static const IconData add = Icons.add;
  static const IconData close = Icons.close;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline;
  static const IconData search = Icons.search;
  static const IconData settings = Icons.settings;
  static const IconData tune = Icons.tune_outlined;
  static const IconData logout = Icons.logout;

  // 도메인 (술/기록)
  static const IconData drink = Icons.wine_bar_outlined;
  static const IconData drinkFilled = Icons.wine_bar;
  static const IconData glass = Icons.local_bar_outlined;
  static const IconData liquid = Icons.local_drink_outlined;
  static const IconData place = Icons.place_outlined;
  static const IconData note = Icons.note_outlined;
  static const IconData notes = Icons.notes_outlined;
  static const IconData image = Icons.image_outlined;
  static const IconData condition = Icons.monitor_heart_outlined;
  static const IconData history = Icons.history_rounded;
  static const IconData calendar = Icons.calendar_month_outlined;
  static const IconData stats = Icons.bar_chart_rounded;
  static const IconData archive = Icons.inventory_2_outlined;
  static const IconData achievement = Icons.emoji_events;

  // AI
  static const IconData ai = Icons.smart_toy_outlined;
  static const IconData aiSpark = Icons.auto_awesome;
  static const IconData offline = Icons.offline_bolt_outlined;

  // 상태/피드백
  static const IconData errorOutline = Icons.error_outline;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData success = Icons.check_circle;
  static const IconData info = Icons.info_outline;
  static const IconData schedule = Icons.schedule_outlined;
  static const IconData notification = Icons.notifications_outlined;
  static const IconData lock = Icons.lock_outline;
  static const IconData visible = Icons.visibility;
  static const IconData hidden = Icons.visibility_off;

  // 즐겨찾기/평점
  static const IconData favorite = Icons.favorite;
  static const IconData favoriteBorder = Icons.favorite_border;
  static const IconData star = Icons.star_rounded;
  static const IconData starHalf = Icons.star_half_rounded;
  static const IconData starOutline = Icons.star_outline_rounded;
}

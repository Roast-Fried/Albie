import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/drink_log.dart';

/// 시각을 제거한 날짜 키 — 캘린더 그룹핑/조회에 공통 사용.
DateTime calendarDayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// 전체 음주 기록을 일자별로 그룹핑한 맵 — 캘린더 마커 + 선택일 리스트용.
///
/// 기존 in-memory 필터 패턴(recentFrequentLiquors / thisMonthLogCount)과 동일하게
/// `getAll()` 결과를 메모리에서 그룹핑한다(개인 기록 앱이라 규모가 작아 신규 쿼리
/// 없이 재사용 — Scope Discipline). `drankAt` 은 6시 컷오프가 이미 반영된 최종
/// 시각이므로 추가 보정 없이 날짜로 그룹핑한다.
final calendarLogsByDayProvider =
    FutureProvider<Map<DateTime, List<DrinkLog>>>((ref) async {
  final logs = await ref.watch(drinkLogRepoProvider).getAll();
  return groupLogsByDay(logs);
});

/// 로그 리스트를 일자별로 그룹핑(각 날짜 내 최신 우선) — 순수 함수(테스트 용이).
Map<DateTime, List<DrinkLog>> groupLogsByDay(List<DrinkLog> logs) {
  final byDay = <DateTime, List<DrinkLog>>{};
  for (final log in logs) {
    (byDay[calendarDayKey(log.drankAt)] ??= <DrinkLog>[]).add(log);
  }
  for (final list in byDay.values) {
    list.sort((a, b) => b.drankAt.compareTo(a.drankAt));
  }
  return byDay;
}

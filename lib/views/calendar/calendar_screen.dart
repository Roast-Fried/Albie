import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/app_routes.dart';
import '../../core/utils/date_utils.dart' as dt_utils;
import '../../core/utils/label_utils.dart';
import '../../domain/entities/drink_log.dart';
import '../../viewmodels/calendar_viewmodel.dart';
import '../common/animations.dart';
import '../common/error_state_widget.dart';

/// 월별 음주 캘린더 — 마신 날에 마커 표시, 날짜 선택 시 해당일 기록 목록.
///
/// 강의 고득점 예시(캘린더) + 실생활 유용성("이번 달 며칠 마셨나"). 기존
/// sqflite/Riverpod 만 사용(table_calendar 는 표시 위젯). 기록 0 인 날은 마커 없음.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay = calendarDayKey(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final byDayAsync = ref.watch(calendarLogsByDayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('음주 캘린더')),
      body: RepaintBoundary(
        child: byDayAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorStateWidget(
            message: '캘린더를 불러올 수 없습니다',
            onRetry: () => ref.invalidate(calendarLogsByDayProvider),
          ),
          data: (byDay) {
            final selectedLogs = byDay[_selectedDay] ?? const <DrinkLog>[];
            return Column(
              children: [
                _buildCalendar(context, byDay),
                const Divider(height: 1),
                Expanded(
                  child: _DaySection(day: _selectedDay, logs: selectedLogs),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    Map<DateTime, List<DrinkLog>> byDay,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return TableCalendar<DrinkLog>(
      locale: 'ko_KR',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2100, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: '월'},
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: (day) => byDay[calendarDayKey(day)] ?? const <DrinkLog>[],
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = calendarDayKey(selectedDay);
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) => _focusedDay = focusedDay,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarStyle: CalendarStyle(
        markerDecoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
        todayDecoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(color: scheme.onPrimaryContainer),
        selectedDecoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      // a11y: 기본 마커 점은 스크린리더가 못 읽음 → 동일 비주얼 + 기록 건수 라벨.
      calendarBuilders: CalendarBuilders<DrinkLog>(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return const SizedBox.shrink();
          final count = events.length;
          final dots = count > 3 ? 3 : count;
          return Semantics(
            label: '기록 $count건',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < dots; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 선택한 날짜의 기록 목록 (없으면 빈 상태).
class _DaySection extends StatelessWidget {
  const _DaySection({required this.day, required this.logs});

  final DateTime day;
  final List<DrinkLog> logs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = DateFormat('M월 d일 (E)', 'ko').format(day);

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_drink_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              '$label 은 기록이 없어요',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Text(
          '$label · ${logs.length}건',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppPalette.accentText(Theme.of(context).brightness),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        for (final log in logs)
          AppearAnimation(child: _DayLogTile(log: log)),
      ],
    );
  }
}

class _DayLogTile extends StatelessWidget {
  const _DayLogTile({required this.log});

  final DrinkLog log;

  @override
  Widget build(BuildContext context) {
    final tod = dt_utils.timeOfDayKorean(log.drankAt);
    final time = DateFormat('h:mm').format(log.drankAt);
    final summary = log.entries
        .map((e) =>
            '${e.liquorNameRaw} ${e.quantityValue % 1 == 0 ? e.quantityValue.toInt() : e.quantityValue}${unitLabel(e.quantityUnit)}')
        .join(', ');

    return Card(
      child: ListTile(
        title: Text(summary.isEmpty ? '(항목 없음)' : summary),
        subtitle: Text(
          '$tod $time${log.place != null ? ' · 📍 ${log.place}' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed(
          Routes.logDetail,
          arguments: log.id!,
        ),
      ),
    );
  }
}

import 'package:albi/domain/entities/drink_log.dart';
import 'package:albi/viewmodels/calendar_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

DrinkLog _log(DateTime at) => DrinkLog(drankAt: at);

void main() {
  group('calendarDayKey — 시각 제거 정규화', () {
    test('같은 날의 다른 시각은 동일 키', () {
      final a = calendarDayKey(DateTime(2026, 5, 12, 1, 30));
      final b = calendarDayKey(DateTime(2026, 5, 12, 23, 59));
      expect(a, b);
      expect(a, DateTime(2026, 5, 12));
    });

    test('다른 날은 다른 키', () {
      expect(
        calendarDayKey(DateTime(2026, 5, 12, 23)),
        isNot(calendarDayKey(DateTime(2026, 5, 13, 0))),
      );
    });
  });

  group('groupLogsByDay — 일자별 그룹핑 + 정렬', () {
    test('같은 날 기록은 한 키에 묶이고 최신 우선 정렬', () {
      final early = _log(DateTime(2026, 5, 12, 18));
      final late = _log(DateTime(2026, 5, 12, 22));
      final other = _log(DateTime(2026, 5, 13, 9));

      final byDay = groupLogsByDay([early, late, other]);

      expect(byDay.keys.length, 2);
      final may12 = byDay[DateTime(2026, 5, 12)]!;
      expect(may12.length, 2);
      expect(may12.first.drankAt, late.drankAt); // 최신 우선
      expect(byDay[DateTime(2026, 5, 13)]!.length, 1);
    });

    test('빈 리스트는 빈 맵', () {
      expect(groupLogsByDay(const []), isEmpty);
    });
  });
}

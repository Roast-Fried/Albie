@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:albi/views/home/home_screen.dart';
import 'package:albi/core/providers.dart';
import 'package:albi/viewmodels/home_viewmodel.dart';
import 'package:albi/domain/entities/drink_log.dart';
import 'golden_helper.dart';

void main() {
  setUpAll(setupGoldenTests);

  group('HomeScreen Golden', () {
    testWidgets('empty state', (tester) async {
      await tester.pumpWidget(
        goldenWrapper(
          const HomeScreen(),
          overrides: [
            recentLogsProvider.overrideWith((_) async => <DrinkLog>[]),
            logCountProvider.overrideWith((_) async => 0),
            homeViewModelProvider.overrideWith(
              (_) => HomeViewModel.forTest(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_empty.png'),
      );
    });

    testWidgets('with recent logs', (tester) async {
      final now = DateTime(2026, 3, 30, 22, 0);
      final logs = [
        DrinkLog(
          id: 1,
          rawInputText: '벤로막 15 두 잔',
          parseSource: 'local_parser',
          place: '바',
          drankAt: now,
          entries: [
            DrinkEntry(
              id: 1,
              logId: 1,
              liquorNameRaw: '벤로마크',
              liquorCategory: 'whisky',
              ageStatement: '15년',
              quantityValue: 2,
              quantityUnit: 'glass',
              isEstimated: false,
            ),
          ],
          foodItems: ['육회'],
        ),
        DrinkLog(
          id: 2,
          rawInputText: '하이볼 한 잔',
          parseSource: 'local_parser',
          drankAt: now.subtract(const Duration(days: 1)),
          entries: [
            DrinkEntry(
              id: 2,
              logId: 2,
              liquorNameRaw: '하이볼',
              liquorCategory: 'highball',
              quantityValue: 1,
              quantityUnit: 'glass',
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        goldenWrapper(
          const HomeScreen(),
          overrides: [
            recentLogsProvider.overrideWith((_) async => logs),
            logCountProvider.overrideWith((_) async => 5),
            homeViewModelProvider.overrideWith(
              (_) => HomeViewModel.forTest(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_with_logs.png'),
      );
    });
  });
}

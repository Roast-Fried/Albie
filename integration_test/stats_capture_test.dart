import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

import '_screenshot_helper.dart';

/// 통계 화면 — 기간 필터 / 차트 / 스크롤.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stats — 모든 기간 + 스크롤 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(true);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    await tapText(tester, '더보기');
    await tapText(tester, '통계');

    // 1. 통계 초기 (이번 달)
    await takeShot(tester, 'stats_01_this_month');

    // 2. 3개월 필터
    final three = find.text('3개월');
    if (three.evaluate().isNotEmpty) {
      await tester.tap(three.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeShot(tester, 'stats_02_three_months');
    }

    // 3. 전체
    final all = find.text('전체');
    if (all.evaluate().isNotEmpty) {
      await tester.tap(all.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeShot(tester, 'stats_03_all');
    }

    // 4. 스크롤 down (차트 + top liquors 영역)
    final lv = find.byType(ListView).evaluate().isNotEmpty
        ? find.byType(ListView).first
        : find.byType(SingleChildScrollView).first;
    if (lv.evaluate().isNotEmpty) {
      await tester.drag(lv, const Offset(0, -500));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'stats_04_scrolled_mid');

      await tester.drag(lv, const Offset(0, -500));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'stats_05_scrolled_bottom');
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

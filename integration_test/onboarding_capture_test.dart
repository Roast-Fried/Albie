import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

import '_screenshot_helper.dart';

/// 온보딩 모든 페이지 캡처 — SharedPreferences 초기화로 첫 진입 강제.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding — 모든 페이지 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(false); // 첫 진입 강제

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 1. 페이지 1
    await takeShot(tester, 'onboarding_01_page1');

    // 2. 다음 페이지 (스와이프 또는 다음 버튼)
    final next = find.text('다음');
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'onboarding_02_page2');

      // 3. 페이지 3
      if (next.evaluate().isNotEmpty) {
        await tester.tap(next.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await takeShot(tester, 'onboarding_03_page3');
      }
    } else {
      // PageView swipe
      await tester.drag(find.byType(PageView), const Offset(-360, 0));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'onboarding_02_swipe1');

      await tester.drag(find.byType(PageView), const Offset(-360, 0));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'onboarding_03_swipe2');
    }

    // 4. 시작 또는 건너뛰기 버튼 (마지막 페이지)
    final start = find.text('시작');
    if (start.evaluate().isNotEmpty) {
      await takeShot(tester, 'onboarding_04_last_with_start');
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

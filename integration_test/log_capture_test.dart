import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

import '_screenshot_helper.dart';

/// 기록 목록 + 상세 캡처.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('log — 모든 상황 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(true);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    // 1. 기록 탭 진입
    await tapText(tester, '기록');
    await takeShot(tester, 'log_01_list');

    // 2. 검색 TextField focused (find.byType(TextField).first 가 검색바 우선)
    final search = find.byType(TextField).first;
    await tester.tap(search, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await takeShot(tester, 'log_02_search_focused');

    // 3. 검색어 입력
    await tester.enterText(search, '글렌피딕');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await takeShot(tester, 'log_03_search_filtered');

    // 4. 검색 clear (text 비움)
    await tester.enterText(search, '');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await takeShot(tester, 'log_04_search_cleared');

    // 상세 진입 / 별점 tap 은 별도 sprint — multi-widget hitTest hang risk.

    expect(find.byType(Scaffold), findsWidgets);
  });
}

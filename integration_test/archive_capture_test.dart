import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

import '_screenshot_helper.dart';

/// 아카이브 + 상세 캡처.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('archive — 모든 상황 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(true);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    // 1. 더보기 → 마셔본 술
    await tapText(tester, '더보기');
    await takeShot(tester, 'archive_00_more_menu');
    await tapText(tester, '마셔본 술');
    await takeShot(tester, 'archive_01_list');

    // 2. 카테고리 필터 chip — 위스키
    final whiskyChip = find.text('위스키');
    if (whiskyChip.evaluate().isNotEmpty) {
      await tester.tap(whiskyChip.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'archive_02_filter_whisky');
    }

    // 3. 첫 카드 tap → 상세
    final firstCard = find.byType(InkWell).first;
    if (firstCard.evaluate().isNotEmpty) {
      await tester.tap(firstCard, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeShot(tester, 'archive_03_detail');
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

import '_screenshot_helper.dart';

/// 설정 + AI 설정 캡처 — 2026-05-27 단순화 v2.
///
/// 이전 v1 의 `tapText('설정')` 이 settings_screen 의 AppBar title '설정' 과
/// 충돌해 hitTest 가 4분 hang 한 회귀를 해소. ListTile finder 로 정확 지정 +
/// 다크 모드 dialog 토글 skip (cosmetic, layout_08 PNG 로 시각 검증 대체).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings — 단순화 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(true);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    // 1. 더보기 탭 진입
    await tapText(tester, '더보기');
    await takeShot(tester, 'settings_00_more');

    // 2. 더보기 screen 의 '설정' ListTile (AppBar title 충돌 회피)
    final settingsTile = find.widgetWithText(ListTile, '설정');
    if (settingsTile.evaluate().isNotEmpty) {
      await tester.tap(settingsTile.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeShot(tester, 'settings_01_top');

      // 3. 스크롤 down (전체 옵션)
      final lv = find.byType(ListView);
      if (lv.evaluate().isNotEmpty) {
        await tester.drag(lv.first, const Offset(0, -400));
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await takeShot(tester, 'settings_02_scrolled');
      }

      // 4. AI 설정 상세 진입 (settings 화면으로 스크롤 back up)
      if (lv.evaluate().isNotEmpty) {
        await tester.drag(lv.first, const Offset(0, 400));
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
      final aiDetail = find.widgetWithText(ListTile, 'AI 설정 상세');
      if (aiDetail.evaluate().isNotEmpty) {
        await tester.tap(aiDetail.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await takeShot(tester, 'settings_03_ai_settings');

        // 5. API key 입력 focused + 더미 입력
        final keyInput = find.byType(TextField);
        if (keyInput.evaluate().isNotEmpty) {
          await tester.enterText(keyInput.first, 'dummy_key_xxxx');
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await takeShot(tester, 'settings_04_key_filled');
        }
      }
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

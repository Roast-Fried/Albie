import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

import '_screenshot_helper.dart';

/// 설정 + AI 설정 + 다크 dialog 캡처.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings — 모든 상황 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(true);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    await tapText(tester, '더보기');
    await tapText(tester, '설정');

    // 1. 설정 초기
    await takeShot(tester, 'settings_01_top');

    // 2. 스크롤 down (전체 옵션 보기)
    final lv = find.byType(ListView).evaluate().isNotEmpty
        ? find.byType(ListView).first
        : find.byType(SingleChildScrollView).first;
    if (lv.evaluate().isNotEmpty) {
      await tester.drag(lv, const Offset(0, -400));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'settings_02_scrolled');
    }

    // 3. 다크 모드 dialog
    final dark = find.text('다크 모드');
    if (dark.evaluate().isNotEmpty) {
      // 스크롤 back up
      if (lv.evaluate().isNotEmpty) {
        await tester.drag(lv, const Offset(0, 400));
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
      await tester.tap(dark.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'settings_03_theme_dialog');

      // 다크 옵션 선택
      final darkOpt = find.text('다크');
      if (darkOpt.evaluate().isNotEmpty) {
        await tester.tap(darkOpt.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await takeShot(tester, 'settings_04_dark_applied');
      }

      // 시스템 따름으로 복원
      await tester.tap(find.text('다크 모드').first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final sys = find.text('시스템 따름');
      if (sys.evaluate().isNotEmpty) {
        await tester.tap(sys.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
    }

    // 4. AI 설정 상세 진입
    final aiDetail = find.text('AI 설정 상세');
    if (aiDetail.evaluate().isNotEmpty) {
      await tester.tap(aiDetail.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeShot(tester, 'settings_05_ai_settings');

      // API key 입력 focused
      final keyInput = find.byType(TextField);
      if (keyInput.evaluate().isNotEmpty) {
        await tester.tap(keyInput.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await takeShot(tester, 'settings_06_key_input_focused');

        // 더미 키 입력 (검증은 실제 API 호출 → 실패하지만 입력 상태 캡처)
        await tester.enterText(keyInput.first, 'dummy_key_for_capture');
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await takeShot(tester, 'settings_07_key_input_filled');

        // visibility 토글
        final eye = find.byIcon(Icons.visibility);
        if (eye.evaluate().isNotEmpty) {
          await tester.tap(eye.first, warnIfMissed: false);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await takeShot(tester, 'settings_08_key_visible');
        }
      }

      // 스크롤 down — 모델 선택 + 사용량 + 처리 로그
      final aiLv = find.byType(ListView).first;
      await tester.drag(aiLv, const Offset(0, -500));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'settings_09_ai_scrolled');
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

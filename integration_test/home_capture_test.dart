import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

import '_screenshot_helper.dart';

/// 홈 화면 모든 상황별 캡처.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home — 모든 상황 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(true);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    // 1. 홈 빈 입력 상태
    await takeShot(tester, 'home_01_empty');

    // 2. 입력창 tap + focused (cursor 표시)
    final input = textFieldByHint('').evaluate().isEmpty
        ? find.byType(TextField).first
        : find.byType(TextField).first;
    await tester.tap(input, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await takeShot(tester, 'home_02_input_focused');

    // 3. 짧은 입력
    await tester.enterText(input, '맥주');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await takeShot(tester, 'home_03_input_short');

    // 4. 긴 입력 — AI 생성 버튼 활성 + 직접 입력 버튼 활성
    await tester.enterText(input, '오늘 친구들이랑 위스키 두 잔 하이볼 세 잔 마셨어');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await takeShot(tester, 'home_04_input_long');

    // 5. clear 버튼 (suffixIcon X) 영역 확인 (X 버튼 표시 상태)
    await takeShot(tester, 'home_05_input_with_clear');

    // 6. clear tap → 빈 입력으로 복귀
    final clearIcon = find.byIcon(Icons.clear);
    if (clearIcon.evaluate().isNotEmpty) {
      await tester.tap(clearIcon.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'home_06_after_clear');
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

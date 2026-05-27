import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

import '_screenshot_helper.dart';

/// 위스키 컨셉 light/dark 모드 시각 검증 — 짐빔 (Jim Beam) / 아란 마크리무어 CS
/// (Arran Machrie Moor Cask Strength) 팔레트 + Pretendard 폰트 적용 후.
///
/// SharedPreferences mock 으로 themeMode 강제 후 각 모드에서 home + 더보기 화면
/// 캡처. 시스템 다크 모드와 무관하게 light/dark 양쪽 정확히 노출.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('theme — light (짐빔)', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingAndTheme(true, 'light');

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    // 1. 홈 화면 (light)
    await takeShot(tester, 'theme_light_01_home');

    // 2. 입력 후 (light) — primary 색 확인
    final input = find.byType(TextField).first;
    await tester.enterText(input, '오늘 위스키 한 잔');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await takeShot(tester, 'theme_light_02_home_input');

    // 3. 더보기 화면 (light)
    await tapText(tester, '더보기');
    await takeShot(tester, 'theme_light_03_more');

    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('theme — dark (아란 마크리무어 CS)', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingAndTheme(true, 'dark');

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    // 1. 홈 화면 (dark)
    await takeShot(tester, 'theme_dark_01_home');

    // 2. 입력 후 (dark) — primary 색 확인
    final input = find.byType(TextField).first;
    await tester.enterText(input, '오늘 위스키 한 잔');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await takeShot(tester, 'theme_dark_02_home_input');

    // 3. 더보기 화면 (dark)
    await tapText(tester, '더보기');
    await takeShot(tester, 'theme_dark_03_more');

    expect(find.byType(Scaffold), findsWidgets);
  });
}

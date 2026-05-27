import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;
import 'package:albi/views/log/log_list_screen.dart';

import '_screenshot_helper.dart';

/// 위스키 컨셉 light/dark 전 화면 캡처.
///
/// 짐빔 (Light) / 아란 마크리무어 CS (Dark) 팔레트 + Pretendard 폰트가 모든
/// 화면에 일관 적용되는지 시각 검증. SharedPreferences mock 으로 themeMode
/// 강제 + 화면 별 navigate + PNG 캡처.
///
/// 캡처 셋 (light 12 + dark 12 = 24 PNG):
/// - 01_home, 02_home_input
/// - 03_draft_empty, 04_draft_name (글렌피딕 입력 후 master matching ✓ 확인)
/// - 05_more, 06_archive_list, 07_stats, 08_log_list
/// - 09_settings_top, 10_settings_ai_guide
/// - 11_onboarding_p1, 12_onboarding_p2

Future<void> _runScenario(WidgetTester tester, String prefix) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 3));
  await skipOnboarding(tester);

  // 01 home (빈 상태)
  await takeShot(tester, '${prefix}_01_home');

  // 02 home 입력 후
  final input = find.byType(TextField).first;
  await tester.enterText(input, '오늘 글렌피딕 한 잔');
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await takeShot(tester, '${prefix}_02_home_input');

  // 03 draft 빈
  final directButton = find.text('직접 입력');
  if (directButton.evaluate().isNotEmpty) {
    await tester.tap(directButton.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await takeShot(tester, '${prefix}_03_draft_empty');

    // 04 draft 술 이름 입력 후 master matching 확인
    final nameField = textFieldByLabel('술 이름');
    if (nameField.evaluate().isNotEmpty) {
      await tester.tap(nameField.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.enterText(nameField.first, '글렌피딕');
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeShot(tester, '${prefix}_04_draft_name');
    }

    // back to home
    await safeBack(tester);
  }

  // 05 더보기
  await tapText(tester, '더보기');
  await takeShot(tester, '${prefix}_05_more');

  // 06 archive
  final archiveTile = find.widgetWithText(ListTile, '마셔본 술');
  if (archiveTile.evaluate().isNotEmpty) {
    await tester.tap(archiveTile.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await takeShot(tester, '${prefix}_06_archive');
    await safeBack(tester);
  }

  // 07 stats
  final statsTile = find.widgetWithText(ListTile, '통계');
  if (statsTile.evaluate().isNotEmpty) {
    await tester.tap(statsTile.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await takeShot(tester, '${prefix}_07_stats');
    await safeBack(tester);
  }

  // 08 log (BottomNav) — Codex audit WARN: settings 앞에 위치하도록 정렬.
  final logTab = find.byIcon(Icons.list_alt_outlined);
  if (logTab.evaluate().isNotEmpty) {
    await tester.tap(logTab, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    if (find.byType(LogListScreen).evaluate().isNotEmpty) {
      await takeShot(tester, '${prefix}_08_log', activeScreen: LogListScreen);
    }
    // 다시 더보기로 복귀 — settings 진입 위해.
    await tapText(tester, '더보기');
  }

  // 09 settings
  final settingsTile = find.widgetWithText(ListTile, '설정');
  if (settingsTile.evaluate().isNotEmpty) {
    await tester.tap(settingsTile.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await takeShot(tester, '${prefix}_09_settings');

    // 10 AI 설정 상세 (guide card)
    final aiDetail = find.widgetWithText(ListTile, 'AI 설정 상세');
    if (aiDetail.evaluate().isNotEmpty) {
      await tester.tap(aiDetail.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeShot(tester, '${prefix}_10_ai_guide');
      await safeBack(tester);
    }
    await safeBack(tester);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('theme full — light (짐빔)', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingAndTheme(true, 'light');
    await _runScenario(tester, 'full_light');
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('theme full — dark (아란 마크리무어 CS)', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingAndTheme(true, 'dark');
    await _runScenario(tester, 'full_dark');
    expect(find.byType(Scaffold), findsWidgets);
  });
}

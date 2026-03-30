@Tags(['golden'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:albi/views/settings/more_screen.dart';
import 'package:albi/views/onboarding/onboarding_screen.dart';
import 'golden_helper.dart';

void main() {
  setUpAll(setupGoldenTests);

  group('MoreScreen Golden', () {
    testWidgets('default state', (tester) async {
      await tester.pumpWidget(goldenWrapper(const MoreScreen()));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/more_screen.png'),
      );
    });
  });

  group('OnboardingScreen Golden', () {
    testWidgets('first page', (tester) async {
      await tester.pumpWidget(
        goldenWrapper(OnboardingScreen(onComplete: () {})),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/onboarding_page1.png'),
      );
    });
  });
}

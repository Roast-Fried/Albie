import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

import '_screenshot_helper.dart';

/// DraftReview 모든 상황별 캡처 — manual / AI / 다중 entry / 입력 focus / dialog.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('draft_review — 모든 상황 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(true);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    // 1. 직접 입력 모드 — manual entry (빈 카드)
    final directBtn = find.text('직접 입력');
    if (directBtn.evaluate().isNotEmpty) {
      await tester.tap(directBtn.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeShot(tester, 'draft_01_manual_empty');

      // 2. 술 이름 입력 후 entry card
      await enterByLabel(tester, '술 이름', '글렌피딕');
      await takeShot(tester, 'draft_02_name_entered');

      // 3. 양 입력
      await enterByLabel(tester, '양', '2');
      await takeShot(tester, 'draft_03_quantity_entered');

      // 4. 도수% 입력
      await enterByLabel(tester, '도수%', '43');
      await takeShot(tester, 'draft_04_abv_entered');

      // 5. 연산 (age) 입력
      await enterByLabel(tester, '연산', '15년');
      await takeShot(tester, 'draft_05_age_entered');

      // 6. 장소 입력
      await enterByLabel(tester, '장소', '집');
      await takeShot(tester, 'draft_06_place_entered');

      // 7. 메모 입력 (긴 텍스트)
      await enterByLabel(tester, '메모', '맛있게 마셨다. 가벼운 모임.');
      await takeShot(tester, 'draft_07_memo_entered');

      // 8. 항목 추가 → 2 entry
      final addBtn = find.text('항목 추가');
      if (addBtn.evaluate().isNotEmpty) {
        await tester.tap(addBtn.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await takeShot(tester, 'draft_08_two_entries');

        // 9. 두 번째 entry 입력
        final nameFields = textFieldByLabel('술 이름');
        if (nameFields.evaluate().length >= 2) {
          await tester.tap(nameFields.at(1), warnIfMissed: false);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await tester.enterText(nameFields.at(1), '맥주');
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await takeShot(tester, 'draft_09_second_entry_filled');
        }
      }

      // 10. 음식 추가 (입력 후 + 버튼)
      final foodInput = textFieldByHint('음식 추가');
      if (foodInput.evaluate().isNotEmpty) {
        await tester.tap(foodInput.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await tester.enterText(foodInput.first, '치즈');
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await takeShot(tester, 'draft_10_food_input_focused');

        // + 버튼 tap
        final addFoodIcon = find.byIcon(Icons.add_circle_outline);
        if (addFoodIcon.evaluate().isNotEmpty) {
          await tester.tap(addFoodIcon.first, warnIfMissed: false);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await takeShot(tester, 'draft_11_food_chip_added');
        }
      }

      // 12. 뒤로가기 → 작성 취소 dialog
      final back = find.byType(BackButton);
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await takeShot(tester, 'draft_12_cancel_dialog');

        // 13. "나가기" tap → home 복귀
        final leave = find.text('나가기');
        if (leave.evaluate().isNotEmpty) {
          await tester.tap(leave.first, warnIfMissed: false);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await takeShot(tester, 'draft_13_after_leave');
        }
      }
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

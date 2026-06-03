import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;
import 'package:albi/views/archive/archive_screen.dart';
import 'package:albi/views/archive/archive_detail_screen.dart';

import '_screenshot_helper.dart';

/// 아카이브 + 상세 캡처.
///
/// C2 fix (2026-06-03): 기존엔 데이터 시드 없이 archive 진입 → 빈 리스트라
/// `archive_03_detail` 이 상세가 아닌 (빈) 리스트를 캡처했다. 홈 입력으로
/// 글렌피딕(master 'whisky' 매칭) 1건을 저장해 archive entry 를 만든 뒤,
/// 카드 text 를 직접 tap + activeScreen 가드로 실제 상세 화면을 캡처한다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('archive — 모든 상황 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(true);

    app.main();
    await settleOrPump(tester);
    await skipOnboarding(tester);

    // ===== 0) 아카이브 entry 시드 — 글렌피딕(local parser master 매칭) 저장 =====
    await _enterLog(tester, '글렌피딕 12 두 잔');
    await _saveDraft(tester);

    // 1. 더보기 → 마셔본 술
    await tapText(tester, '더보기');
    await takeShot(tester, 'archive_00_more_menu');
    final archiveTile = find.widgetWithText(ListTile, '마셔본 술');
    if (archiveTile.evaluate().isNotEmpty) {
      await tester.tap(archiveTile.first, warnIfMissed: false);
      await settleOrPump(tester);
    } else {
      await tapText(tester, '마셔본 술');
    }
    await takeShot(tester, 'archive_01_list', activeScreen: ArchiveScreen);

    // 2. 카테고리 필터 chip — 위스키
    final whiskyChip = find.text('위스키');
    if (whiskyChip.evaluate().isNotEmpty) {
      await tester.tap(whiskyChip.first, warnIfMissed: false);
      await settleOrPump(tester);
      await takeShot(tester, 'archive_02_filter_whisky',
          activeScreen: ArchiveScreen);
    }

    // 3. 글렌피딕 카드 text 직접 tap → 상세 (trailing 즐겨찾기 아이콘 회피).
    //    activeScreen 가드로 실제 ArchiveDetailScreen 진입 시에만 캡처.
    final glen = find.text('글렌피딕');
    if (glen.evaluate().isNotEmpty) {
      await tester.tap(glen.first, warnIfMissed: false);
      await settleOrPump(tester);
      if (find.byType(ArchiveDetailScreen).evaluate().isNotEmpty) {
        await takeShot(tester, 'archive_03_detail',
            activeScreen: ArchiveDetailScreen);
      }
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

/// 홈에서 자연어 입력 → "AI로 생성"(AI 키 없으면 local parser fallback) → draft.
Future<void> _enterLog(WidgetTester tester, String text) async {
  final homeTab = find.byIcon(Icons.home_outlined);
  if (homeTab.evaluate().isNotEmpty) {
    await tester.tap(homeTab, warnIfMissed: false);
    await settleOrPump(tester);
  }
  final input = find.byType(TextField).first;
  await tester.tap(input, warnIfMissed: false);
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await tester.enterText(input, text);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  final aiBtn = find.text('AI로 생성');
  if (aiBtn.evaluate().isNotEmpty) {
    await tester.tap(aiBtn.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 8));
  }
}

/// draft_review 의 "저장" 버튼 tap → home 복귀.
Future<void> _saveDraft(WidgetTester tester) async {
  final save = find.text('저장');
  if (save.evaluate().isNotEmpty) {
    await tester.tap(save.first, warnIfMissed: false);
    await settleOrPump(tester);
  } else {
    await safeBack(tester);
  }
}

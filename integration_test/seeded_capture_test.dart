import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;
import 'package:albi/views/log/log_list_screen.dart';
import 'package:albi/views/log/log_detail_screen.dart';
import 'package:albi/views/archive/archive_screen.dart';
import 'package:albi/views/archive/archive_detail_screen.dart';
import 'package:albi/views/stats/stats_screen.dart';

import '_screenshot_helper.dart';

/// 데이터를 실제로 넣으면서 dialog/sheet 캡처.
///
/// 1) AI key (secure storage mock + dart-define) → AI 로 생성 흐름
/// 2) home 입력 → AI 또는 manual → draft 저장 (2-3건)
/// 3) log_list (데이터 있는) → log_detail → tasting note → 별점
/// 4) archive (카테고리별) → archive_detail
/// 5) stats (차트 있는)
/// 6) settings → 다크 모드 dialog / 데이터 초기화 confirm dialog
///
/// 실행:
///   flutter test integration_test/seeded_capture_test.dart -d windows \
///     --dart-define=GEMINI_API_KEY=KEY_HERE
const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seeded — 데이터 입력 + dialog/sheet 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingAndTheme(true, 'light');
    setupSecureStorageMock({
      if (_geminiKey.isNotEmpty) 'gemini_api_key': _geminiKey,
    });

    app.main();
    await settleOrPump(tester);
    await skipOnboarding(tester);

    // ===== 1) 글렌피딕 (local parser 매칭 — master 'whisky' + defaultAbv 40) =====
    await _enterLog(tester, '글렌피딕 12 두 잔');
    await takeShot(tester, 'seeded_01_draft_glenfiddich');
    await _saveDraft(tester);

    // ===== 2) 맥주 — AI key 있으면 Gemini, 없으면 local parser =====
    await _enterLog(tester, '오늘 친구들이랑 맥주 세 잔 마셨어');
    await takeShot(tester, 'seeded_02_draft_beer');
    await _saveDraft(tester);

    // ===== 3) 와인 =====
    await _enterLog(tester, '와인 한 잔');
    await takeShot(tester, 'seeded_02b_draft_wine');
    await _saveDraft(tester);

    // ===== Log List (BottomNav 기록) =====
    final logTab = find.byIcon(Icons.list_alt_outlined);
    if (logTab.evaluate().isNotEmpty) {
      await tester.tap(logTab, warnIfMissed: false);
      await settleOrPump(tester);
      await takeShot(tester, 'seeded_03_log_list',
          activeScreen: LogListScreen);

      // 검색 IconButton tap → 검색 TextField → 검색어 입력
      final searchIcon = find.byIcon(Icons.search);
      if (searchIcon.evaluate().isNotEmpty) {
        await tester.tap(searchIcon.first, warnIfMissed: false);
        await settleOrPump(tester);
        await takeShot(tester, 'seeded_03a_log_search_focused',
            activeScreen: LogListScreen);

        // 검색어 입력 (글렌피딕 — 매칭 결과)
        final searchField = find.byType(TextField).first;
        await tester.enterText(searchField, '글렌피딕');
        await settleOrPump(tester);
        await takeShot(tester, 'seeded_03b_log_search_glenfiddich',
            activeScreen: LogListScreen);

        // 검색어 변경 (0건 결과)
        await tester.enterText(searchField, '존재하지않는술');
        await settleOrPump(tester);
        await takeShot(tester, 'seeded_03c_log_search_empty',
            activeScreen: LogListScreen);

        // 검색 닫기 (X icon)
        final closeIcon = find.byIcon(Icons.close);
        if (closeIcon.evaluate().isNotEmpty) {
          await tester.tap(closeIcon.first, warnIfMissed: false);
          await settleOrPump(tester);
        }
      }

      // 첫 entry tap → log_detail. log_list 의 entry tile 은 Card+InkWell
      // (ListTile 아님). InkWell 의 첫 tap 으로 정확히 entry navigation.
      final entries = find.byType(InkWell);
      if (entries.evaluate().isNotEmpty) {
        await tester.tap(entries.first, warnIfMissed: false);
        await settleOrPump(tester);
        await takeShot(tester, 'seeded_04_log_detail',
            activeScreen: LogDetailScreen);

        // tasting note 작성 sheet — Codex audit [4]: 실제 CTA '테이스팅 노트 작성'.
        // 별점 widget 은 sheet 안에 있으므로 sheet 진입 후 별점 tap.
        final noteEdit = find.text('테이스팅 노트 작성');
        final noteEdit2 = find.text('테이스팅 노트 작성/수정');
        final noteBtn = noteEdit.evaluate().isNotEmpty
            ? noteEdit
            : (noteEdit2.evaluate().isNotEmpty ? noteEdit2 : null);
        if (noteBtn != null) {
          await tester.tap(noteBtn.first, warnIfMissed: false);
          await settleOrPump(tester);
          await takeShot(tester, 'seeded_06_tasting_note_sheet');

          // 별점 tap (sheet 안 — 4번째 별 tap) — Icons.star_outline_rounded.
          final starsBorder = find.byIcon(Icons.star_outline_rounded);
          if (starsBorder.evaluate().length >= 4) {
            await tester.tap(starsBorder.at(3), warnIfMissed: false);
            await settleOrPump(tester);
            await takeShot(tester, 'seeded_05_rating_4stars');
          }

          // 노트 입력
          final noteField = find.byType(TextField);
          if (noteField.evaluate().isNotEmpty) {
            await tester.enterText(noteField.first, '깔끔하고 마시기 좋다');
            await settleOrPump(tester);
            await takeShot(tester, 'seeded_07_tasting_note_filled');
          }

          // 닫기 (dismiss)
          await tester.tapAt(const Offset(180, 100));
          await settleOrPump(tester);
        }

        await safeBack(tester);
      }
    }

    // ===== Archive =====
    await tapText(tester, '더보기');
    await settleOrPump(tester);
    final archiveTile = find.widgetWithText(ListTile, '마셔본 술');
    if (archiveTile.evaluate().isNotEmpty) {
      await tester.tap(archiveTile.first, warnIfMissed: false);
      await settleOrPump(tester);
      await takeShot(tester, 'seeded_08_archive', activeScreen: ArchiveScreen);

      // 첫 entry tap → archive_detail. ListTile 의 trailing favorite icon
      // 영역 회피 — 글렌피딕 text 직접 tap.
      final glenInArchive = find.text('글렌피딕');
      if (glenInArchive.evaluate().isNotEmpty) {
        await tester.tap(glenInArchive.first, warnIfMissed: false);
        await settleOrPump(tester);
        await takeShot(tester, 'seeded_09_archive_detail',
            activeScreen: ArchiveDetailScreen);
        await safeBack(tester);
      }
      await safeBack(tester);
    }

    // ===== Stats (차트 있는) =====
    await tapText(tester, '더보기');
    await settleOrPump(tester);
    final statsTile = find.widgetWithText(ListTile, '통계');
    if (statsTile.evaluate().isNotEmpty) {
      await tester.tap(statsTile.first, warnIfMissed: false);
      await settleOrPump(tester);
      await takeShot(tester, 'seeded_10_stats', activeScreen: StatsScreen);

      // 스크롤
      final lv = find.byType(ListView);
      if (lv.evaluate().isNotEmpty) {
        await tester.drag(lv.first, const Offset(0, -400));
        await settleOrPump(tester);
        await takeShot(tester, 'seeded_11_stats_scrolled',
            activeScreen: StatsScreen);
      }
      await safeBack(tester);
    }

    // ===== Settings (다크 dialog / 데이터 초기화 confirm) =====
    await tapText(tester, '더보기');
    await settleOrPump(tester);
    final settingsTile = find.widgetWithText(ListTile, '설정');
    if (settingsTile.evaluate().isNotEmpty) {
      await tester.tap(settingsTile.first, warnIfMissed: false);
      await settleOrPump(tester);

      // 다크 모드 dialog — modal route 는 root boundary 사용 (activeScreen 미지정).
      final dark = find.widgetWithText(ListTile, '다크 모드');
      if (dark.evaluate().isNotEmpty) {
        await tester.tap(dark.first, warnIfMissed: false);
        await settleOrPump(tester);
        await takeShot(tester, 'seeded_12_dark_mode_dialog');

        // 다이얼로그 dismiss (취소)
        final cancel = find.text('취소');
        if (cancel.evaluate().isNotEmpty) {
          await tester.tap(cancel.first, warnIfMissed: false);
        } else {
          await tester.tapAt(const Offset(20, 20));
        }
        await settleOrPump(tester);
      }

      // 데이터 초기화 confirm dialog
      final reset = find.widgetWithText(ListTile, '데이터 초기화');
      if (reset.evaluate().isNotEmpty) {
        await tester.tap(reset.first, warnIfMissed: false);
        await settleOrPump(tester);
        // confirm dialog 도 modal route — root boundary.
        await takeShot(tester, 'seeded_13_reset_confirm_dialog');

        // 취소 (실제 reset 방지)
        final cancel = find.text('취소');
        if (cancel.evaluate().isNotEmpty) {
          await tester.tap(cancel.first, warnIfMissed: false);
          await settleOrPump(tester);
        }
      }
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

/// 홈에서 텍스트 입력 → "AI로 생성" 클릭. AI key 활성 시 Gemini 호출,
/// 부재 시 LocalRuleParser fallback. 어느 쪽이든 entries 자동 채움.
///
/// _onManualInput 의 "직접 입력" 은 rawInputText 만 보존 + 빈 entry — parsing
/// 안 함. 데이터 생성 목적이라 본 helper 는 항상 generateDraft 경로.
Future<void> _enterLog(WidgetTester tester, String text) async {
  // home tab 으로 강제 복귀 — 이전 draft 잔존 회피.
  final homeTab = find.byIcon(Icons.home_outlined);
  if (homeTab.evaluate().isNotEmpty) {
    await tester.tap(homeTab, warnIfMissed: false);
    await settleOrPump(tester);
  }

  // input TextField — home_screen 의 input_section_widget 의 첫 TextField.
  final input = find.byType(TextField).first;
  await tester.tap(input, warnIfMissed: false);
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await tester.enterText(input, text);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  // "AI로 생성" 클릭 — generateDraft 호출 (AI 또는 local fallback).
  final aiBtn = find.text('AI로 생성');
  if (aiBtn.evaluate().isNotEmpty) {
    await tester.tap(aiBtn.first, warnIfMissed: false);
    // local parser 는 빠름, AI 는 ~5-10s. 충분히 대기.
    await tester.pumpAndSettle(const Duration(seconds: 12));
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

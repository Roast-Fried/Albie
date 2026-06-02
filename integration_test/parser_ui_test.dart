import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

/// /goal Iter 1-7 의 logic fix 가 DraftReview UI 에 정확히 반영되는지 통합 검증.
///
/// 핸드폰 세로 해상도 (logical 360x800 @ 3.0x = physical 1080x2400) 강제 — 실제
/// 모바일 환경에서의 widget layout 검증.
///
/// LocalRuleParser fallback 경로 (GEMINI_API_KEY env var 없음 → AI 호출 무시) 로
/// 결정적 결과 보장.
///
/// 2026-05-26 작성 / 2026-05-26 v2 — viewport 강제 + boundary topmost + BackButton finder.

/// pumpAndSettle 하되 debounce(master-matching) timer 로 settle 안 되면 고정 pump
/// 폴백 — 텍스트 입력 후 pumpAndSettle 무한대기 hang 방지.
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 4),
    );
  } catch (_) {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }
}

/// 화면 캡처 — topmost RenderRepaintBoundary (navigator 의 마지막 push 된 route)
/// 를 캡처해 home 위 DraftReview 같이 stacked 화면도 정확히 캡처.
Future<void> takeScreenshot(WidgetTester tester, String name) async {
  await _settle(tester);
  if (Platform.isAndroid || Platform.isIOS) return;
  try {
    final renderObject = tester.binding.rootElement!.renderObject!;
    final boundaries = <RenderRepaintBoundary>[];
    void findBoundary(RenderObject obj) {
      if (obj is RenderRepaintBoundary) {
        boundaries.add(obj);
      }
      obj.visitChildren(findBoundary);
    }

    findBoundary(renderObject);
    // Codex audit 권고: viewport 면적 70% 이상 boundary 만 선택 — DraftReview
    // 내부 ListView card 같은 sub-boundary 가 size>200 만족할 수 있어 잘못 잡힘.
    // 전체 화면 boundary 보장 위해 면적 비율 가드.
    final viewLogical = tester.view.physicalSize / tester.view.devicePixelRatio;
    final minW = viewLogical.width * 0.7;
    final minH = viewLogical.height * 0.7;
    RenderRepaintBoundary? boundary;
    for (final b in boundaries.reversed) {
      if (b.size.width >= minW && b.size.height >= minH) {
        boundary = b;
        break;
      }
    }
    boundary ??= boundaries.isNotEmpty ? boundaries.first : null;

    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final dir = Directory('test_screenshots');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File('test_screenshots/$name.png')
            .writeAsBytesSync(byteData.buffer.asUint8List());
        debugPrint('Screenshot: $name.png (${boundary.size})');
      }
    }
  } catch (e) {
    debugPrint('Screenshot failed ($name): $e');
  }
}

Future<bool> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return true;
  }
  await _settle(tester);
  return false;
}

Finder textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
}

/// Home 화면의 자연어 입력 TextField — hintText 가 들어있는 첫 TextField.
Finder homeInputField() {
  return find.byWidgetPredicate((w) {
    if (w is! TextField) return false;
    // home 입력은 maxLines=2, hintText 존재
    final hint = w.decoration?.hintText;
    return hint != null && w.maxLines == 2;
  });
}

String fieldValue(WidgetTester tester, String label, {int at = 0}) {
  final field = tester.widget<TextField>(textFieldByLabel(label).at(at));
  return field.controller?.text ?? '';
}

Future<void> skipOnboardingIfNeeded(WidgetTester tester) async {
  if (find.text('건너뛰기').evaluate().isNotEmpty) {
    await tester.tap(find.text('건너뛰기'));
    await _settle(tester);
  }
}

/// 홈 화면에서 자연어 입력 + AI로 생성 → DraftReview 진입까지.
Future<void> generateDraft(WidgetTester tester, String text) async {
  // 홈 탭 보장
  final homeTab = find.text('홈');
  if (homeTab.evaluate().isNotEmpty) {
    await tester.tap(homeTab.last);
    await _settle(tester);
  }

  // home 입력 TextField 명시 찾기
  final input = homeInputField();
  expect(input, findsOneWidget,
      reason: 'home input TextField (maxLines=2, hintText 있음) 1개');
  await tester.tap(input);
  await _settle(tester);
  await tester.enterText(input, text);
  await _settle(tester);

  final genBtn = find.text('AI로 생성');
  expect(genBtn, findsOneWidget, reason: 'AI로 생성 버튼');
  await tester.tap(genBtn);
  await tester.pump(const Duration(seconds: 1));
  await _settle(tester);

  final reviewFound = await waitFor(tester, find.text('기록 검토'));
  expect(reviewFound, isTrue, reason: '입력 "$text" 후 DraftReview 진입 실패');
}

/// DraftReview 이탈 — AppBar 의 BackButton tap → "작성 취소" dialog → "나가기" tap.
Future<void> leaveDraftReview(WidgetTester tester) async {
  final back = find.byType(BackButton);
  if (back.evaluate().isEmpty) {
    debugPrint('leaveDraftReview: BackButton 없음 — 이미 home?');
    return;
  }
  await tester.tap(back.first);
  await _settle(tester);
  if (find.text('나가기').evaluate().isNotEmpty) {
    await tester.tap(find.text('나가기'));
    await _settle(tester);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Iter 1-7 fix 가 DraftReview UI 에 반영된다 (mobile portrait)', (tester) async {
    // 핸드폰 세로 viewport 강제 — Pixel 5 비슷 (1080x2400 @ 3.0x = logical 360x800)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    app.main();
    await _settle(tester);
    await skipOnboardingIfNeeded(tester);

    await takeScreenshot(tester, 'parser_ui_00_home_ready');

    // --- Phase B-1: 명시 도수 표기 5종 → 도수% field 정확 표시 ---
    final abvCases = <({String input, String expected, String shot})>[
      (input: '맥주 0% 한 캔', expected: '0.0', shot: 'parser_ui_01_beer_0_percent'),
      (input: '위스키 40% 한 잔', expected: '40.0', shot: 'parser_ui_02_whisky_40_percent'),
      (input: '소주 17도 한 잔', expected: '17.0', shot: 'parser_ui_03_soju_17_do'),
      (input: '위스키 도수 43 한 잔', expected: '43.0', shot: 'parser_ui_04_dosu_43_prefix'),
      (input: '맥주 abv 5.5 한 캔', expected: '5.5', shot: 'parser_ui_05_abv_prefix'),
    ];

    for (final c in abvCases) {
      await generateDraft(tester, c.input);
      expect(textFieldByLabel('도수%'), findsWidgets,
          reason: '"${c.input}" → "도수%" label TextField 1+ 개 있어야');
      final actual = fieldValue(tester, '도수%');
      expect(actual, c.expected,
          reason: '"${c.input}" → 도수% 표시 = "$actual" (expected "${c.expected}")');
      await takeScreenshot(tester, c.shot);
      await leaveDraftReview(tester);
    }

    // --- Phase B-2: ageStatement 정확성 ---
    // (a) "벤로막 15년" → 연산 field 가 "15년"
    await generateDraft(tester, '벤로막 15년 한 잔');
    expect(fieldValue(tester, '연산'), '15년',
        reason: '"벤로막 15년" → 연산 = "15년" (정상 age 추출)');
    await takeScreenshot(tester, 'parser_ui_06_age_15');
    await leaveDraftReview(tester);

    // (b) "위스키 40%" → 연산 비어있음 + 도수% = "40.0" (Iter 4 F1 fix)
    await generateDraft(tester, '위스키 40% 한 잔');
    expect(fieldValue(tester, '연산'), '',
        reason: 'Iter 4 F1 fix: "위스키 40%" 의 40 은 age 아님 — 연산 비어있어야');
    expect(fieldValue(tester, '도수%'), '40.0');
    await takeScreenshot(tester, 'parser_ui_07_age_null_abv_40');
    await leaveDraftReview(tester);

    // (c) 복수 ABV: "위스키 13도 보드카 40% 각 한 잔" → 2 entry + age 오인 X (Iter 6+7)
    await generateDraft(tester, '위스키 13도 보드카 40% 각 한 잔');
    expect(find.text('항목 1'), findsOneWidget);
    expect(find.text('항목 2'), findsOneWidget,
        reason: 'Iter 7 split keyword: 보드카 entry');
    final ageValuesMultiAbv = [
      fieldValue(tester, '연산', at: 0),
      fieldValue(tester, '연산', at: 1),
    ];
    expect(ageValuesMultiAbv, everyElement(isNot('40년')),
        reason: 'Iter 6 F3 span overlap: 40 abv → age 제외');
    expect(ageValuesMultiAbv, everyElement(isNot('13년')),
        reason: 'Iter 6 F3 span overlap: 13 abv → age 제외');
    await takeScreenshot(tester, 'parser_ui_08_multi_abv_split');
    await leaveDraftReview(tester);

    // --- Phase B-3: qtyPattern 통일 (한글 수량어 split) ---
    await generateDraft(tester, '소주 두 잔 맥주 네 잔');
    expect(find.text('항목 1'), findsOneWidget);
    expect(find.text('항목 2'), findsOneWidget,
        reason: 'Iter 1 C2: "네 잔" 도 split trigger');
    await takeScreenshot(tester, 'parser_ui_09_qty_split_korean');
    await leaveDraftReview(tester);

    // --- Phase B-4: Iter 7 split keyword 확장 (위스키/보드카) ---
    await generateDraft(tester, '위스키 한 잔 보드카 한 잔');
    expect(find.text('항목 1'), findsOneWidget);
    expect(find.text('항목 2'), findsOneWidget,
        reason: 'Iter 7: 보드카 split keyword 추가');
    await takeScreenshot(tester, 'parser_ui_10_iter7_categories');
    await leaveDraftReview(tester);

    await takeScreenshot(tester, 'parser_ui_11_final_home');

    expect(true, isTrue);
  });
}

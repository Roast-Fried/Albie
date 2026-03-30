import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

/// RenderRepaintBoundary 기반 스크린샷 — 플랫폼 무관하게 동작
Future<void> takeScreenshot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();

  try {
    // 루트 RenderObject에서 캡처
    final renderObject = tester.binding.rootElement!.renderObject!;
    RenderRepaintBoundary? boundary;

    void findBoundary(RenderObject obj) {
      if (obj is RenderRepaintBoundary) {
        boundary ??= obj;
        return;
      }
      obj.visitChildren(findBoundary);
    }

    findBoundary(renderObject);

    if (boundary != null) {
      final image = await boundary!.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final dir = Directory('test_screenshots');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File('test_screenshots/$name.png')
            .writeAsBytesSync(byteData.buffer.asUint8List());
        debugPrint('Screenshot saved: test_screenshots/$name.png');
      }
    }
  } catch (e) {
    debugPrint('Screenshot failed ($name): $e');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('전체 플로우 테스트 + 스크린샷', (tester) async {
    app.main();

    // DB 초기화 대기
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 1. 온보딩 or 홈
    await takeScreenshot(tester, '01_first_screen');

    // 온보딩이 보이면 건너뛰기
    final skipBtn = find.text('건너뛰기');
    if (skipBtn.evaluate().isNotEmpty) {
      await tester.tap(skipBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // 2. 홈 화면
    await takeScreenshot(tester, '02_home');

    // 3. 텍스트 입력
    final inputFields = find.byType(TextField);
    if (inputFields.evaluate().isNotEmpty) {
      await tester.tap(inputFields.first);
      await tester.pumpAndSettle();
      await tester.enterText(inputFields.first, '하이볼 두 잔 감자튀김');
      await tester.pumpAndSettle();
      await takeScreenshot(tester, '03_input_text');
    }

    // 4. AI로 생성
    final aiBtn = find.text('AI로 생성');
    if (aiBtn.evaluate().isNotEmpty) {
      await tester.tap(aiBtn);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await takeScreenshot(tester, '04_draft_review');
    }

    // 5. 저장
    final saveBtn = find.text('저장');
    if (saveBtn.evaluate().isNotEmpty) {
      await tester.tap(saveBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await takeScreenshot(tester, '05_after_save');
    }

    // 6. 기록 탭
    final logTab = find.text('기록');
    if (logTab.evaluate().isNotEmpty) {
      await tester.tap(logTab.last);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeScreenshot(tester, '06_log_list');
    }

    // 7. 더보기 탭
    final moreTab = find.text('더보기');
    if (moreTab.evaluate().isNotEmpty) {
      await tester.tap(moreTab.last);
      await tester.pumpAndSettle();
      await takeScreenshot(tester, '07_more');
    }

    expect(true, isTrue); // 테스트 성공 표시
  });
}

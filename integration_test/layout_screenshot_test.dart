import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;

/// 세로 모바일 해상도 (360x800) 에서 모든 주요 화면 layout 깨짐 확인용.
///
/// integration_test/parser_ui_test.dart 가 parser 결과의 entry card UI 만 검증한다면
/// 본 test 는 entry card 외 home/log/archive/stats/settings/ai_settings/onboarding
/// 의 layout overflow / 잘림 / 좁아짐 등을 시각 검증하기 위한 PNG 캡처용.
///
/// assertion 은 최소 (Scaffold findsWidgets) — 깨짐 발견은 PNG 시각 검토 후 후속 fix.
///
/// 2026-05-26 작성.

Future<void> takeScreenshot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
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
    final viewLogical =
        tester.view.physicalSize / tester.view.devicePixelRatio;
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

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) return;
  await tester.tap(f.last);
  await tester.pumpAndSettle();
}

Future<void> back(WidgetTester tester) async {
  final f = find.byType(BackButton);
  if (f.evaluate().isEmpty) return;
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('주요 화면 mobile portrait layout screenshot', (tester) async {
    // Pixel 5 비슷 (1080x2400 @ 3.0x = logical 360x800)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 온보딩 (있다면 캡처 후 skip)
    if (find.text('건너뛰기').evaluate().isNotEmpty) {
      await takeScreenshot(tester, 'layout_00_onboarding');
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // 홈
    await takeScreenshot(tester, 'layout_01_home');

    // 기록 탭
    await tapText(tester, '기록');
    await takeScreenshot(tester, 'layout_02_log_list');

    // 더보기 탭
    await tapText(tester, '더보기');
    await takeScreenshot(tester, 'layout_03_more');

    // 마셔본 술 (아카이브)
    await tapText(tester, '마셔본 술');
    await takeScreenshot(tester, 'layout_04_archive');
    await back(tester);

    // 통계
    await tapText(tester, '통계');
    await takeScreenshot(tester, 'layout_05_stats');
    await back(tester);

    // 설정
    await tapText(tester, '설정');
    await takeScreenshot(tester, 'layout_06_settings');

    // AI 설정 상세
    await tapText(tester, 'AI 설정 상세');
    await takeScreenshot(tester, 'layout_07_ai_settings');
    await back(tester);

    // 설정 → 다크 모드 dialog (가로 layout 검증)
    await tapText(tester, '다크 모드');
    await takeScreenshot(tester, 'layout_08_theme_dialog');
    // dialog 닫기 — 바깥 tap 또는 cancel
    if (find.text('취소').evaluate().isNotEmpty) {
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}

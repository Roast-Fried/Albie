import 'dart:io';
import 'dart:ui' as ui;

import 'package:albi/core/theme/app_theme.dart';
import 'package:albi/domain/entities/drink_log.dart';
import 'package:albi/viewmodels/calendar_viewmodel.dart';
import 'package:albi/views/calendar/calendar_screen.dart';
import 'package:albi/views/settings/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// 신규 화면(캘린더/클라우드 백업 dormant)을 스마트폰 해상도로 렌더 + 캡처.
/// headless 위젯 테스트라 디바이스/실 DB 없이 동작(Windows integration 의 hang 회피).
/// provider override 로 데이터 주입 → table_calendar locale·dormant 카드 렌더 검증.
Future<void> _pumpScreen(
  WidgetTester tester,
  GlobalKey key,
  Widget screen,
  List<Override> overrides,
) async {
  // 스마트폰 세로 해상도: 1080x2340 물리, DPR 3 → 360x780 logical.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RepaintBoundary(key: key, child: screen),
      ),
    ),
  );
  // 비동기 provider/애니메이션 진행 — pumpAndSettle 대신 고정 pump(hang 회피).
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _capture(GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('test_screenshots');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('test_screenshots/$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('Captured: test_screenshots/$name.png');
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
    // 앱 테마 폰트(Pretendard) 로드 — 미로드 시 한글이 tofu(□)로 렌더됨.
    final loader = FontLoader('Pretendard');
    for (final path in const [
      'assets/fonts/Pretendard-Regular.otf',
      'assets/fonts/Pretendard-Medium.otf',
      'assets/fonts/Pretendard-SemiBold.otf',
      'assets/fonts/Pretendard-Bold.otf',
    ]) {
      final f = File(path);
      if (f.existsSync()) {
        loader.addFont(
          Future.value(ByteData.view(f.readAsBytesSync().buffer)),
        );
      }
    }
    await loader.load();
  });

  testWidgets('캘린더 화면 캡처 (스마트폰)', (tester) async {
    final key = GlobalKey();
    final today = DateTime.now();
    await _pumpScreen(tester, key, const CalendarScreen(), [
      calendarLogsByDayProvider.overrideWith((ref) async {
        // 오늘 + 며칠 전에 마커가 보이도록 샘플 기록.
        return {
          calendarDayKey(today): [
            DrinkLog(
              drankAt: today,
              place: '집',
              entries: [
                DrinkEntry(liquorNameRaw: '글렌피딕 12', quantityValue: 2),
              ],
            ),
          ],
          calendarDayKey(today.subtract(const Duration(days: 3))): [
            DrinkLog(
              drankAt: today.subtract(const Duration(days: 3)),
              entries: [DrinkEntry(liquorNameRaw: '하이볼')],
            ),
          ],
        };
      }),
    ]);

    expect(find.byType(CalendarScreen), findsOneWidget);
    await _capture(key, 'ca_calendar');
  });

  testWidgets('클라우드 백업 dormant 화면 캡처 (스마트폰)', (tester) async {
    final key = GlobalKey();
    // .env 미설정(AppConfig.hasSupabase=false) → accountProvider configured=false.
    await _pumpScreen(tester, key, const AccountScreen(), const []);

    expect(find.text('클라우드 백업이 설정되지 않았어요'), findsOneWidget);
    await _capture(key, 'ca_account_dormant');
  });
}

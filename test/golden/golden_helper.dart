import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:albi/core/theme/app_theme.dart';

/// Golden test 실행 전 호출 — 한글 폰트 로드.
///
/// Golden 갱신은 `flutter test --update-goldens` flag 로 처리 (autoUpdateGoldenFiles
/// 가 자동 true). shell `UPDATE_GOLDENS=true` 는 dart `String.fromEnvironment` 가
/// compile-time constant 라 작동 안 함 — `--update-goldens` 로 통일.
Future<void> setupGoldenTests() async {
  // 한글 폰트 로드
  final fontFile = File('assets/fonts/NotoSansKR.ttf');
  if (fontFile.existsSync()) {
    final bytes = fontFile.readAsBytesSync();
    final fontLoader = FontLoader('NotoSansKR')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await fontLoader.load();
  }
  // autoUpdateGoldenFiles 는 flutter cli 의 --update-goldens 가 자동 설정.
}

/// Golden test용 래퍼
Widget goldenWrapper(
  Widget child, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
}) {
  return ProviderScope(
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
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Material(child: child),
        ),
      ),
    ),
  );
}

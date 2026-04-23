import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:albi/core/theme/app_theme.dart';

/// Golden test 실행 전 호출 — 한글 폰트 로드 + autoUpdate 설정
Future<void> setupGoldenTests() async {
  // 한글 폰트 로드
  final fontFile = File('assets/fonts/NotoSansKR.ttf');
  if (fontFile.existsSync()) {
    final bytes = fontFile.readAsBytesSync();
    final fontLoader = FontLoader('NotoSansKR')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await fontLoader.load();
  }

  // 환경변수 UPDATE_GOLDENS=true 로 실행 시에만 golden 파일 갱신
  // CI 및 일반 테스트에서는 회귀 감지를 위해 비교 모드 사용
  autoUpdateGoldenFiles =
      const String.fromEnvironment('UPDATE_GOLDENS') == 'true';
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

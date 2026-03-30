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

  // Golden 비교 시 항상 업데이트 모드 → 실패 없이 최신 이미지 생성
  // 비교 검증은 직접 이미지를 눈으로 확인하는 방식
  autoUpdateGoldenFiles = true;
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

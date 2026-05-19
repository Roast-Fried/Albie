import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  /// 알비 브랜드 색상 — 따뜻한 앰버(Amber) 계열.
  /// Material 3 colorSchemeSeed 로 사용되어 전체 ColorScheme 이 자동 생성됩니다.
  static const Color kAlbiAmber = Color(0xFFD4870A);

  static const _fontFamily = 'NotoSansKR';

  static final light = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: kAlbiAmber,
    brightness: Brightness.light,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: const Color(0xFFF8F6F3),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: kAlbiAmber,
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: kAlbiAmber,
    brightness: Brightness.dark,
    fontFamily: _fontFamily,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
    ),
  );
}

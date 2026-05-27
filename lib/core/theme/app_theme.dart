import 'package:flutter/material.dart';

/// 알비 테마 — 위스키 컨셉.
///
/// **Light**: 짐빔 (Jim Beam) — 버번 위스키의 황금 앰버 + 따뜻한 크림 배경.
/// **Dark**: 아란 마크리무어 캐스크 스트렝스 (Arran Machrie Moor CS) — 피트 + 셰리
/// 캐스크의 진한 황금 + 피트 블랙 배경.
///
/// 폰트: Pretendard (한국어/라틴 모두 자연스러운 가독성).
class AppTheme {
  AppTheme._();

  // --- Jim Beam (Light) ---
  /// 짐빔 버번의 액체 색 — deep amber gold. primary seed.
  static const Color kJimBeamAmber = Color(0xFFB8731A);

  /// 짐빔 라벨 오크 — secondary/accent.
  static const Color kOakBrown = Color(0xFF5C3A1E);

  /// 따뜻한 크림 배경.
  static const Color kCreamSurface = Color(0xFFFBF6EE);

  // --- Arran Machrie Moor CS (Dark) ---
  /// 캐스크 스트렝스의 진한 황금 — primary seed (dark).
  static const Color kArranCaskGold = Color(0xFFE0A857);

  /// 피트 블랙 — scaffold.
  static const Color kPeatBlack = Color(0xFF15110D);

  /// 피트 스모크 — surface.
  static const Color kPeatSmoke = Color(0xFF1F1812);

  static const _fontFamily = 'Pretendard';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: kJimBeamAmber,
      brightness: Brightness.light,
    ).copyWith(
      primary: kJimBeamAmber,
      secondary: kOakBrown,
      surface: kCreamSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: kCreamSurface,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: kCreamSurface,
      ),
      // 2026-05-27 Codex audit Finding 4: cream 배경 (#FBF6EE) 와 white card 의
      // 대비 1.08:1 — 카드 경계 색만으로 거의 구분 불가. outlineVariant border
      // 추가로 카드 경계 시각 분리.
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: kJimBeamAmber,
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: kArranCaskGold,
      brightness: Brightness.dark,
    ).copyWith(
      primary: kArranCaskGold,
      surface: kPeatSmoke,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: kPeatBlack,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: kPeatBlack,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: kPeatSmoke,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kPeatSmoke,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: kPeatSmoke,
        selectedItemColor: kArranCaskGold,
      ),
    );
  }

  /// 기존 코드 호환 — `AppTheme.kAlbiAmber` 참조처 유지.
  /// Jim Beam 의 amber 가 그 자리에 대응.
  static const Color kAlbiAmber = kJimBeamAmber;
}

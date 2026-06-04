import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// 알비 테마 — 위스키 컨셉.
///
/// **Light**: 짐빔 (Jim Beam) — 버번 위스키의 황금 앰버 + 따뜻한 크림 배경.
/// **Dark**: 아란 마크리무어 캐스크 스트렝스 (Arran Machrie Moor CS) — 피트 + 셰리
/// 캐스크의 진한 황금 + 피트 블랙 배경.
///
/// 폰트: Pretendard. 간격/반경/타이포는 [AppTokens] SoT 경유.
class AppTheme {
  AppTheme._();

  // --- Jim Beam (Light) ---
  static const Color kJimBeamAmber = AppPalette.jimBeamAmber;
  static const Color kOakBrown = AppPalette.oakBrown;
  static const Color kCreamSurface = AppPalette.creamSurface;

  // --- Arran Machrie Moor CS (Dark) ---
  static const Color kArranCaskGold = AppPalette.arranCaskGold;
  static const Color kPeatBlack = AppPalette.peatBlack;
  static const Color kPeatSmoke = AppPalette.peatSmoke;

  static const _fontFamily = AppTypography.fontFamily;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: kJimBeamAmber,
      brightness: Brightness.light,
    ).copyWith(
      primary: kJimBeamAmber,
      secondary: kOakBrown,
      surface: kCreamSurface,
      error: AppPalette.error,
    );
    return _base(
      scheme: scheme,
      brightness: Brightness.light,
      scaffold: kCreamSurface,
      cardColor: Colors.white,
      // cream(#FBF6EE) 배경과 white card 대비 1.08:1 → outlineVariant 보더로 경계 분리.
      cardBorder: BorderSide(color: scheme.outlineVariant, width: 0.5),
      fieldFill: Colors.white,
      navBg: Colors.white,
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
    return _base(
      scheme: scheme,
      brightness: Brightness.dark,
      scaffold: kPeatBlack,
      cardColor: kPeatSmoke,
      cardBorder: BorderSide.none,
      fieldFill: kPeatSmoke,
      navBg: kPeatSmoke,
    );
  }

  /// Light/Dark 공통 컴포넌트 테마 — 토큰 기반 통일.
  static ThemeData _base({
    required ColorScheme scheme,
    required Brightness brightness,
    required Color scaffold,
    required Color cardColor,
    required BorderSide cardBorder,
    required Color fieldFill,
    required Color navBg,
  }) {
    final textTheme = AppTypography.textTheme(brightness)
        .apply(fontFamily: _fontFamily);
    // 표면 위 소형 강조 텍스트 — light amber 는 AA 미달이라 oakBrown 사용.
    final accentText = AppPalette.accentText(brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scaffold,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: cardBorder,
        ),
        color: cardColor,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.fieldR,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.fieldR,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.fieldR,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardR),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetR),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.fieldR),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: navBg,
        // 아이콘은 amber(대형 — 3:1 통과), 선택 라벨(소형)은 accentText(AA 통과).
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(color: accentText),
        unselectedLabelStyle: textTheme.labelSmall,
      ),
    );
  }

  /// 기존 코드 호환 — `AppTheme.kAlbiAmber` 참조처 유지.
  static const Color kAlbiAmber = kJimBeamAmber;
}

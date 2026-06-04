import 'package:flutter/material.dart';

/// 알비 디자인 토큰 — 간격/반경/모션/타이포/시맨틱 색상 SoT.
///
/// 위스키 컨셉(Light: Jim Beam amber, Dark: Arran cask)을 유지하면서,
/// 화면들이 하드코딩 대신 본 토큰을 경유하도록 통일한다.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets listV = EdgeInsets.symmetric(vertical: sm);
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  static const BorderRadius cardR = BorderRadius.all(Radius.circular(md));
  static const BorderRadius fieldR = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheetR =
      BorderRadius.vertical(top: Radius.circular(lg));
}

class AppDuration {
  AppDuration._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

/// 시맨틱/브랜드 색상 토큰. 위스키 팔레트 + 상태 색 + 소스 뱃지(WCAG AA 검증값).
class AppPalette {
  AppPalette._();

  // 위스키 브랜드 (app_theme 와 동일 SoT)
  static const Color jimBeamAmber = Color(0xFFB8731A); // light primary
  static const Color oakBrown = Color(0xFF5C3A1E); // light secondary
  static const Color creamSurface = Color(0xFFFBF6EE); // light bg
  static const Color arranCaskGold = Color(0xFFE0A857); // dark primary
  static const Color peatBlack = Color(0xFF15110D); // dark bg
  static const Color peatSmoke = Color(0xFF1F1812); // dark surface

  // 상태 색 (light 기준, WCAG AA 본문 대비 확보)
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFB25900);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF0055CC);

  // 소스 뱃지 (source_badge_widget 의 WCAG AA fix 값 — SoT 승격)
  static const Color sourceAiUserKey = Color(0xFF0055CC); // 4.7:1
  static const Color sourceAiAppKey = Color(0xFF006855); // 5.4:1
  static const Color sourceLocalParser = Color(0xFFB25900); // 4.5:1
  static const Color sourceManual = Color(0xFF5F5F5F); // 6.4:1
}

/// Pretendard 기반 TextTheme — 위계(display/headline/title/body/label).
class AppTypography {
  AppTypography._();
  static const String fontFamily = 'Pretendard';

  static TextTheme textTheme(Brightness brightness) {
    return const TextTheme(
      headlineMedium:
          TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25),
      headlineSmall:
          TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
      titleLarge:
          TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
      titleMedium:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
      titleSmall:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
      bodyLarge:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall:
          TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45),
      labelLarge:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
      labelMedium:
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
      labelSmall:
          TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3),
    );
  }
}

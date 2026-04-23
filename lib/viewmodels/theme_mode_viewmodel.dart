import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자가 선택한 ThemeMode 를 SharedPreferences 에 저장/로드.
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    state = AsyncData(mode);
  }
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
        ThemeModeNotifier.new);

/// ThemeMode → 한글 라벨.
String themeModeLabel(ThemeMode m) => switch (m) {
      ThemeMode.system => '시스템 따름',
      ThemeMode.light => '라이트',
      ThemeMode.dark => '다크',
    };

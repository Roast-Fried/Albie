import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsState {
  final String defaultQuantityUnit;
  final bool sixHourCutoffEnabled;

  const AppSettingsState({
    this.defaultQuantityUnit = 'glass',
    this.sixHourCutoffEnabled = true,
  });

  AppSettingsState copyWith({
    String? defaultQuantityUnit,
    bool? sixHourCutoffEnabled,
  }) {
    return AppSettingsState(
      defaultQuantityUnit: defaultQuantityUnit ?? this.defaultQuantityUnit,
      sixHourCutoffEnabled: sixHourCutoffEnabled ?? this.sixHourCutoffEnabled,
    );
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsViewModel, AppSettingsState>(
      AppSettingsViewModel.new,
    );

class AppSettingsViewModel extends AsyncNotifier<AppSettingsState> {
  static const _defaultUnitKey = 'default_quantity_unit';
  static const _sixHourCutoffKey = 'six_hour_cutoff_enabled';

  @override
  Future<AppSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettingsState(
      defaultQuantityUnit: prefs.getString(_defaultUnitKey) ?? 'glass',
      sixHourCutoffEnabled: prefs.getBool(_sixHourCutoffKey) ?? true,
    );
  }

  Future<void> setDefaultQuantityUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultUnitKey, unit);
    state = AsyncData(
      (state.valueOrNull ?? const AppSettingsState()).copyWith(
        defaultQuantityUnit: unit,
      ),
    );
  }

  Future<void> setSixHourCutoffEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sixHourCutoffKey, enabled);
    state = AsyncData(
      (state.valueOrNull ?? const AppSettingsState()).copyWith(
        sixHourCutoffEnabled: enabled,
      ),
    );
  }
}

String quantityUnitLabel(String unit) => switch (unit) {
  'glass' => '잔',
  'shot' => '샷',
  'bottle' => '병',
  'can' => '캔',
  'ml' => 'ml',
  'unknown' => '모름',
  _ => unit,
};

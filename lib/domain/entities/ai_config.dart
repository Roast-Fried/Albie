class AiConfig {
  final String provider;
  final String keyMode; // none | user_provided  (2026-05-26: app_default 제거 — env var 미동작)
  final String selectedModel; // gemini-2.5-flash-lite | gemini-2.5-flash
  final bool isEnabled;
  final DateTime? lastValidatedAt;
  final String? lastErrorMessage;

  AiConfig({
    this.provider = 'gemini',
    this.keyMode = 'none',
    this.selectedModel = 'gemini-2.5-flash-lite',
    this.isEnabled = false,
    this.lastValidatedAt,
    this.lastErrorMessage,
  });

  AiConfig copyWith({
    String? keyMode,
    String? selectedModel,
    bool? isEnabled,
    DateTime? lastValidatedAt,
    String? lastErrorMessage,
  }) {
    return AiConfig(
      provider: provider,
      keyMode: keyMode ?? this.keyMode,
      selectedModel: selectedModel ?? this.selectedModel,
      isEnabled: isEnabled ?? this.isEnabled,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1, // 싱글톤
      'provider': provider,
      'keyMode': keyMode,
      'selectedModel': selectedModel,
      'isEnabled': isEnabled ? 1 : 0,
      'lastValidatedAt': lastValidatedAt?.toIso8601String(),
      'lastErrorMessage': lastErrorMessage,
    };
  }

  factory AiConfig.fromMap(Map<String, dynamic> map) {
    return AiConfig(
      provider: map['provider'] as String? ?? 'gemini',
      // Legacy normalize: 기존 'app_default' row 는 'none' 으로 강등 (env var 미동작).
      keyMode: (map['keyMode'] == 'user_provided') ? 'user_provided' : 'none',
      selectedModel:
          map['selectedModel'] as String? ?? 'gemini-2.5-flash-lite',
      isEnabled: (map['isEnabled'] as int?) == 1,
      lastValidatedAt: map['lastValidatedAt'] != null
          ? DateTime.parse(map['lastValidatedAt'] as String)
          : null,
      lastErrorMessage: map['lastErrorMessage'] as String?,
    );
  }
}

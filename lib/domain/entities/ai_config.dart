class AiConfig {
  final String provider;
  final String keyMode; // none | app_default | user_provided
  final String selectedModel; // gemini-2.5-flash-lite | gemini-2.5-flash
  final bool isEnabled;
  final DateTime? lastValidatedAt;
  final String? lastErrorMessage;

  AiConfig({
    this.provider = 'gemini',
    this.keyMode = 'app_default',
    this.selectedModel = 'gemini-2.5-flash-lite',
    this.isEnabled = true,
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
      keyMode: map['keyMode'] as String? ?? 'app_default',
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

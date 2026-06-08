import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/providers.dart';
import '../domain/entities/ai_config.dart';
import '../domain/entities/parse_job.dart';
import '../domain/entities/usage_quota.dart';
import '../integrations/gemini/gemini_client.dart';

final aiConfigProvider =
    AsyncNotifierProvider<AiSettingsViewModel, AiSettingsState>(
        AiSettingsViewModel.new);

/// AI 설정 화면 하단의 "최근 처리 로그" 목록.
final recentParseJobsProvider = FutureProvider<List<ParseJob>>((ref) async {
  final repo = ref.watch(parseJobRepoProvider);
  return repo.getRecent(limit: 10);
});

class AiSettingsState {
  final AiConfig config;
  final UsageQuota quota;
  final bool hasUserKey;
  final bool isValidating;

  AiSettingsState({
    required this.config,
    required this.quota,
    this.hasUserKey = false,
    this.isValidating = false,
  });

  AiSettingsState copyWith({
    AiConfig? config,
    UsageQuota? quota,
    bool? hasUserKey,
    bool? isValidating,
  }) {
    return AiSettingsState(
      config: config ?? this.config,
      quota: quota ?? this.quota,
      hasUserKey: hasUserKey ?? this.hasUserKey,
      isValidating: isValidating ?? this.isValidating,
    );
  }
}

class AiSettingsViewModel extends AsyncNotifier<AiSettingsState> {
  static const _storage = FlutterSecureStorage();
  final _geminiClient = GeminiClient();

  @override
  Future<AiSettingsState> build() async {
    final repo = ref.watch(aiConfigRepoProvider);
    final config = await repo.get();
    final quota = await repo.getQuotaToday();
    final key = await _storage.read(key: 'gemini_api_key');

    return AiSettingsState(
      config: config,
      quota: quota,
      hasUserKey: key != null && key.isNotEmpty,
    );
  }

  Future<void> toggleEnabled(bool enabled) async {
    final repo = ref.read(aiConfigRepoProvider);
    final config = (await future).config;
    await repo.update(config.copyWith(isEnabled: enabled));
    ref.invalidateSelf();
  }

  // 2026-05-26: app_default 제거 — setKeyMode 외부 호출처 없음. saveApiKey/deleteApiKey 에서 직접 'user_provided' / 'none' 설정.

  Future<void> selectModel(String model) async {
    final repo = ref.read(aiConfigRepoProvider);
    final config = (await future).config;
    await repo.update(config.copyWith(selectedModel: model));
    ref.invalidateSelf();
  }

  Future<String?> saveApiKey(String key) async {
    if (key.trim().isEmpty) return '키를 입력해주세요';

    final valid = await _geminiClient.validateKey(key.trim());
    if (!valid) return 'API Key가 유효하지 않습니다';

    await _storage.write(key: 'gemini_api_key', value: key.trim());

    final repo = ref.read(aiConfigRepoProvider);
    final config = (await future).config;
    // 키 등록 = AI 사용 의사 표시 → isEnabled 자동 활성화.
    // (홈 "AI로 생성" 게이트가 isEnabled && hasUserKey 를 함께 본다)
    await repo.update(config.copyWith(
      keyMode: 'user_provided',
      isEnabled: true,
      lastValidatedAt: DateTime.now(),
      lastErrorMessage: null,
    ));

    ref.invalidateSelf();
    return null; // 성공
  }

  Future<void> deleteApiKey() async {
    await _storage.delete(key: 'gemini_api_key');
    final repo = ref.read(aiConfigRepoProvider);
    final config = (await future).config;
    await repo.update(config.copyWith(keyMode: 'none', isEnabled: false));
    ref.invalidateSelf();
  }
}

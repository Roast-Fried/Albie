import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 앱 전역 설정값 — credential 주입의 단일 출처(Single Source of Truth).
///
/// 우선순위: (1) 런타임 `.env`(flutter_dotenv) → (2) 빌드타임 `--dart-define`.
/// 둘 다 비어 있으면 빈 문자열을 반환하며, 해당 기능은 **dormant**(비활성)로
/// 기존 로컬 동작을 100% 그대로 유지한다.
///
/// 사용자는 `.env.example` 을 참고해 `.env` 값만 채우면(또는 `--dart-define` 전달)
/// 클라우드 백업·동기화 등 credential 기능이 활성화된다. → docs/supabase-setup.md
///
/// 보안 주의:
/// - `SUPABASE_ANON_KEY` 는 클라이언트 공개 키(RLS 로 데이터 보호)라 커밋해도 안전.
/// - `GEMINI_API_KEY` 는 비밀 키라 `.env`(공개 asset)에서 읽지 않는다. 앱 내 보안
///   저장소 입력을 기본으로 하고, 빌드타임 `--dart-define` 으로만 주입 가능.
class AppConfig {
  AppConfig._();

  // 빌드타임 --dart-define fallback. String.fromEnvironment 의 key 는 컴파일타임
  // const literal 이어야 하므로 미리 선언한다(미전달 시 기본값 '').
  static const String _defineSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const String _defineSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String _defineGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );

  static String get supabaseUrl => _read('SUPABASE_URL', _defineSupabaseUrl);

  static String get supabaseAnonKey =>
      _read('SUPABASE_ANON_KEY', _defineSupabaseAnonKey);

  // Gemini 키는 비밀이므로 `.env`(공개 asset)에서 읽지 않는다. 빌드타임
  // `--dart-define` 만 허용(일반 사용은 앱 내 보안 저장소 입력 권장).
  static String get geminiApiKey => _defineGeminiApiKey.trim();

  /// Supabase credential 이 모두 채워졌는지 — 클라우드 기능 활성 게이트.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// 빌드 기본 Gemini 키 존재 여부 — 인앱 입력이 없을 때 fallback 으로 사용.
  static bool get hasGeminiBuildKey => geminiApiKey.isNotEmpty;

  /// (1) 런타임 `.env` → (2) 빌드타임 `--dart-define` → (3) 빈 문자열.
  ///
  /// dotenv 가 초기화되지 않았거나(로드 실패/asset 부재) 키가 비어 있으면
  /// 빌드타임 fallback 으로 넘어간다. 어느 쪽도 없으면 ''.
  static String _read(String key, String defineFallback) {
    if (dotenv.isInitialized) {
      final v = dotenv.maybeGet(key);
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return defineFallback.trim();
  }
}

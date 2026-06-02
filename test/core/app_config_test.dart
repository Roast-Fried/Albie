import 'package:albi/core/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// dotenv 미초기화 + --dart-define 미전달 환경(= 기본 빌드)에서 모든 credential 이
/// 비어 있어 기능이 dormant 상태임을 검증. 이 상태가 "사용자가 .env 를 채우기 전"의
/// 기존 로컬 동작 보존을 보장한다.
void main() {
  group('AppConfig — credential 미설정 (dormant 기본값)', () {
    test('Supabase URL/anonKey 는 빈 문자열', () {
      expect(AppConfig.supabaseUrl, '');
      expect(AppConfig.supabaseAnonKey, '');
    });

    test('Gemini API key 는 빈 문자열', () {
      expect(AppConfig.geminiApiKey, '');
    });

    test('hasSupabase 는 false — 클라우드 기능 비활성', () {
      expect(AppConfig.hasSupabase, isFalse);
    });

    test('hasGeminiBuildKey 는 false — 인앱 키 흐름 유지', () {
      expect(AppConfig.hasGeminiBuildKey, isFalse);
    });
  });
}

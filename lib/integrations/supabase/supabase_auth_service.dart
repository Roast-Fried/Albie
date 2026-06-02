import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions.dart';

/// Supabase 이메일 인증 래퍼 — 가입/로그인/로그아웃. 오류는 앱 sealed AppError 로
/// 매핑(잘못된 자격증명 → ValidationError, 그 외 → NetworkError).
class SupabaseAuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signUp(String email, String password) async {
    await _guard(
      () => _client.auth.signUp(email: email.trim(), password: password),
    );
  }

  Future<void> signIn(String email, String password) async {
    await _guard(
      () => _client.auth
          .signInWithPassword(email: email.trim(), password: password),
    );
  }

  Future<void> signOut() async {
    await _guard(() => _client.auth.signOut());
  }

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on AuthException catch (e) {
      throw ValidationError(_authMessage(e), cause: e);
    } catch (e) {
      throw NetworkError('네트워크 오류로 처리하지 못했어요', cause: e);
    }
  }

  String _authMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid') || msg.contains('credential')) {
      return '이메일 또는 비밀번호를 확인해주세요';
    }
    if (msg.contains('already registered') || msg.contains('exists')) {
      return '이미 가입된 이메일이에요';
    }
    if (msg.contains('password')) {
      return '비밀번호는 6자 이상이어야 해요';
    }
    return e.message;
  }
}

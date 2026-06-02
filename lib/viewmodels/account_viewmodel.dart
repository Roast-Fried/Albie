import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integrations/supabase/supabase_providers.dart';

/// 계정/백업 화면 상태 — Supabase 설정 여부 + 로그인 여부 + 마지막 백업 시각.
class AccountInfo {
  const AccountInfo({required this.configured, this.email, this.lastBackupAt});

  /// `.env` 에 Supabase credential 이 채워져 클라우드 기능이 활성화됐는지.
  final bool configured;

  /// 로그인한 이메일(null = 로그아웃 상태).
  final String? email;

  /// 마지막 백업 시각(SharedPreferences 보관 — DB 변경 회피).
  final DateTime? lastBackupAt;

  bool get loggedIn => email != null;
}

final accountProvider =
    AsyncNotifierProvider<AccountNotifier, AccountInfo>(AccountNotifier.new);

class AccountNotifier extends AsyncNotifier<AccountInfo> {
  static const _kLastBackup = 'last_backup_at';

  @override
  Future<AccountInfo> build() async {
    final auth = ref.watch(supabaseAuthServiceProvider);
    if (auth == null) {
      return const AccountInfo(configured: false);
    }
    // 로그인/로그아웃 시 자동 새로고침.
    final sub = auth.onAuthStateChange.listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);

    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_kLastBackup);
    return AccountInfo(
      configured: true,
      email: auth.currentUser?.email,
      lastBackupAt: iso != null ? DateTime.tryParse(iso) : null,
    );
  }

  /// 로그인 — 실패 시 AppError 를 던진다(호출 화면에서 표시).
  Future<void> signIn(String email, String password) async {
    final auth = ref.read(supabaseAuthServiceProvider);
    if (auth == null) return;
    await auth.signIn(email, password);
    ref.invalidateSelf();
  }

  /// 회원가입 — 실패 시 AppError 를 던진다.
  Future<void> signUp(String email, String password) async {
    final auth = ref.read(supabaseAuthServiceProvider);
    if (auth == null) return;
    await auth.signUp(email, password);
    ref.invalidateSelf();
  }

  Future<void> signOut() async {
    final auth = ref.read(supabaseAuthServiceProvider);
    if (auth == null) return;
    await auth.signOut();
    ref.invalidateSelf();
  }

  /// 백업 성공 시각 기록.
  Future<void> markBackedUp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastBackup, DateTime.now().toIso8601String());
    ref.invalidateSelf();
  }
}

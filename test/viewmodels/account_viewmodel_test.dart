import 'package:albi/viewmodels/account_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Supabase credential 미설정(기본 빌드)에서 계정 기능이 dormant 임을 검증.
/// supabaseClientProvider 가 AppConfig.hasSupabase=false 로 null 을 반환하므로
/// Supabase.initialize 없이도 안전하게 configured=false 가 나와야 한다.
void main() {
  test('Supabase 미설정 → accountProvider 는 configured=false (dormant)',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final info = await container.read(accountProvider.future);

    expect(info.configured, isFalse);
    expect(info.loggedIn, isFalse);
    expect(info.email, isNull);
    expect(info.lastBackupAt, isNull);
  });
}

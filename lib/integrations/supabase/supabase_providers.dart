import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';
import '../../core/providers.dart';
import 'supabase_auth_service.dart';
import 'supabase_sync_service.dart';

/// `Supabase.initialize` 성공 여부 — main 에서 설정한다. credential 이 채워져
/// `AppConfig.hasSupabase` 이더라도 초기화가 실패하면 false 로 남아 dormant 로
/// 강제 전환된다(초기화 안 된 `Supabase.instance` 접근 시 예외 방지).
bool supabaseInitialized = false;

/// Supabase 클라이언트 — credential 미설정 또는 초기화 실패 시 null(dormant).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppConfig.hasSupabase || !supabaseInitialized) return null;
  return Supabase.instance.client;
});

final supabaseAuthServiceProvider = Provider<SupabaseAuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAuthService(client);
});

final supabaseSyncServiceProvider = Provider<SupabaseSyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  final service = SupabaseSyncService(
    client,
    ref.watch(drinkLogRepoProvider),
    ref.watch(tastingNoteRepoProvider),
    ref.watch(liquorMasterRepoProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

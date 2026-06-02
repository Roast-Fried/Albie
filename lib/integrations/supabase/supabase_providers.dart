import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';
import '../../core/providers.dart';
import 'supabase_auth_service.dart';
import 'supabase_sync_service.dart';

/// Supabase 클라이언트 — `.env` 미설정(hasSupabase=false) 이면 null(dormant).
/// main 에서 hasSupabase 일 때만 Supabase.initialize 가 호출된다.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppConfig.hasSupabase) return null;
  return Supabase.instance.client;
});

final supabaseAuthServiceProvider = Provider<SupabaseAuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAuthService(client);
});

final supabaseSyncServiceProvider = Provider<SupabaseSyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  final repo = ref.watch(drinkLogRepoProvider);
  final service = SupabaseSyncService(client, repo);
  ref.onDispose(service.dispose);
  return service;
});

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions.dart';
import '../../data/drink_log_repository.dart';
import 'backup_codec.dart';

/// 동기화 진행 상태 — account 화면에서 StreamBuilder 로 표시.
enum SyncStatus { idle, syncing, done, error }

/// 클라우드 백업/복원 — offline-first. 로컬(DrinkLogRepository)이 SoT 이며,
/// 클라우드는 사용자당 1행 스냅샷(`drink_backups`). 네트워크 실패는 NetworkError
/// 로 표면화하되 로컬 데이터는 건드리지 않는다.
class SupabaseSyncService {
  SupabaseSyncService(this._client, this._repo);

  final SupabaseClient _client;
  final DrinkLogRepository _repo;

  static const _table = 'drink_backups';

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// 로컬 전체 스냅샷을 클라우드에 백업(upsert, 멱등). 반환=백업한 기록 수.
  Future<int> backup() async {
    final userId = _requireUserId();
    _statusController.add(SyncStatus.syncing);
    try {
      final logs = await _repo.getAll();
      await _client.from(_table).upsert({
        'user_id': userId,
        'payload': encodeBackup(logs),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _statusController.add(SyncStatus.done);
      return logs.length;
    } catch (e) {
      _statusController.add(SyncStatus.error);
      if (e is AppError) rethrow;
      throw NetworkError('백업 중 오류가 발생했어요', cause: e);
    }
  }

  /// 클라우드 스냅샷을 로컬에 저장. 반환=복원된 기록 수(백업 없으면 0).
  /// 호출측에서 기존 로컬을 비운 뒤 호출하면 "교체" 의미가 된다.
  Future<int> restore() async {
    final userId = _requireUserId();
    _statusController.add(SyncStatus.syncing);
    try {
      final row = await _client
          .from(_table)
          .select('payload')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        _statusController.add(SyncStatus.done);
        return 0;
      }
      final logs =
          decodeBackup((row['payload'] as Map).cast<String, dynamic>());
      for (final log in logs) {
        await _repo.save(log);
      }
      _statusController.add(SyncStatus.done);
      return logs.length;
    } catch (e) {
      _statusController.add(SyncStatus.error);
      if (e is AppError) rethrow;
      throw NetworkError('복원 중 오류가 발생했어요', cause: e);
    }
  }

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const ValidationError('로그인이 필요해요');
    return id;
  }

  void dispose() => _statusController.close();
}

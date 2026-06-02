import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/exceptions.dart';
import '../../data/drink_log_repository.dart';
import '../../data/liquor_master_repository.dart';
import '../../data/tasting_note_repository.dart';
import '../../domain/entities/drink_log.dart';
import '../../domain/entities/tasting_note.dart';
import 'backup_codec.dart';

/// 동기화 진행 상태 — account 화면에서 StreamBuilder 로 표시.
enum SyncStatus { idle, syncing, done, error }

/// 클라우드 백업/복원 — offline-first. 로컬(SQLite)이 SoT 이며, 클라우드는
/// 사용자당 1행 스냅샷(`drink_backups`). 복원은 "fetch → (확인) → wipe → apply"
/// 순서라 네트워크 실패 시 로컬 데이터가 유실되지 않는다.
class SupabaseSyncService {
  SupabaseSyncService(
    this._client,
    this._drinkLogRepo,
    this._tastingNoteRepo,
    this._liquorMasterRepo,
  );

  final SupabaseClient _client;
  final DrinkLogRepository _drinkLogRepo;
  final TastingNoteRepository _tastingNoteRepo;
  final LiquorMasterRepository _liquorMasterRepo;

  static const _table = 'drink_backups';

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// 로컬 전체 스냅샷(로그+항목+음식+테이스팅 노트)을 클라우드에 백업(upsert).
  /// 반환=백업한 기록 수.
  Future<int> backup() async {
    final userId = _requireUserId();
    _statusController.add(SyncStatus.syncing);
    try {
      final logs = await _drinkLogRepo.getAll();

      final entryIds = [
        for (final l in logs)
          for (final e in l.entries)
            if (e.id != null) e.id!,
      ];
      final notes = await _tastingNoteRepo.getByEntryIds(entryIds);
      final noteByEntry = {for (final n in notes) n.entryId: n};

      final masters = await _liquorMasterRepo.getAll();
      final canonicalById = {
        for (final m in masters)
          if (m.id != null) m.id!: m.canonicalName,
      };

      final backups = [
        for (final log in logs)
          LogBackup(
            log: log,
            entries: [
              for (final e in log.entries)
                EntryBackup(
                  entry: e,
                  masterCanonical: e.liquorMasterId != null
                      ? canonicalById[e.liquorMasterId]
                      : null,
                  note: e.id != null ? noteByEntry[e.id] : null,
                ),
            ],
          ),
      ];

      await _client.from(_table).upsert({
        'user_id': userId,
        'payload': encodeBackup(backups),
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

  /// 클라우드 스냅샷을 가져온다(네트워크만, 로컬 미변경). null = 백업 없음.
  /// offline-first: 호출측은 이 호출이 성공한 뒤에만 로컬을 비우고 [applyRestore].
  Future<List<LogBackup>?> fetchBackup() async {
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
        return null;
      }
      final backups =
          decodeBackup((row['payload'] as Map).cast<String, dynamic>());
      _statusController.add(SyncStatus.done);
      return backups;
    } catch (e) {
      _statusController.add(SyncStatus.error);
      if (e is AppError) rethrow;
      throw NetworkError('복원 데이터를 가져오지 못했어요', cause: e);
    }
  }

  /// 가져온 스냅샷을 로컬에 저장(호출측이 기존 로컬을 비운 뒤 호출 → 교체).
  /// 마스터 id 는 canonicalName 으로 재매칭(없으면 null — FK 안전), 테이스팅
  /// 노트는 복원된 새 entryId 에 재연결한다.
  Future<void> applyRestore(List<LogBackup> backups) async {
    final masters = await _liquorMasterRepo.getAll();
    final idByCanonical = {
      for (final m in masters)
        if (m.id != null) m.canonicalName.toLowerCase(): m.id!,
    };

    for (final b in backups) {
      final entries = [
        for (final eb in b.entries)
          DrinkEntry(
            liquorMasterId: eb.masterCanonical != null
                ? idByCanonical[eb.masterCanonical!.toLowerCase()]
                : null,
            liquorNameRaw: eb.entry.liquorNameRaw,
            liquorCategory: eb.entry.liquorCategory,
            ageStatement: eb.entry.ageStatement,
            quantityValue: eb.entry.quantityValue,
            quantityUnit: eb.entry.quantityUnit,
            isEstimated: eb.entry.isEstimated,
            alcoholPercent: eb.entry.alcoholPercent,
          ),
      ];
      final log = DrinkLog(
        rawInputText: b.log.rawInputText,
        rawImagePath: b.log.rawImagePath,
        parseSource: b.log.parseSource,
        place: b.log.place,
        overallMemo: b.log.overallMemo,
        drankAt: b.log.drankAt,
        userConfirmedAt: b.log.userConfirmedAt,
        createdAt: b.log.createdAt,
        updatedAt: b.log.updatedAt,
        entries: entries,
        foodItems: b.log.foodItems,
      );
      final newLogId = await _drinkLogRepo.save(log);

      // 테이스팅 노트 재연결 — 저장된 새 entryId 순서로 매칭.
      if (b.entries.any((e) => e.note != null)) {
        final saved = await _drinkLogRepo.getById(newLogId);
        final savedEntries = saved?.entries ?? const <DrinkEntry>[];
        for (var i = 0; i < b.entries.length && i < savedEntries.length; i++) {
          final note = b.entries[i].note;
          final savedId = savedEntries[i].id;
          if (note != null && savedId != null) {
            await _tastingNoteRepo.save(
              TastingNote(
                entryId: savedId,
                nose: note.nose,
                palate: note.palate,
                finish: note.finish,
                rating: note.rating,
                note: note.note,
              ),
            );
          }
        }
      }
    }
  }

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const ValidationError('로그인이 필요해요');
    return id;
  }

  void dispose() => _statusController.close();
}

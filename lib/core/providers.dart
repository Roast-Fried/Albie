import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'database/database_helper.dart';
import '../data/drink_log_repository.dart';
import '../data/liquor_master_repository.dart';
import '../data/ai_config_repository.dart';
import '../data/parse_job_repository.dart';
import '../data/tasting_note_repository.dart';
import '../domain/entities/drink_log.dart';
import '../domain/entities/tasting_note.dart';

/// DB 인스턴스
final databaseProvider = FutureProvider<Database>((ref) async {
  return DatabaseHelper.instance.database;
});

/// AppShell 의 BottomNav 탭 인덱스 (0=홈, 1=기록, 2=더보기).
/// 다른 화면에서 프로그램적으로 탭을 전환할 때 사용.
final appTabIndexProvider = StateProvider<int>((ref) => 0);

/// Repositories — AppShell이 DB 준비 완료를 보장한 후에만 접근됨
final drinkLogRepoProvider = Provider<DrinkLogRepository>((ref) {
  final db = ref.watch(databaseProvider).requireValue;
  return DrinkLogRepository(db);
});

final liquorMasterRepoProvider = Provider<LiquorMasterRepository>((ref) {
  final db = ref.watch(databaseProvider).requireValue;
  return LiquorMasterRepository(db);
});

final aiConfigRepoProvider = Provider<AiConfigRepository>((ref) {
  final db = ref.watch(databaseProvider).requireValue;
  return AiConfigRepository(db);
});

final parseJobRepoProvider = Provider<ParseJobRepository>((ref) {
  final db = ref.watch(databaseProvider).requireValue;
  return ParseJobRepository(db);
});

final tastingNoteRepoProvider = Provider<TastingNoteRepository>((ref) {
  final db = ref.watch(databaseProvider).requireValue;
  return TastingNoteRepository(db);
});

/// entry id 별 테이스팅 노트 조회 (없으면 null).
final tastingNoteByEntryProvider =
    FutureProvider.family<TastingNote?, int>((ref, entryId) async {
  final repo = ref.watch(tastingNoteRepoProvider);
  return repo.getByEntryId(entryId);
});

/// ── 공유 데이터 Providers (홈/목록 등 여러 화면에서 사용) ──

/// 최근 기록 (홈 위젯용)
final recentLogsProvider = FutureProvider<List<DrinkLog>>((ref) async {
  final repo = ref.watch(drinkLogRepoProvider);
  return repo.getAll(limit: 5);
});

/// 전체 기록 수 (홈 통계 카드용)
final logCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(drinkLogRepoProvider);
  return repo.count();
});

/// 이번 달 기록 수 (홈 하단 카드).
///
/// 경계 inclusive — stats_viewmodel 의 `!isBefore` 와 일관 (월 1일 00:00 누락 방지).
final thisMonthLogCountProvider = FutureProvider<int>((ref) async {
  final logs = await ref.watch(drinkLogRepoProvider).getAll();
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  return logs.where((l) => !l.drankAt.isBefore(monthStart)).length;
});

/// "최근 마셔본 술" chips — 최근 한 달 내 기록에서 많이 등장한 브랜드 상위 6 개.
final recentFrequentLiquorsProvider =
    FutureProvider<List<String>>((ref) async {
  final logs = await ref.watch(drinkLogRepoProvider).getAll();
  final now = DateTime.now();
  final monthAgo = DateTime(now.year, now.month - 1, now.day);
  final counts = <String, int>{};
  for (final log in logs) {
    if (!log.drankAt.isAfter(monthAgo)) continue;
    for (final e in log.entries) {
      final name = e.liquorNameRaw.trim();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(6).map((e) => e.key).toList();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'database/database_helper.dart';
import '../data/drink_log_repository.dart';
import '../data/liquor_master_repository.dart';
import '../data/ai_config_repository.dart';
import '../data/parse_job_repository.dart';
import '../data/tasting_note_repository.dart';

/// DB 인스턴스
final databaseProvider = FutureProvider<Database>((ref) async {
  return DatabaseHelper.instance.database;
});

/// Repositories — DB가 준비된 후 사용
final drinkLogRepoProvider = Provider<DrinkLogRepository>((ref) {
  final db = ref.watch(databaseProvider).value;
  if (db == null) throw StateError('Database not ready');
  return DrinkLogRepository(db);
});

final liquorMasterRepoProvider = Provider<LiquorMasterRepository>((ref) {
  final db = ref.watch(databaseProvider).value;
  if (db == null) throw StateError('Database not ready');
  return LiquorMasterRepository(db);
});

final aiConfigRepoProvider = Provider<AiConfigRepository>((ref) {
  final db = ref.watch(databaseProvider).value;
  if (db == null) throw StateError('Database not ready');
  return AiConfigRepository(db);
});

final parseJobRepoProvider = Provider<ParseJobRepository>((ref) {
  final db = ref.watch(databaseProvider).value;
  if (db == null) throw StateError('Database not ready');
  return ParseJobRepository(db);
});

final tastingNoteRepoProvider = Provider<TastingNoteRepository>((ref) {
  final db = ref.watch(databaseProvider).value;
  if (db == null) throw StateError('Database not ready');
  return TastingNoteRepository(db);
});

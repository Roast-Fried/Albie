import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/liquor_master.dart';

/// 아카이브 아이템 — 술 + 집계 정보
class ArchiveItem {
  final String liquorNameRaw;
  final int? liquorMasterId;
  final String category;
  final int recordCount;
  final DateTime? lastDrankAt;
  final String? nameKo;
  final String? canonicalName;
  final bool isFavorite;

  ArchiveItem({
    required this.liquorNameRaw,
    this.liquorMasterId,
    required this.category,
    required this.recordCount,
    this.lastDrankAt,
    this.nameKo,
    this.canonicalName,
    this.isFavorite = false,
  });

  String get displayName => nameKo ?? canonicalName ?? liquorNameRaw;
}

final archiveCategoryFilter = StateProvider<String?>((ref) => null);

final archiveListProvider =
    AsyncNotifierProvider<ArchiveViewModel, List<ArchiveItem>>(
        ArchiveViewModel.new);

class ArchiveViewModel extends AsyncNotifier<List<ArchiveItem>> {
  @override
  Future<List<ArchiveItem>> build() async {
    final filter = ref.watch(archiveCategoryFilter);
    return _loadArchive(filter);
  }

  Future<List<ArchiveItem>> _loadArchive(String? categoryFilter) async {
    final logRepo = ref.read(drinkLogRepoProvider);
    final masterRepo = ref.read(liquorMasterRepoProvider);

    final logs = await logRepo.getAll();
    // entry별 집계
    final Map<String, _Agg> agg = {};

    for (final log in logs) {
      for (final entry in log.entries) {
        final key = entry.liquorMasterId?.toString() ??
            entry.liquorNameRaw.toLowerCase();

        if (categoryFilter != null && entry.liquorCategory != categoryFilter) {
          continue;
        }

        agg.putIfAbsent(
            key,
            () => _Agg(
                  liquorNameRaw: entry.liquorNameRaw,
                  liquorMasterId: entry.liquorMasterId,
                  category: entry.liquorCategory,
                ));
        agg[key]!.count++;
        final drankAt = log.drankAt;
        if (agg[key]!.lastDrankAt == null ||
            drankAt.isAfter(agg[key]!.lastDrankAt!)) {
          agg[key]!.lastDrankAt = drankAt;
        }
      }
    }

    // 마스터 정보 보강
    final items = <ArchiveItem>[];
    for (final a in agg.values) {
      LiquorMaster? master;
      if (a.liquorMasterId != null) {
        master = await masterRepo.getById(a.liquorMasterId!);
      }
      items.add(ArchiveItem(
        liquorNameRaw: a.liquorNameRaw,
        liquorMasterId: a.liquorMasterId,
        category: a.category,
        recordCount: a.count,
        lastDrankAt: a.lastDrankAt,
        nameKo: master?.nameKo,
        canonicalName: master?.canonicalName,
        isFavorite: master?.isFavorite ?? false,
      ));
    }

    items.sort((a, b) => b.recordCount.compareTo(a.recordCount));
    return items;
  }

  Future<void> toggleFavorite(int masterId, bool current) async {
    await ref.read(liquorMasterRepoProvider).toggleFavorite(masterId, !current);
    ref.invalidateSelf();
  }
}

class _Agg {
  final String liquorNameRaw;
  final int? liquorMasterId;
  final String category;
  int count = 0;
  DateTime? lastDrankAt;

  _Agg({
    required this.liquorNameRaw,
    this.liquorMasterId,
    required this.category,
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/liquor_master.dart';

/// 아카이브 아이템 — 술 + 집계 정보
class ArchiveItem {
  final String liquorNameRaw;
  final int? liquorMasterId;
  final String category;
  final String? subcategory;
  final int recordCount;
  final DateTime? lastDrankAt;
  final String? nameKo;
  final String? canonicalName;
  final String? country;
  final double? defaultAbv;
  final bool isFavorite;
  final double? avgRating;

  ArchiveItem({
    required this.liquorNameRaw,
    this.liquorMasterId,
    required this.category,
    this.subcategory,
    required this.recordCount,
    this.lastDrankAt,
    this.nameKo,
    this.canonicalName,
    this.country,
    this.defaultAbv,
    this.isFavorite = false,
    this.avgRating,
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
    final noteRepo = ref.read(tastingNoteRepoProvider);

    final logs = await logRepo.getAll();

    // entry별 집계 + entry id 수집 (avgRating 계산용)
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
        if (entry.id != null) agg[key]!.entryIds.add(entry.id!);
        final drankAt = log.drankAt;
        if (agg[key]!.lastDrankAt == null ||
            drankAt.isAfter(agg[key]!.lastDrankAt!)) {
          agg[key]!.lastDrankAt = drankAt;
        }
      }
    }

    // 전체 entry id 한 번에 batch 조회해 평점 그룹핑
    final allEntryIds =
        agg.values.expand((a) => a.entryIds).toList();
    final notes = await noteRepo.getByEntryIds(allEntryIds);
    final ratingByEntry = <int, double>{
      for (final n in notes)
        if (n.rating != null) n.entryId: n.rating!,
    };

    // 마스터 정보 + 평점 평균 병합
    final items = <ArchiveItem>[];
    for (final a in agg.values) {
      LiquorMaster? master;
      if (a.liquorMasterId != null) {
        master = await masterRepo.getById(a.liquorMasterId!);
      }
      final ratings =
          a.entryIds.map((id) => ratingByEntry[id]).whereType<double>().toList();
      final avg = ratings.isEmpty
          ? null
          : ratings.reduce((x, y) => x + y) / ratings.length;
      items.add(ArchiveItem(
        liquorNameRaw: a.liquorNameRaw,
        liquorMasterId: a.liquorMasterId,
        category: a.category,
        subcategory: master?.subcategory,
        recordCount: a.count,
        lastDrankAt: a.lastDrankAt,
        nameKo: master?.nameKo,
        canonicalName: master?.canonicalName,
        country: master?.country,
        defaultAbv: master?.defaultAbv,
        isFavorite: master?.isFavorite ?? false,
        avgRating: avg,
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
  final List<int> entryIds = [];

  _Agg({
    required this.liquorNameRaw,
    this.liquorMasterId,
    required this.category,
  });
}

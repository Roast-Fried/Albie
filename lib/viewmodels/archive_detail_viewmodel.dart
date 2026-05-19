import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/drink_log.dart';
import '../domain/entities/liquor_master.dart';
import 'archive_viewmodel.dart';

/// 아카이브 상세 화면 데이터 집계 결과.
class ArchiveDetailData {
  final LiquorMaster master;
  final int totalRecords; // 이 브랜드가 포함된 log 의 개수
  final int totalEntries; // 이 브랜드 entry 총 개수 (단위 혼재 회피 — "총 음주량" 대체)
  final double? avgRating; // tastingNote.rating 있는 entry 만 평균, 없으면 null
  final List<ArchiveHistoryItem> history; // 최신순

  ArchiveDetailData({
    required this.master,
    required this.totalRecords,
    required this.totalEntries,
    required this.avgRating,
    required this.history,
  });
}

class ArchiveHistoryItem {
  final DateTime drankAt;
  final double quantityValue;
  final String quantityUnit;
  final double? rating;
  final String? place;

  ArchiveHistoryItem({
    required this.drankAt,
    required this.quantityValue,
    required this.quantityUnit,
    this.rating,
    this.place,
  });
}

final archiveDetailProvider = FutureProvider.family<ArchiveDetailData, int>((
  ref,
  masterId,
) async {
  final logRepo = ref.watch(drinkLogRepoProvider);
  final masterRepo = ref.watch(liquorMasterRepoProvider);
  final noteRepo = ref.watch(tastingNoteRepoProvider);

  final master = await masterRepo.getById(masterId);
  if (master == null) {
    throw StateError('liquorMaster($masterId) 가 존재하지 않습니다');
  }

  final logs = await logRepo.getAll();

  // 해당 masterId entry 가 있는 log 만 추리기
  final matchedLogs = <DrinkLog>[];
  final matchingEntryIds = <int>[];
  final history = <ArchiveHistoryItem>[];
  var totalEntries = 0;

  for (final log in logs) {
    final ownedEntries = log.entries
        .where((e) => e.liquorMasterId == masterId)
        .toList();
    if (ownedEntries.isEmpty) continue;
    matchedLogs.add(log);

    for (final e in ownedEntries) {
      totalEntries++;
      if (e.id != null) matchingEntryIds.add(e.id!);
      history.add(
        ArchiveHistoryItem(
          drankAt: log.drankAt,
          quantityValue: e.quantityValue,
          quantityUnit: e.quantityUnit,
          place: log.place,
        ),
      );
    }
  }

  // 평점 평균 — 노트 있는 entry 만
  double? avgRating;
  if (matchingEntryIds.isNotEmpty) {
    final notes = await noteRepo.getByEntryIds(matchingEntryIds);
    final ratings = notes.map((n) => n.rating).whereType<double>().toList();
    if (ratings.isNotEmpty) {
      avgRating = ratings.reduce((a, b) => a + b) / ratings.length;

      // history item 에 rating 매핑 — entry id 기반 간단 lookup
      final ratingByEntry = <int, double>{};
      for (final n in notes) {
        if (n.rating != null) ratingByEntry[n.entryId] = n.rating!;
      }
      // 기록을 다시 돌며 rating 병합
      final enrichedHistory = <ArchiveHistoryItem>[];
      for (final log in matchedLogs) {
        for (final e in log.entries.where(
          (e) => e.liquorMasterId == masterId,
        )) {
          final r = e.id != null ? ratingByEntry[e.id!] : null;
          enrichedHistory.add(
            ArchiveHistoryItem(
              drankAt: log.drankAt,
              quantityValue: e.quantityValue,
              quantityUnit: e.quantityUnit,
              rating: r,
              place: log.place,
            ),
          );
        }
      }
      history
        ..clear()
        ..addAll(enrichedHistory);
    }
  }

  history.sort((a, b) => b.drankAt.compareTo(a.drankAt));

  return ArchiveDetailData(
    master: master,
    totalRecords: matchedLogs.length,
    totalEntries: totalEntries,
    avgRating: avgRating,
    history: history,
  );
});

Future<void> toggleArchiveFavorite(
  WidgetRef ref,
  int masterId,
  bool current,
) async {
  await ref.read(liquorMasterRepoProvider).toggleFavorite(masterId, !current);
  ref.invalidate(archiveDetailProvider(masterId));
  ref.invalidate(archiveListProvider);
}

Future<void> addArchiveAlias(WidgetRef ref, int masterId, String alias) async {
  await ref.read(liquorMasterRepoProvider).addAlias(masterId, alias);
  ref.invalidate(archiveDetailProvider(masterId));
  ref.invalidate(archiveListProvider);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';

class Achievement {
  final String title;
  final String description;
  final bool unlocked;

  const Achievement({
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final logRepo = ref.watch(drinkLogRepoProvider);
  final noteRepo = ref.watch(tastingNoteRepoProvider);
  final logs = await logRepo.getAll();
  final entries = logs.expand((log) => log.entries).toList();
  final entryIds = entries.map((e) => e.id).whereType<int>().toList();
  final notes = await noteRepo.getByEntryIds(entryIds);

  final uniqueLiquors = <String>{};
  final categories = <String>{};
  for (final entry in entries) {
    if (entry.liquorMasterId != null) {
      uniqueLiquors.add('master:${entry.liquorMasterId}');
    } else if (entry.liquorNameRaw.trim().isNotEmpty) {
      uniqueLiquors.add('raw:${entry.liquorNameRaw.trim().toLowerCase()}');
    }
    categories.add(entry.liquorCategory);
  }

  return [
    Achievement(
      title: '첫 기록',
      description: '음주 기록 1개 저장',
      unlocked: logs.isNotEmpty,
    ),
    Achievement(
      title: '꾸준한 기록가',
      description: '음주 기록 10개 저장',
      unlocked: logs.length >= 10,
    ),
    Achievement(
      title: '탐험가',
      description: '서로 다른 술 10종 기록',
      unlocked: uniqueLiquors.length >= 10,
    ),
    Achievement(
      title: '넓은 취향',
      description: '주종 3개 이상 기록',
      unlocked: categories.length >= 3,
    ),
    Achievement(
      title: '테이스팅 메모리',
      description: '테이스팅 노트 3개 작성',
      unlocked: notes.length >= 3,
    ),
  ];
});

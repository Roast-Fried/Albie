import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/drink_log.dart';

final logListProvider =
    AsyncNotifierProvider<LogListViewModel, List<DrinkLog>>(
        LogListViewModel.new);

class LogListViewModel extends AsyncNotifier<List<DrinkLog>> {
  @override
  Future<List<DrinkLog>> build() async {
    final repo = ref.watch(drinkLogRepoProvider);
    return repo.getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(drinkLogRepoProvider).getAll());
  }

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      await refresh();
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(drinkLogRepoProvider).search(keyword));
  }

  Future<void> delete(int logId) async {
    await ref.read(drinkLogRepoProvider).delete(logId);
    await refresh();
  }
}

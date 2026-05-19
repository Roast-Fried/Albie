import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../domain/entities/drink_log.dart';
import '../domain/entities/liquor_master.dart';

final logDetailProvider = FutureProvider.family<DrinkLog?, int>((
  ref,
  logId,
) async {
  final repo = ref.watch(drinkLogRepoProvider);
  return repo.getById(logId);
});

final entryMasterProvider = FutureProvider.family<LiquorMaster?, int>((
  ref,
  masterId,
) async {
  return ref.watch(liquorMasterRepoProvider).getById(masterId);
});

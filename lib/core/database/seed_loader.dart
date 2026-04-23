import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/liquor_master.dart';

class SeedLoader {
  SeedLoader._();

  static Future<void> loadLiquorMaster(Database db) async {
    final jsonStr = await rootBundle.loadString('assets/seed/liquor_master.json');
    final list = jsonDecode(jsonStr) as List;
    if (list.isEmpty) return;

    final batch = db.batch();
    for (final item in list) {
      final master = LiquorMaster.fromSeedJson(item as Map<String, dynamic>);
      // replace로 시드 업데이트 반영 (isFavorite, isUserAdded는 toMap에 포함됨)
      batch.insert('liquorMaster', master.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}

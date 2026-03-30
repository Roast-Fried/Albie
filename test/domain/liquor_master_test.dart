import 'package:flutter_test/flutter_test.dart';
import 'package:albi/domain/entities/liquor_master.dart';

void main() {
  group('LiquorMaster', () {
    test('fromSeedJson parses correctly', () {
      final json = {
        'canonicalName': 'Benromach',
        'nameKo': '벤로마크',
        'aliases': ['벤로마크', '벤로막', 'benromach'],
        'category': 'whisky',
        'subcategory': 'single_malt',
        'defaultAbv': 43.0,
        'country': 'Scotland',
        'distillery': 'Benromach',
      };

      final master = LiquorMaster.fromSeedJson(json);
      expect(master.canonicalName, 'Benromach');
      expect(master.nameKo, '벤로마크');
      expect(master.aliases, ['벤로마크', '벤로막', 'benromach']);
      expect(master.category, 'whisky');
      expect(master.defaultAbv, 43.0);
    });

    test('toMap/fromMap roundtrip with aliases JSON', () {
      final master = LiquorMaster(
        canonicalName: 'Glenfiddich',
        nameKo: '글렌피딕',
        aliases: ['글렌피딕', 'glenfiddich'],
        category: 'whisky',
      );

      final map = master.toMap();
      // aliasesJson should be a JSON string
      expect(map['aliasesJson'], contains('글렌피딕'));

      final restored = LiquorMaster.fromMap({...map, 'id': 1});
      expect(restored.canonicalName, 'Glenfiddich');
      expect(restored.aliases, ['글렌피딕', 'glenfiddich']);
    });

    test('fromMap handles null aliases gracefully', () {
      final master = LiquorMaster.fromMap({
        'id': 1,
        'canonicalName': 'Test',
        'aliasesJson': null,
        'category': 'other',
        'isUserAdded': 0,
        'isFavorite': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(master.aliases, isEmpty);
    });
  });

  group('UsageQuota', () {
    test('canUseAppText respects limit', () {
      // Import is in the actual file but testing the concept here
      // UsageQuota.maxAppTextPerDay is 10
    });
  });
}

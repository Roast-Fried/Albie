import 'dart:convert';

import 'package:albi/domain/entities/drink_log.dart';
import 'package:albi/integrations/supabase/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backup_codec — encode/decode round-trip', () {
    test('로그(항목+음식)가 JSON 직렬화 후 동일하게 복원된다', () {
      final logs = [
        DrinkLog(
          rawInputText: '글렌피딕 12 두 잔이랑 치즈',
          parseSource: 'local_parser',
          place: '집',
          overallMemo: '좋았음',
          drankAt: DateTime(2026, 5, 12, 20, 30),
          foodItems: const ['치즈', '견과'],
          entries: [
            DrinkEntry(
              liquorNameRaw: '글렌피딕 12',
              liquorCategory: 'whisky',
              ageStatement: '12년',
              quantityValue: 2,
              quantityUnit: 'glass',
              isEstimated: false,
              alcoholPercent: 40,
            ),
          ],
        ),
      ];

      // 실제 네트워크 경로처럼 JSON 문자열까지 왕복(jsonb 직렬화 모사).
      final encoded = jsonDecode(jsonEncode(encodeBackup(logs)))
          as Map<String, dynamic>;
      final decoded = decodeBackup(encoded);

      expect(decoded.length, 1);
      final log = decoded.first;
      expect(log.id, isNull); // 복원은 신규 id
      expect(log.rawInputText, '글렌피딕 12 두 잔이랑 치즈');
      expect(log.place, '집');
      expect(log.overallMemo, '좋았음');
      expect(log.parseSource, 'local_parser');
      expect(log.drankAt, DateTime(2026, 5, 12, 20, 30));
      expect(log.foodItems, ['치즈', '견과']);
      expect(log.entries.length, 1);
      final e = log.entries.first;
      expect(e.liquorNameRaw, '글렌피딕 12');
      expect(e.liquorCategory, 'whisky');
      expect(e.ageStatement, '12년');
      expect(e.quantityValue, 2);
      expect(e.quantityUnit, 'glass');
      expect(e.isEstimated, false);
      expect(e.alcoholPercent, 40);
    });

    test('빈 로그 리스트도 안전하게 왕복', () {
      final encoded = encodeBackup(const []);
      expect(encoded['version'], backupSchemaVersion);
      expect(encoded['logCount'], 0);
      expect(decodeBackup(encoded), isEmpty);
    });

    test('nullable 필드(장소/메모/도수) 누락도 기본값으로 복원', () {
      final logs = [DrinkLog(drankAt: DateTime(2026, 1, 1))];
      final decoded =
          decodeBackup(jsonDecode(jsonEncode(encodeBackup(logs))));
      expect(decoded.first.place, isNull);
      expect(decoded.first.overallMemo, isNull);
      expect(decoded.first.entries, isEmpty);
      expect(decoded.first.foodItems, isEmpty);
    });
  });
}

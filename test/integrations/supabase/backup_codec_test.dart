import 'dart:convert';

import 'package:albi/core/exceptions.dart';
import 'package:albi/domain/entities/drink_log.dart';
import 'package:albi/domain/entities/tasting_note.dart';
import 'package:albi/integrations/supabase/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backup_codec — encode/decode round-trip', () {
    test('로그+항목+음식+마스터키+테이스팅노트가 JSON 왕복 후 보존된다', () {
      final backups = [
        LogBackup(
          log: DrinkLog(
            rawInputText: '글렌피딕 12 두 잔이랑 치즈',
            parseSource: 'local_parser',
            place: '집',
            overallMemo: '좋았음',
            drankAt: DateTime(2026, 5, 12, 20, 30),
            foodItems: const ['치즈', '견과'],
          ),
          entries: [
            EntryBackup(
              entry: DrinkEntry(
                liquorMasterId: 7, // 백업엔 저장 안 됨(재매칭용 canonical 사용)
                liquorNameRaw: '글렌피딕 12',
                liquorCategory: 'whisky',
                ageStatement: '12년',
                quantityValue: 2,
                quantityUnit: 'glass',
                isEstimated: false,
                alcoholPercent: 40,
              ),
              masterCanonical: 'Glenfiddich 12',
              note: TastingNote(
                entryId: 99,
                nose: '배',
                palate: '꿀',
                finish: '길게',
                rating: 4.5,
                note: '맛있다',
              ),
            ),
          ],
        ),
      ];

      // 실제 jsonb 경로처럼 문자열까지 왕복.
      final encoded =
          jsonDecode(jsonEncode(encodeBackup(backups))) as Map<String, dynamic>;
      final decoded = decodeBackup(encoded);

      expect(decoded.length, 1);
      final b = decoded.first;
      expect(b.log.id, isNull); // 복원은 신규 id
      expect(b.log.place, '집');
      expect(b.log.foodItems, ['치즈', '견과']);
      expect(b.entries.length, 1);

      final eb = b.entries.first;
      expect(eb.entry.liquorMasterId, isNull); // 복원 시 canonical 로 재매칭
      expect(eb.masterCanonical, 'Glenfiddich 12');
      expect(eb.entry.liquorNameRaw, '글렌피딕 12');
      expect(eb.entry.quantityValue, 2);
      expect(eb.entry.alcoholPercent, 40);
      expect(eb.note, isNotNull);
      expect(eb.note!.nose, '배');
      expect(eb.note!.rating, 4.5);
    });

    test('빈 리스트도 안전하게 왕복', () {
      final encoded = encodeBackup(const []);
      expect(encoded['version'], backupSchemaVersion);
      expect(encoded['logCount'], 0);
      expect(decodeBackup(encoded), isEmpty);
    });

    test('테이스팅노트/마스터키 없는 항목도 정상 왕복', () {
      final backups = [
        LogBackup(
          log: DrinkLog(drankAt: DateTime(2026, 1, 1)),
          entries: [EntryBackup(entry: DrinkEntry(liquorNameRaw: '소주'))],
        ),
      ];
      final decoded = decodeBackup(jsonDecode(jsonEncode(encodeBackup(backups))));
      expect(decoded.first.entries.first.note, isNull);
      expect(decoded.first.entries.first.masterCanonical, isNull);
    });
  });

  group('backup_codec — 손상/구버전 payload 방어', () {
    test('지원보다 높은 version → ValidationError', () {
      expect(
        () => decodeBackup({'version': backupSchemaVersion + 1, 'logs': []}),
        throwsA(isA<ValidationError>()),
      );
    });

    test('version 누락 → ValidationError', () {
      expect(
        () => decodeBackup({'logs': []}),
        throwsA(isA<ValidationError>()),
      );
    });

    test('logs 가 List 아님 → ValidationError', () {
      expect(
        () => decodeBackup({'version': 1, 'logs': 'nope'}),
        throwsA(isA<ValidationError>()),
      );
    });
  });
}

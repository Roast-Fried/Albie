import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:albi/data/liquor_master_repository.dart';
import 'package:albi/integrations/parser/local_rule_parser.dart';
import 'package:albi/integrations/parser/parse_result.dart';

/// LocalRuleParser 회귀 테스트 — boundary case 4종 (fixed behaviour lock).
///
/// 2026-05-18: 초기 버전은 현재(buggy) 동작을 lock.
/// 2026-05-18: Bug A/B/C/D fix 적용 후 fixed 동작으로 테스트 갱신.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalRuleParser parser;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE liquorMaster (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            canonicalName TEXT NOT NULL UNIQUE,
            nameKo TEXT,
            aliasesJson TEXT NOT NULL DEFAULT '[]',
            category TEXT NOT NULL DEFAULT 'other',
            subcategory TEXT,
            defaultAbv REAL,
            country TEXT,
            distillery TEXT,
            isUserAdded INTEGER NOT NULL DEFAULT 0,
            isFavorite INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
    final repo = LiquorMasterRepository(db);
    parser = LocalRuleParser(repo, sixHourCutoffEnabled: false);
  });

  group('LocalRuleParser — 다중 음주 분리 (접속사 의존성)', () {
    test('접속사 이랑 이 있으면 segment 2개로 분리된다', () async {
      final result = await parser.parse(
        ParseInput(text: '소주 한 잔이랑 맥주 두 캔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.length, 2, reason: '접속사로 분리된 세그먼트는 별도 entry 가 되어야 함');
      final categories = result.entries.map((e) => e.liquorCategory).toSet();
      expect(categories, containsAll(['soju', 'beer']));
    });

    // Bug A fixed: 접속사 없어도 카테고리 키워드 2회 + 수량 패턴 시 분리
    test('접속사 없어도 카테고리 키워드 2회 등장 시 분리된다', () async {
      final result = await parser.parse(
        ParseInput(text: '소주 2병 맥주 3잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.length, 2,
          reason: 'Bug A fix: 카테고리 키워드 2회 + 수량 패턴으로 분리');
    });
  });

  group('LocalRuleParser — ml 수량 패턴', () {
    test('정수 ml 은 정상 인식한다', () async {
      final result = await parser.parse(
        ParseInput(text: '와인 200ml', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.length, 1);
      final entry = result.entries.first;
      expect(entry.quantityUnit, 'ml');
      expect(entry.quantityValue, 200.0);
    });

    // Bug B fixed: 소수점 ml 정상 인식
    test('소수점 ml (187.5ml) 도 정상 인식한다', () async {
      final result = await parser.parse(
        ParseInput(text: '와인 187.5ml', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.length, 1);
      final entry = result.entries.first;
      expect(entry.quantityUnit, 'ml');
      expect(entry.quantityValue, 187.5,
          reason: 'Bug B fix: 소수점 ml 패턴 (\\d+(?:\\.\\d+)?) 으로 정상 파싱');
    });
  });

  group('LocalRuleParser — 음식 부분 매칭 오탐', () {
    // Bug C fixed: 회사 → 회 오탐 방지
    test('"회사" 입력은 음식 "회" 로 오탐 안 한다', () async {
      final result = await parser.parse(
        ParseInput(text: '회사에서 맥주 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.foodItems, isNot(contains('회')),
          reason: 'Bug C fix: 단어 경계 RegExp 로 부분 매칭 오탐 방지');
    });

    test('실제 음식 단어는 정상 매칭된다 (positive control)', () async {
      final result = await parser.parse(
        ParseInput(text: '치즈랑 와인 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.foodItems, contains('치즈'));
    });
  });

  group('LocalRuleParser — 장소 ~에서 패턴 경계', () {
    // Bug D fixed: 술 카테고리 키워드는 장소로 채택 안 함
    test('술 카테고리 키워드 + 에서 는 장소로 채택 안 된다', () async {
      final result = await parser.parse(
        ParseInput(text: '소주에서 3잔 마셨음', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.place, isNull,
          reason: 'Bug D fix: 술 카테고리 키워드(소주)는 _drinkCategoryKeywords 로 장소 후보에서 제외');
    });

    // Bug D fixed: 길이 1 단어도 장소 후보 제외
    test('짧은(길이 1) 토큰 + 에서 는 장소로 채택 안 된다', () async {
      final result = await parser.parse(
        ParseInput(text: '저에서 마신 맥주', inputTime: DateTime(2026, 5, 18)),
      );

      // 저 는 길이 1 → place == null
      expect(result.place, isNull,
          reason: 'Bug D fix: candidate.length < 2 인 경우 장소 후보 제외');
    });

    // 아무거나에서: 길이 4, 술 카테고리 아님 → place 채택 (허용 케이스)
    test('일반 토큰 + 에서 는 장소로 채택된다', () async {
      final result = await parser.parse(
        ParseInput(text: '아무거나에서 한 잔 마셨음', inputTime: DateTime(2026, 5, 18)),
      );

      // 아무거나: 길이 4, 술 카테고리 아님 → 장소로 채택 (~에서 fallback)
      expect(result.place, '아무거나');
    });
  });

  group('LocalRuleParser — Bug A 복합 명사 false positive 방어', () {
    // Codex 2026-05-18 최종 audit: 복합 장소명은 split 대상이 아니어야 함.
    // Bug A fix 의 false-positive guard (drink keyword 뒤 한글 char 면 skip)
    // 가 정확히 동작하는지 명시 회귀.
    test('"맥주집" 은 카테고리 분리 trigger 아님', () async {
      final result = await parser.parse(
        ParseInput(text: '맥주집에서 와인 한 잔', inputTime: DateTime(2026, 5, 18)),
      );
      // "맥주" 뒤에 "집" (한글) → false positive guard 발동 → 분리 안 됨
      expect(result.entries.length, 1,
          reason: '복합 명사 "맥주집" 은 drink keyword split 대상 아님');
    });

    test('"와인바" 도 분리 trigger 아님', () async {
      final result = await parser.parse(
        ParseInput(text: '와인바에서 위스키 두 샷', inputTime: DateTime(2026, 5, 18)),
      );
      expect(result.entries.length, 1,
          reason: '복합 명사 "와인바" 도 분리 대상 아님');
    });
  });
}

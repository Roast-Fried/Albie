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

  group('LocalRuleParser — qtyPattern 통일 (Codex C2 fix, 2026-05-26)', () {
    // 2026-05-26 /goal HIGH 1: _splitByDrinkKeyword 의 qtyPattern 이 _extractQuantity
    // 와 동일 한글 수량어 범위 (한~열두, 반) 를 cover 하는지 회귀 lock.
    test('"소주 두 잔 맥주 네 잔" 도 분리된다 (네 잔은 기존 qtyPattern 누락 케이스)',
        () async {
      final result = await parser.parse(
        ParseInput(text: '소주 두 잔 맥주 네 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.length, 2,
          reason: 'qtyPattern 통일: "네 잔" 도 split trigger 로 인정');
      final categories = result.entries.map((e) => e.liquorCategory).toSet();
      expect(categories, containsAll(['soju', 'beer']));
    });

    test('"와인 반 병 위스키 한 잔" 도 분리된다 (반 병 케이스)', () async {
      final result = await parser.parse(
        ParseInput(text: '와인 반 병 위스키 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.length, 2,
          reason: 'qtyPattern 통일: "반 병" 도 split trigger 로 인정');
    });

    test('"막걸리 다섯 잔 맥주 두 캔" 다섯/두 수량어 분리', () async {
      final result = await parser.parse(
        ParseInput(
            text: '막걸리 다섯 잔 맥주 두 캔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.length, 2,
          reason: 'qtyPattern 통일: 다섯 / 여섯 / .. / 열두 도 인정');
    });
  });

  group('LocalRuleParser — 명시 도수 파싱 (Codex C1 fix, 2026-05-26)', () {
    // 2026-05-26 /goal HIGH 2: alcoholPercent 가 master defaultAbv 가 아니라
    // 입력 텍스트의 명시 도수(40%, 17도, 도수 43, abv 5.5)를 우선 채택하는지.
    test('"40%" 명시 도수가 alcoholPercent 로 반영된다', () async {
      final result = await parser.parse(
        ParseInput(text: '위스키 40% 두 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.length, 1);
      expect(result.entries.first.alcoholPercent, 40.0,
          reason: '명시 도수 % 패턴이 우선 반영');
    });

    test('"17도" 명시 도수가 반영된다', () async {
      final result = await parser.parse(
        ParseInput(text: '소주 17도 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.first.alcoholPercent, 17.0);
    });

    test('"도수 43" prefix 명시 도수가 반영된다', () async {
      final result = await parser.parse(
        ParseInput(text: '위스키 도수 43 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.first.alcoholPercent, 43.0);
    });

    test('"abv 5.5" 영문 prefix 명시 도수가 반영된다', () async {
      final result = await parser.parse(
        ParseInput(text: '맥주 abv 5.5 두 캔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.first.alcoholPercent, 5.5);
    });

    // Codex code-review Iteration 2 LOW: 0% / 0도 (무알콜) 인정
    test('"0%" 무알콜 명시 시 alcoholPercent == 0.0 (silent drop 금지)', () async {
      final result = await parser.parse(
        ParseInput(text: '논알콜 맥주 0% 한 캔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.first.alcoholPercent, 0.0,
          reason: 'Codex LOW fix: 명시 0% 는 무알콜 표기로 인정 (v >= 0)');
    });

    test('"0도" 무알콜 명시 시 alcoholPercent == 0.0', () async {
      final result = await parser.parse(
        ParseInput(text: '맥주 0도 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.first.alcoholPercent, 0.0);
    });

    test('명시 도수가 범위 밖(>96)이면 무시되고 fallback', () async {
      final result = await parser.parse(
        ParseInput(text: '맥주 200% 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      // 200% 는 비현실 → null, master 매칭 없으므로 결과는 null
      expect(result.entries.first.alcoholPercent, isNull,
          reason: 'abv 96 초과 시 명시 값 거부 + master 매칭 없으면 null');
    });

    // Codex final sanity F1 (2026-05-26 MEDIUM BUG): 명시 도수 숫자는 age 가 아님
    test('"위스키 40%" 입력 시 ageStatement 는 null (40 은 abv 이지 age 아님)', () async {
      final result = await parser.parse(
        ParseInput(text: '위스키 40% 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.first.ageStatement, isNull,
          reason: 'F1 fix: 40% 의 40 은 abv 패턴 — age 추출 skip');
      expect(result.entries.first.alcoholPercent, 40.0);
    });

    test('"소주 17도" 입력 시 ageStatement 는 null', () async {
      final result = await parser.parse(
        ParseInput(text: '소주 17도 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.first.ageStatement, isNull,
          reason: 'F1 fix: 17도 의 17 은 abv suffix — age 추출 skip');
      expect(result.entries.first.alcoholPercent, 17.0);
    });

    test('"도수 43 위스키" prefix 도 age 로 오인되지 않음', () async {
      final result = await parser.parse(
        ParseInput(text: '도수 43 위스키 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      expect(result.entries.first.ageStatement, isNull);
      expect(result.entries.first.alcoholPercent, 43.0);
    });

    test('"벤로막 15년 한 잔" 의 15년 은 정상 age 추출 (regression guard)',
        () async {
      final result = await parser.parse(
        ParseInput(text: '벤로막 15년 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      // F1 fix 후에도 명시 "15년" age 는 그대로 추출되어야 함
      expect(result.entries.first.ageStatement, '15년',
          reason: 'F1 fix 가 정상 age 추출을 망가뜨리면 안 됨');
    });

    test('"15년" age statement 는 alcoholPercent 로 오인되지 않음', () async {
      final result = await parser.parse(
        ParseInput(text: '벤로막 15년 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      // 15년 은 age statement, abv 가 아님 — "도수" / "%" 패턴 매칭 안 됨
      expect(result.entries.first.ageStatement, '15년');
      // alcoholPercent 는 master 매칭이 있으면 defaultAbv, 없으면 null
    });

    // Codex audit 권고 1: false positive negative control 3 케이스 보강.
    test('"도수가 좋은 위스키" prefix false positive 아님', () async {
      final result = await parser.parse(
        ParseInput(
            text: '도수가 좋은 위스키 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      // "도수가" 는 도수 + 가 (조사) — 숫자 prefix 패턴 매칭 안 됨
      expect(result.entries.first.alcoholPercent, isNull,
          reason: '"도수가" 는 [:=]?\\s*(\\d+) 미매칭');
    });

    test('"어제 5시에 마셨음" 시간 숫자 false positive 아님', () async {
      final result = await parser.parse(
        ParseInput(
            text: '어제 5시에 맥주 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      // "5시" 의 5 는 abv 패턴 미매칭 (% / 도 / 도수 prefix / abv prefix 어느 것도 매칭 안 됨)
      // master 매칭이 있으면 defaultAbv 사용 — alcoholPercent 가 5.0 이 아니어야 함
      expect(result.entries.first.alcoholPercent, isNot(5.0),
          reason: '"5시" 의 숫자 5 는 abv 로 오인되면 안 됨');
    });

    test('"15년산 위스키" 의 15년산 도 abv 로 오인되지 않음', () async {
      final result = await parser.parse(
        ParseInput(
            text: '15년산 위스키 한 잔', inputTime: DateTime(2026, 5, 18)),
      );

      // "15년산" 의 15 는 negative lookahead `(?![수가년])` 로 차단
      expect(result.entries.first.alcoholPercent, isNot(15.0),
          reason: '"15년" 은 abv 로 오인되면 안 됨 (도 패턴 negative lookahead)');
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

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:albi/data/ai_config_repository.dart';

/// AI quota — 2026-05-26 app_default 제거 후 user_provided 만 동작.
/// `incrementUserText/Image` 및 `getQuotaToday` 회귀.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> openTestDb() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE aiConfig (
            id INTEGER PRIMARY KEY,
            isEnabled INTEGER NOT NULL DEFAULT 0,
            keyMode TEXT NOT NULL DEFAULT 'none',
            selectedModel TEXT NOT NULL DEFAULT 'gemini-2.0-flash',
            lastValidatedAt TEXT,
            lastErrorMessage TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE usageQuota (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dayKey TEXT NOT NULL UNIQUE,
            appDefaultTextCount INTEGER NOT NULL DEFAULT 0,
            appDefaultImageCount INTEGER NOT NULL DEFAULT 0,
            userKeyTextCount INTEGER NOT NULL DEFAULT 0,
            userKeyImageCount INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  group('incrementUserText/Image — user_provided 사용량 +1', () {
    test('incrementUserText 호출 시 userKeyTextCount 가 1 증가', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        await repo.incrementUserText();
        final quota = await repo.getQuotaToday();
        expect(quota.userKeyTextCount, 1);
        expect(quota.appDefaultTextCount, 0,
            reason: 'app_default 분기 제거 — appDefault 카운트는 절대 증가 안 함');
      } finally {
        await db.close();
      }
    });

    test('incrementUserImage 호출 시 userKeyImageCount 가 1 증가', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        await repo.incrementUserImage();
        final quota = await repo.getQuotaToday();
        expect(quota.userKeyImageCount, 1);
        expect(quota.appDefaultImageCount, 0);
      } finally {
        await db.close();
      }
    });

    test('연속 호출 시 누적 — user 키는 한도 없음 (자체 Gemini 할당량 내)', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        for (var i = 0; i < 25; i++) {
          await repo.incrementUserText();
        }
        final quota = await repo.getQuotaToday();
        expect(quota.userKeyTextCount, 25,
            reason: 'user_provided 는 앱 한도 없음 — 누적 모두 기록');
      } finally {
        await db.close();
      }
    });
  });

  group('getQuotaToday — 오늘 quota 행 보장', () {
    test('최초 호출 시 INSERT OR IGNORE 로 0-row 생성', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        final quota = await repo.getQuotaToday();
        expect(quota.userKeyTextCount, 0);
        expect(quota.userKeyImageCount, 0);
      } finally {
        await db.close();
      }
    });
  });
}

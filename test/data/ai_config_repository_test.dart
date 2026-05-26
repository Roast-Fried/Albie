import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:albi/data/ai_config_repository.dart';
import 'package:albi/domain/entities/usage_quota.dart';

/// AI quota atomic reserve 회귀 (Codex C4 fix, 2026-05-26).
///
/// 기존 패턴 (check → API → increment 별도 transaction) 은 병렬 호출 race 가능.
/// 본 테스트는 reserveAppText / reserveAppImage 가 단일 UPDATE 로 한도 초과를
/// 막는지 검증.
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
            keyMode TEXT NOT NULL DEFAULT 'disabled',
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

  group('reserveAppText — atomic check + increment', () {
    test('한도 미달이면 reserve 성공 (true) + count 가 1 증가', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        final reserved = await repo.reserveAppText();
        expect(reserved, isTrue);

        final quota = await repo.getQuotaToday();
        expect(quota.appDefaultTextCount, 1);
      } finally {
        await db.close();
      }
    });

    test('연속 10회 reserve 시 11번째는 한도 초과로 실패 (count 그대로)', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        for (var i = 0; i < UsageQuota.maxAppTextPerDay; i++) {
          final ok = await repo.reserveAppText();
          expect(ok, isTrue, reason: 'iteration ${i + 1}: 한도 미달이면 reserve 성공');
        }
        // 11번째 — 한도 초과
        final overflow = await repo.reserveAppText();
        expect(overflow, isFalse, reason: '한도 초과 시 reserve 실패 (false)');

        // count 는 한도까지만 증가 (overflow 시 변경 없음)
        final quota = await repo.getQuotaToday();
        expect(quota.appDefaultTextCount, UsageQuota.maxAppTextPerDay);
      } finally {
        await db.close();
      }
    });

    test('병렬 호출 시 총 reserve 성공 횟수 == 한도 (race-free)', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        // 한도 보다 많은 병렬 호출 (한도 10, 20개 동시)
        final futures = List.generate(20, (_) => repo.reserveAppText());
        final results = await Future.wait(futures);
        final successCount = results.where((r) => r).length;

        expect(successCount, UsageQuota.maxAppTextPerDay,
            reason: 'atomic UPDATE WHERE count<limit 로 race 차단 — '
                '총 성공 == 한도');

        final quota = await repo.getQuotaToday();
        expect(quota.appDefaultTextCount, UsageQuota.maxAppTextPerDay);
      } finally {
        await db.close();
      }
    });
  });

  group('reserveAppImage — atomic check + increment', () {
    test('연속 3회 reserve 후 4번째 한도 초과', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        for (var i = 0; i < UsageQuota.maxAppImagePerDay; i++) {
          expect(await repo.reserveAppImage(), isTrue);
        }
        expect(await repo.reserveAppImage(), isFalse);

        final quota = await repo.getQuotaToday();
        expect(quota.appDefaultImageCount, UsageQuota.maxAppImagePerDay);
      } finally {
        await db.close();
      }
    });
  });

  // Codex F2 fix (2026-05-26): 취소 시 quota rollback 회귀.
  group('decrementAppText/Image — rollback on cancel', () {
    test('reserve 후 decrement 하면 count 가 0 으로 복귀', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        expect(await repo.reserveAppText(), isTrue);
        var quota = await repo.getQuotaToday();
        expect(quota.appDefaultTextCount, 1);

        await repo.decrementAppText();
        quota = await repo.getQuotaToday();
        expect(quota.appDefaultTextCount, 0,
            reason: 'F2 fix: 취소 시 reserve 환원 → 0 으로 복귀');
      } finally {
        await db.close();
      }
    });

    test('count == 0 에서 decrement 호출 시 underflow 없이 0 유지', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        // reserve 없이 decrement 호출 (잘못된 사용)
        await repo.decrementAppText();
        final quota = await repo.getQuotaToday();
        expect(quota.appDefaultTextCount, 0,
            reason: 'WHERE count > 0 가드로 underflow 방지 (clamp at 0)');
      } finally {
        await db.close();
      }
    });

    test('decrementAppImage 도 동일하게 동작', () async {
      final db = await openTestDb();
      try {
        final repo = AiConfigRepository(db);
        expect(await repo.reserveAppImage(), isTrue);
        await repo.decrementAppImage();
        final quota = await repo.getQuotaToday();
        expect(quota.appDefaultImageCount, 0);
      } finally {
        await db.close();
      }
    });
  });
}

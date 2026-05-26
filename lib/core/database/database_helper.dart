import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'seed_loader.dart';

class DatabaseHelper {
  static Database? _db;
  static const _dbName = 'albi.db';
  static const _dbVersion = 2;

  DatabaseHelper._();
  static final instance = DatabaseHelper._();

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE drinkLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rawInputText TEXT,
        rawImagePath TEXT,
        parseSource TEXT NOT NULL DEFAULT 'manual',
        place TEXT,
        overallMemo TEXT,
        drankAt TEXT NOT NULL,
        userConfirmedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE drinkEntry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        logId INTEGER NOT NULL REFERENCES drinkLog(id) ON DELETE CASCADE,
        liquorMasterId INTEGER REFERENCES liquorMaster(id),
        liquorNameRaw TEXT NOT NULL,
        liquorCategory TEXT NOT NULL DEFAULT 'other',
        ageStatement TEXT,
        quantityValue REAL NOT NULL DEFAULT 1.0,
        quantityUnit TEXT NOT NULL DEFAULT 'glass',
        isEstimated INTEGER NOT NULL DEFAULT 1,
        alcoholPercent REAL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE drinkLogFood (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        logId INTEGER NOT NULL REFERENCES drinkLog(id) ON DELETE CASCADE,
        foodName TEXT NOT NULL
      )
    ''');

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

    await db.execute('''
      CREATE TABLE tastingNote (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entryId INTEGER NOT NULL UNIQUE REFERENCES drinkEntry(id) ON DELETE CASCADE,
        nose TEXT,
        palate TEXT,
        finish TEXT,
        rating REAL,
        note TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE parseJob (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        logId INTEGER REFERENCES drinkLog(id) ON DELETE SET NULL,
        sourceType TEXT NOT NULL,
        parserUsed TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'success',
        rawRequest TEXT,
        rawResponse TEXT,
        errorCode TEXT,
        errorMessage TEXT,
        durationMs INTEGER,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE aiConfig (
        id INTEGER PRIMARY KEY DEFAULT 1,
        provider TEXT NOT NULL DEFAULT 'gemini',
        keyMode TEXT NOT NULL DEFAULT 'none',
        selectedModel TEXT NOT NULL DEFAULT 'gemini-2.5-flash-lite',
        isEnabled INTEGER NOT NULL DEFAULT 0,
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

    // 인덱스
    await db.execute(
        'CREATE INDEX idx_drinkEntry_logId ON drinkEntry(logId)');
    await db.execute(
        'CREATE INDEX idx_drinkLogFood_logId ON drinkLogFood(logId)');
    await db.execute(
        'CREATE INDEX idx_drinkLog_drankAt ON drinkLog(drankAt)');
    await db.execute(
        'CREATE INDEX idx_parseJob_logId ON parseJob(logId)');
    await db.execute(
        'CREATE INDEX idx_liquorMaster_category ON liquorMaster(category)');
    await db.execute(
        'CREATE INDEX idx_liquorMaster_nameKo ON liquorMaster(nameKo)');
    await db.execute(
        'CREATE INDEX idx_parseJob_createdAt ON parseJob(createdAt)');

    // 기본 AI 설정 삽입 (2026-05-26: app_default 제거 — 사용자가 자신의 API 키 발급 후 enable)
    await db.insert('aiConfig', {
      'id': 1,
      'provider': 'gemini',
      'keyMode': 'none',
      'selectedModel': 'gemini-2.5-flash-lite',
      'isEnabled': 0,
    });

    // 시드 데이터 적재
    await SeedLoader.loadLiquorMaster(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_liquorMaster_category ON liquorMaster(category)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_liquorMaster_nameKo ON liquorMaster(nameKo)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_parseJob_createdAt ON parseJob(createdAt)');
    }
  }
}

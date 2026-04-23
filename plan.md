# Plan: Albi 전체 개선사항 수정
> 날짜: 2026-03-30
> 상태: 완료
> 마감: 2026-05-10

## 목표

78건의 개선사항(CRITICAL 15 / HIGH 23 / MEDIUM 28 / LOW 12)을 4개 Phase로 나누어 체계적으로 수정한다.
각 Phase는 독립적으로 커밋 가능하며, 이전 Phase에 의존한다.

## 접근법

**Bottom-up 레이어 수정** — 하위 레이어(DB/Repository)부터 수정하고 상위(ViewModel → View)로 전파.
이유: View 수정은 ViewModel 인터페이스에 의존하므로, ViewModel을 먼저 안정화해야 View 수정이 깨끗하다.

---

## Phase 1: CRITICAL — 크래시 방지 + 데이터 무결성 (15건)

### 1-1. Provider 초기화 안전성 (C1)

**파일**: `lib/core/providers.dart`
**변경**: 5개 Repository Provider를 FutureProvider로 전환

```dart
// Before (크래시 위험)
final drinkLogRepoProvider = Provider<DrinkLogRepository>((ref) {
  final db = ref.watch(databaseProvider).value;
  if (db == null) throw StateError('Database not ready');
  return DrinkLogRepository(db);
});

// After (안전)
final drinkLogRepoProvider = FutureProvider<DrinkLogRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return DrinkLogRepository(db);
});
```

> **영향 범위**: Repository를 사용하는 모든 파일에서 `.value` → `await .future` 또는 `.when()` 패턴 적용 필요.
> 연쇄 변경이 크므로 Phase 1 첫 번째로 실행.

**연쇄 변경 대상**:
- `lib/viewmodels/home_viewmodel.dart` — localParserProvider, orchestratorProvider
- `lib/viewmodels/log_list_viewmodel.dart` — drinkLogRepoProvider 접근
- `lib/viewmodels/archive_viewmodel.dart` — drinkLogRepoProvider + liquorMasterRepoProvider
- `lib/viewmodels/stats_viewmodel.dart` — drinkLogRepoProvider
- `lib/viewmodels/ai_settings_viewmodel.dart` — aiConfigRepoProvider
- `lib/views/draft_review/draft_review_screen.dart` — repo 접근 (Phase 1-2에서 ViewModel로 이동)
- `lib/views/log/log_detail_screen.dart` — repo 접근 (Phase 1-2에서 ViewModel로 이동)
- `lib/views/log/log_list_screen.dart` — repo 접근 (Phase 1-2에서 ViewModel로 이동)

### 1-2. View → ViewModel 비즈니스 로직 이동 (A1-A3)

**핵심 원칙**: View는 ViewModel 메서드 호출만, Repository 직접 접근 금지.

#### 1-2a. DraftReviewViewModel에 save() 추가

**파일**: `lib/viewmodels/draft_review_viewmodel.dart`

```dart
// 추가할 메서드
Future<SaveResult> save(Ref ref) async {
  final repo = await ref.read(drinkLogRepoProvider.future);
  final jobRepo = await ref.read(parseJobRepoProvider.future);
  final log = toSaveable();

  try {
    if (state.isEditing) {
      await repo.update(log.copyWith(id: state.editingLogId));
    } else {
      final logId = await repo.save(log);
      if (state.parseJobId != null) {
        await jobRepo.linkToLog(state.parseJobId!, logId);
      }
    }
    // 중앙화된 invalidation
    _invalidateLogProviders(ref);
    return SaveResult.success;
  } catch (e) {
    return SaveResult.failure(e.toString());
  }
}
```

**파일**: `lib/views/draft_review/draft_review_screen.dart` (lines 167-206)

```dart
// Before: 직접 repo 호출
final repo = ref.read(drinkLogRepoProvider);
await repo.save(log);

// After: ViewModel에 위임
final result = await ref.read(draftReviewProvider.notifier).save(ref);
if (result.isSuccess && context.mounted) Navigator.of(context).pop();
```

#### 1-2b. LogDetailScreen 삭제 로직 → ViewModel

**파일**: `lib/viewmodels/log_list_viewmodel.dart` (delete 메서드 추가)

```dart
Future<bool> deleteLog(int logId) async {
  try {
    final repo = ref.read(drinkLogRepoProvider).value!;
    await repo.delete(logId);
    _invalidateLogProviders(ref);
    return true;
  } catch (e) {
    return false;
  }
}
```

**파일**: `lib/views/log/log_detail_screen.dart` (lines 204-228) — `_delete()` 수정
**파일**: `lib/views/log/log_list_screen.dart` (lines 89-108) — `_confirmDelete()` 수정

#### 1-2c. Provider Invalidation 중앙화

**파일**: `lib/core/providers.dart` (하단에 헬퍼 추가)

```dart
void invalidateLogProviders(Ref ref) {
  ref.invalidate(recentLogsProvider);
  ref.invalidate(logCountProvider);
  ref.invalidate(logListProvider);
}
```

### 1-3. Repository 에러 핸들링 (B1-B4)

**파일**: `lib/data/drink_log_repository.dart`

```dart
// Before
Future<int> save(DrinkLog log) async {
  return _db.transaction((txn) async { ... });
}

// After
Future<int> save(DrinkLog log) async {
  try {
    return await _db.transaction((txn) async { ... });
  } on DatabaseException catch (e) {
    throw RepositoryException('음주 기록 저장 실패', cause: e);
  }
}
```

**신규 파일**: `lib/core/exceptions.dart`

```dart
class RepositoryException implements Exception {
  final String message;
  final Object? cause;
  const RepositoryException(this.message, {this.cause});
  @override
  String toString() => message;
}
```

동일 패턴을 `update()`, `delete()`, `getById()`에도 적용.

### 1-4. N+1 쿼리 해소 (D1-D2)

**파일**: `lib/data/drink_log_repository.dart`

```dart
// Before: N+1
for (final row in rows) {
  final log = DrinkLog.fromMap(row);
  final entries = await _getEntries(log.id!);  // N 쿼리
  final foods = await _getFoods(log.id!);      // N 쿼리
}

// After: 배치 로딩
Future<List<DrinkLog>> getAll({int? limit, int? offset}) async {
  final rows = await _db.query('drinkLog',
      orderBy: 'drankAt DESC', limit: limit, offset: offset);
  if (rows.isEmpty) return [];

  final logIds = rows.map((r) => r['id'] as int).toList();
  final ph = List.filled(logIds.length, '?').join(',');

  final entriesRows = await _db.rawQuery(
    'SELECT * FROM drinkEntry WHERE logId IN ($ph) ORDER BY logId, id', logIds);
  final foodsRows = await _db.rawQuery(
    'SELECT * FROM drinkLogFood WHERE logId IN ($ph)', logIds);

  final entriesByLog = _groupBy(entriesRows, 'logId', DrinkEntry.fromMap);
  final foodsByLog = _groupByString(foodsRows, 'logId', 'foodName');

  return rows.map((row) {
    final log = DrinkLog.fromMap(row);
    return log.copyWith(
      entries: entriesByLog[log.id] ?? [],
      foodItems: foodsByLog[log.id] ?? [],
    );
  }).toList();
}
```

`search()` 메서드에도 동일 패턴 적용.

### 1-5. DB 마이그레이션 전략 (D3)

**파일**: `lib/core/database/database_helper.dart`

```dart
static const _dbVersion = 2; // 1 → 2

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // Phase 1에서 추가하는 인덱스
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_liquorMaster_category ON liquorMaster(category)');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_liquorMaster_nameKo ON liquorMaster(nameKo)');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_parseJob_createdAt ON parseJob(createdAt)');
  }
  // 향후 버전별 마이그레이션 체인 추가
}
```

### 1-6. Golden 테스트 자동 업데이트 비활성화 (F2)

**파일**: `test/golden/golden_helper.dart`

```dart
// Before
autoUpdateGoldenFiles = true;

// After
// autoUpdateGoldenFiles는 CI에서 false, 로컬 갱신 시만 환경변수로 활성화
autoUpdateGoldenFiles = Platform.environment['UPDATE_GOLDENS'] == 'true';
```

---

## Phase 2: HIGH — 아키텍처 정비 + 에러 처리 강화 (23건)

### 2-1. 구조화된 에러 타입 도입 (B17)

**신규 파일**: `lib/core/exceptions.dart` (Phase 1에서 생성한 파일 확장)

```dart
sealed class AppError {
  final String userMessage;
  final Object? cause;
  const AppError(this.userMessage, {this.cause});
}

class NetworkError extends AppError {
  final int? statusCode;
  const NetworkError(super.userMessage, {super.cause, this.statusCode});
}

class DatabaseError extends AppError {
  const DatabaseError(super.userMessage, {super.cause});
}

class ParseError extends AppError {
  const ParseError(super.userMessage, {super.cause});
}

class ValidationError extends AppError {
  const ValidationError(super.userMessage, {super.cause});
}
```

### 2-2. Bare Catch 제거 (B5-B8)

| 파일 | 위치 | Before | After |
|------|------|--------|-------|
| gemini_client.dart:67 | validateKey | `catch (_) { return false; }` | `on DioException catch (e) { ... }` |
| liquor_master_repository.dart:58-64 | findByAlias | `catch (_) {}` | `on FormatException catch (e) { debugPrint(...); }` |
| local_rule_parser.dart:401-411 | _ensureDictsLoaded | `catch (_) { _foodDict = []; }` | `on FlutterError catch (e) { debugPrint(...); _foodDict = []; }` |
| gemini_text_parser.dart:70-74 | drankAt 파싱 | `catch (_) {}` | `on FormatException catch (e) { debugPrint(...); }` |

### 2-3. Force Unwrap 안전화 (B10-B12)

| 파일 | 위치 | Before | After |
|------|------|--------|-------|
| drink_log_repository.dart:97-98 | getAll loop | `log.id!` | `if (log.id == null) { continue; }` + `log.id` |
| local_rule_parser.dart:126+ | regex group | `m1.group(1)!` | `final raw = m1.group(1); if (raw == null) return null;` |
| ai_config_repository.dart:26-32 | rows.first | `rows.first` | `if (rows.isEmpty) throw ...;` |

### 2-4. ParseOrchestrator 에러 분류 (B9)

**파일**: `lib/integrations/parser/parse_orchestrator.dart`

```dart
// Before
} catch (e) {
  await _aiConfigRepo.update(
    (await _aiConfigRepo.get()).copyWith(lastErrorMessage: e.toString()));
  return null;
}

// After
} on DioException catch (e) {
  final msg = switch (e.response?.statusCode) {
    401 => 'API 키가 유효하지 않습니다',
    429 => 'API 할당량을 초과했습니다',
    _ => e.type == DioExceptionType.connectionTimeout
        ? '네트워크 연결 시간 초과'
        : 'AI 분석 실패: ${e.message}',
  };
  await _aiConfigRepo.update(
    (await _aiConfigRepo.get()).copyWith(lastErrorMessage: msg));
  return null;
} catch (e) {
  await _aiConfigRepo.update(
    (await _aiConfigRepo.get()).copyWith(lastErrorMessage: 'AI 분석 실패'));
  return null;
}
```

### 2-5. 크로스 도메인 import 제거 (A5-A7)

**원칙**: 각 View는 자기 도메인 ViewModel만 import. 공유 provider는 `core/providers.dart`에서 관리.

| 파일 | 제거할 import | 대체 |
|------|-------------|------|
| log_detail_screen.dart:6 | draft_review_viewmodel | DraftReviewState/DraftEntry를 별도 모델로 분리 또는 providers.dart 경유 |
| log_detail_screen.dart:7-8 | log_list_viewmodel, home_viewmodel | `invalidateLogProviders(ref)` 헬퍼 사용 (1-2c) |
| home_screen.dart:4 | draft_review_viewmodel | Navigation 시 ProviderScope override를 providers.dart의 factory 활용 |
| draft_review_screen.dart:6 | home_viewmodel | 제거 (미사용) |

### 2-6. Integration → Data 레이어 역전 해소 (A4)

**파일**: `lib/integrations/parser/parse_orchestrator.dart`
현재 이미 생성자 주입을 사용하므로 import만 정리. Provider 정의에서 주입하는 패턴은 유지.

```dart
// 현재: import '../../data/ai_config_repository.dart';
// → import는 유지하되, 향후 인터페이스 분리 시 domain/ 로 이동 가능한 구조 확인
// 이번 Phase에서는 import 경로가 아닌 DI 패턴이 올바른지 검증
```

> 인터페이스 분리는 현재 프로젝트 규모에서 오버엔지니어링이므로 비범위 처리.

### 2-7. ViewModel DI 개선 (A8)

**파일**: `lib/viewmodels/ai_settings_viewmodel.dart`

```dart
// Before
class AiSettingsViewModel extends AsyncNotifier<AiSettingsState> {
  static const _storage = FlutterSecureStorage();
  final _geminiClient = GeminiClient();

// After — Provider에서 주입
class AiSettingsViewModel extends AsyncNotifier<AiSettingsState> {
  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);
  GeminiClient get _geminiClient => ref.read(geminiClientProvider);
```

**파일**: `lib/core/providers.dart` 에 추가

```dart
final secureStorageProvider = Provider((_) => const FlutterSecureStorage());
final geminiClientProvider = Provider((_) => GeminiClient());
```

### 2-8. DB 쿼리 최적화 (D4-D7)

#### findByAlias 최적화

**파일**: `lib/data/liquor_master_repository.dart`

```dart
// Before: 전체 로딩 후 순회
final all = await _db.query('liquorMaster');

// After: 단계적 쿼리
Future<LiquorMaster?> findByAlias(String alias) async {
  final lower = alias.toLowerCase();

  // 1단계: canonicalName/nameKo 정확 매칭 (인덱스 활용)
  final exact = await _db.query('liquorMaster',
      where: 'LOWER(canonicalName) = ? OR LOWER(nameKo) = ?',
      whereArgs: [lower, lower]);
  if (exact.isNotEmpty) return LiquorMaster.fromMap(exact.first);

  // 2단계: aliasesJson 내 검색 (LIKE 활용, 범위 제한)
  final byAlias = await _db.query('liquorMaster',
      where: 'LOWER(aliasesJson) LIKE ?',
      whereArgs: ['%"$lower"%']);
  for (final row in byAlias) {
    final aliases = (jsonDecode(row['aliasesJson'] as String) as List).cast<String>();
    if (aliases.any((a) => a.toLowerCase() == lower)) {
      return LiquorMaster.fromMap(row);
    }
  }
  return null;
}
```

### 2-9. 에러 핸들링 누락 보강 (B13-B14)

각 ViewModel의 비동기 메서드에 try-catch 추가:
- `ai_settings_viewmodel.dart` — toggleEnabled, setKeyMode, saveKey
- `log_detail_screen.dart` — _delete (await + catch)

### 2-10. Invalidation 누락 수정 (C2)

**파일**: `lib/views/draft_review/draft_review_screen.dart` (또는 ViewModel로 이동한 save 메서드)

```dart
// Before: logListProvider 누락
ref.invalidate(recentLogsProvider);
ref.invalidate(logCountProvider);

// After: invalidateLogProviders 헬퍼 사용 (1-2c에서 정의)
invalidateLogProviders(ref);
```

### 2-11. 코드 중복 제거 (F4-F6)

**신규 파일**: `lib/core/utils/label_utils.dart`

```dart
String categoryLabel(String category) => switch (category) {
  'whisky' => '위스키', 'highball' => '하이볼', 'beer' => '맥주',
  'wine' => '와인', 'cocktail' => '칵테일', 'soju' => '소주',
  'makgeolli' => '막걸리', 'sake' => '사케', _ => '기타',
};

String unitLabel(String unit) => switch (unit) {
  'glass' => '잔', 'bottle' => '병', 'can' => '캔',
  'shot' => '샷', 'ml' => 'ml', _ => unit,
};
```

**공통 삭제 다이얼로그**: `lib/views/common/delete_confirm_dialog.dart`

```dart
Future<bool?> showDeleteConfirmDialog(BuildContext context, {String? message}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('기록 삭제'),
      content: Text(message ?? '이 기록을 삭제하시겠습니까?\n삭제하면 복구할 수 없습니다.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('삭제', style: TextStyle(color: Colors.red))),
      ],
    ),
  );
}
```

---

## Phase 3: MEDIUM — UX 개선 + 테스트 보강 (28건)

### 3-1. Provider 패턴 통일 (C3-C4)

- HomeViewModel: StateNotifierProvider → AsyncNotifierProvider로 마이그레이션
- DraftReviewViewModel: StateNotifierProvider 유지 (동기 초기화이므로 적합)
- AiSettingsState: copyWith 메서드 추가

### 3-2. UI 에러/빈 상태 개선 (E4, E8)

**신규 파일**: `lib/views/common/error_state_widget.dart`

```dart
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({required this.message, this.onRetry, super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center),
      if (onRetry != null) ...[
        const SizedBox(height: 16),
        FilledButton.tonal(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ]),
  );
}
```

5개 화면(archive, log_list, log_detail, stats, home)의 `.when(error:)` 패턴에 적용.

### 3-3. DraftReview 뒤로가기 확인 (E6)

```dart
// draft_review_screen.dart
PopScope(
  canPop: !_hasChanges,
  onPopInvokedWithResult: (didPop, _) async {
    if (didPop) return;
    final shouldLeave = await showDialog<bool>(...);
    if (shouldLeave == true && context.mounted) Navigator.of(context).pop();
  },
  child: Scaffold(...),
)
```

### 3-4. 폼 검증 (E10-E11)

EntryCardWidget의 quantity, ABV 필드에 범위 검증:

```dart
// quantity: 0 초과
onChanged: (text) {
  final val = double.tryParse(text);
  if (val != null && val > 0) widget.onChanged(...);
},

// ABV: 0~100
inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,1}$'))],
```

### 3-5. 접근성 (E16-E18)

- IconButton에 `tooltip` 추가
- FilterChip에 `semanticLabel` 추가
- 이모지 → Icon + Semantics 교체

### 3-6. 반응형 대응 (E2, E14-E15)

- EntryCardWidget: `SizedBox(width: 80)` → `Expanded` + `flex` 비율
- StatsScreen: 소형 화면 시 Column fallback
- OnboardingScreen: `MediaQuery` 기반 padding 조절

### 3-7. 키보드 관리 (E12)

```dart
// _save() 시작 시
FocusScope.of(context).unfocus();
```

### 3-8. ListView Key 추가 (E13)

```dart
// log_list_screen.dart
itemBuilder: (_, i) => _LogTile(key: ValueKey(logs[i].id), ...),
```

### 3-9. 테스트 추가 (F1)

우선순위별 테스트 대상:

| 우선 | 대상 | 파일 |
|------|------|------|
| 1 | DrinkLogRepository 통합 | `test/data/drink_log_repository_integration_test.dart` |
| 2 | ParseOrchestrator 단위 | `test/integrations/parser/parse_orchestrator_test.dart` |
| 3 | HomeViewModel 단위 | `test/viewmodels/home_viewmodel_test.dart` |
| 4 | DraftReviewViewModel 단위 | `test/viewmodels/draft_review_viewmodel_test.dart` |
| 5 | GeminiClient mock | `test/integrations/gemini/gemini_client_test.dart` |

### 3-10. 미사용 코드 정리 (F8-F9)

- 미사용 import 4건 제거
- 빈 디렉토리 5개 삭제
- `test/widget_test.dart` 빈 파일 삭제
- `tastingNoteRepoProvider` 미사용 provider 제거 (또는 TODO 주석)

---

## Phase 4: LOW — 코드 품질 마무리 (12건)

### 4-1. 하드코딩 문자열 추출

**신규 파일**: `lib/core/constants/strings.dart`
100+개 한글 문자열을 상수로 추출. 향후 i18n 전환 기반.

### 4-2. Magic Number 추출

**신규 파일**: `lib/core/constants/dimensions.dart`

```dart
abstract final class AppDimensions {
  static const double paddingS = 8;
  static const double paddingM = 16;
  static const double paddingL = 24;
  static const double cardRadius = 12;
  // ...
}
```

### 4-3. local_rule_parser 분리 (F7)

439줄 → 3개 파일:
- `lib/integrations/parser/local_rule_parser.dart` — 오케스트레이션 (100줄)
- `lib/integrations/parser/quantity_extractor.dart` — 수량 파싱 (100줄)
- `lib/integrations/parser/liquor_matcher.dart` — 주류 매칭 (150줄)

### 4-4. DraftReviewScreen build 분리 (E1)

125줄 build → 7개 서브위젯:
- `_SourceSection`, `_WarningsSection`, `_DateSection`
- `_PlaceSection`, `_EntriesSection`, `_FoodSection`, `_MemoSection`

### 4-5. Long-press 삭제 발견성 개선 (E3)

```dart
// log_list_screen.dart — InkWell(onLongPress:) 대신
Slidable(
  endActionPane: ActionPane(
    motion: const DrawerMotion(),
    children: [
      SlidableAction(onPressed: (_) => _confirmDelete(...),
        backgroundColor: Colors.red, icon: Icons.delete, label: '삭제'),
    ],
  ),
  child: _LogTile(...),
)
```

> flutter_slidable 패키지 추가 필요. 또는 PopupMenuButton으로 대체.

### 4-6. 날짜 의존 테스트 수정 (F10)

```dart
// Before: DateTime(2026, 3, 30, 22, 0) 하드코딩
// After: clock 패키지 또는 테스트 내 now 기준 상대 계산
final now = DateTime(2026, 3, 30, 22, 0);
final yesterday = resolveRelativeDate('어제', referenceDate: now);
expect(yesterday.day, 29);
```

### 4-7. DB 부가 개선 (D8-D11)

- SQL 컬럼명 보간 → switch 문으로 교체
- Seed ConflictAlgorithm.ignore → .replace
- createdAt DEFAULT 추가
- Naming 일관성 (ParseResult.empty → withDefaultEntry)

---

## 변경 파일 총괄

| 파일 | Phase | 변경 유형 | 설명 |
|------|-------|-----------|------|
| lib/core/providers.dart | 1,2 | 수정 | FutureProvider 전환 + invalidation 헬퍼 + DI provider 추가 |
| lib/core/exceptions.dart | 1,2 | **신규** | RepositoryException + AppError sealed class |
| lib/core/utils/label_utils.dart | 2 | **신규** | categoryLabel, unitLabel 공통 유틸 |
| lib/core/constants/strings.dart | 4 | **신규** | 한글 문자열 상수 |
| lib/core/constants/dimensions.dart | 4 | **신규** | 스페이싱/크기 상수 |
| lib/core/database/database_helper.dart | 1,4 | 수정 | 인덱스 추가 + 마이그레이션 + DEFAULT |
| lib/core/database/seed_loader.dart | 4 | 수정 | ConflictAlgorithm.replace |
| lib/data/drink_log_repository.dart | 1 | 수정 | N+1 해소 + 에러 핸들링 |
| lib/data/liquor_master_repository.dart | 2 | 수정 | 쿼리 최적화 + bare catch 수정 |
| lib/data/ai_config_repository.dart | 2 | 수정 | SQL 보간 제거 + rows.first 안전화 |
| lib/viewmodels/draft_review_viewmodel.dart | 1 | 수정 | save() 메서드 추가 |
| lib/viewmodels/home_viewmodel.dart | 1,3 | 수정 | Provider 연쇄 변경 + AsyncNotifier 마이그레이션 |
| lib/viewmodels/log_list_viewmodel.dart | 1 | 수정 | deleteLog() 추가 |
| lib/viewmodels/archive_viewmodel.dart | 1 | 수정 | Provider 연쇄 변경 |
| lib/viewmodels/stats_viewmodel.dart | 1 | 수정 | Provider 연쇄 변경 |
| lib/viewmodels/ai_settings_viewmodel.dart | 2,3 | 수정 | DI 개선 + copyWith + 에러 핸들링 |
| lib/views/draft_review/draft_review_screen.dart | 1,3,4 | 수정 | save 위임 + PopScope + build 분리 |
| lib/views/draft_review/widgets/entry_card_widget.dart | 3 | 수정 | 폼 검증 + 반응형 |
| lib/views/log/log_detail_screen.dart | 1,2 | 수정 | delete 위임 + import 정리 |
| lib/views/log/log_list_screen.dart | 1,2,4 | 수정 | delete 위임 + 중복 제거 + Slidable |
| lib/views/archive/archive_screen.dart | 2,3 | 수정 | label 유틸 사용 + 접근성 |
| lib/views/stats/stats_screen.dart | 2,3 | 수정 | label 유틸 사용 + 반응형 |
| lib/views/home/home_screen.dart | 2,3 | 수정 | import 정리 + 에러 위젯 |
| lib/views/home/widgets/recent_logs_widget.dart | 2 | 수정 | label 유틸 사용 |
| lib/views/settings/ai_settings_screen.dart | 3 | 수정 | 접근성 + 검증 |
| lib/views/onboarding/onboarding_screen.dart | 3 | 수정 | 반응형 padding |
| lib/views/common/error_state_widget.dart | 3 | **신규** | 공통 에러 상태 위젯 |
| lib/views/common/delete_confirm_dialog.dart | 2 | **신규** | 공통 삭제 확인 다이얼로그 |
| lib/integrations/parser/parse_orchestrator.dart | 2 | 수정 | 에러 분류 강화 |
| lib/integrations/parser/local_rule_parser.dart | 2,4 | 수정 | bare catch 수정 + 파일 분리 |
| lib/integrations/parser/gemini_text_parser.dart | 2 | 수정 | bare catch 수정 |
| lib/integrations/gemini/gemini_client.dart | 2 | 수정 | bare catch 수정 |
| test/golden/golden_helper.dart | 1 | 수정 | autoUpdateGoldenFiles 비활성화 |
| test/viewmodels/*_test.dart | 3 | **신규** | ViewModel 단위 테스트 |
| test/data/*_integration_test.dart | 3 | **신규** | Repository 통합 테스트 |

---

## 비범위

- **인터페이스 분리 (domain/repositories/)** — 구현체 1개이므로 오버엔지니어링
- **go_router 도입** — 네비게이션 패턴 전면 교체는 별도 작업
- **국제화(i18n) 완전 구현** — 상수 추출까지만, intl 메시지 카탈로그는 비범위
- **flutter_slidable 패키지** — Phase 4에서 PopupMenuButton으로 우선 대체 가능
- **이미지 파싱 파이프라인** — 현재 미구현 기능
- **TastingNote 기능 완성** — 미사용 코드 정리만 범위 내

## 트레이드오프

| 선택지 | 장점 | 단점 | 결정 |
|--------|------|------|------|
| Repository를 FutureProvider로 전환 | 크래시 방지, 타입 안전 | 소비자 코드 전부 `.future`/`.when()` 변경 필요 | **채택** — 안전성이 편의보다 중요 |
| Repository 인터페이스 분리 | 테스트 용이, 레이어 분리 | 파일 2배, 현재 구현 1개 | **미채택** — 프로젝트 규모에 과잉 |
| sealed class AppError | 타입 안전한 에러 처리 | 코드량 증가, 패턴 매칭 학습 필요 | **채택** — Dart 3 패턴 매칭과 궁합 |
| AsyncNotifier 통일 | 일관성, 최신 Riverpod 패턴 | HomeVM/DraftReviewVM 리팩토링 비용 | **HomeVM만 채택** — DraftReviewVM은 동기 초기화라 StateNotifier 적합 |

## 위험 요소

- **Phase 1 Provider 전환 시 연쇄 변경**: 거의 모든 ViewModel/View 파일 변경 필요. `flutter analyze` + `flutter test` 반복 검증
- **N+1 해소 시 쿼리 결과 매핑**: groupBy 로직 오류 시 entries/foods 꼬임 → 기존 테스트로 검증
- **DB 마이그레이션**: version 1 → 2 전환 시 기존 데이터 유실 없는지 에뮬레이터 테스트 필수
- **Golden 테스트 비활성화**: 기존 golden 파일과 현재 UI 불일치 시 대량 실패 가능 → Phase 1 마지막에 goldens 재생성

## 검증 기준

- [ ] `flutter analyze` — 0 issues
- [ ] `flutter test` — 전체 통과 (golden 제외 가능)
- [ ] Phase 1 후: View에서 Repository 직접 호출 0건 (`grep -r 'drinkLogRepoProvider\|parseJobRepoProvider' lib/views/` → 0 매치)
- [ ] Phase 1 후: N+1 해소 확인 (getAll 20건 호출 시 쿼리 3개 이하)
- [ ] Phase 2 후: `catch (_)` 패턴 0건 (`grep -r 'catch (_)' lib/` → 0 매치)
- [ ] Phase 2 후: 미사용 import 0건 (`flutter analyze`에서 unused_import 경고 0건)
- [ ] Phase 3 후: ViewModel 테스트 5개+ 파일 추가
- [ ] Phase 4 후: 300줄 초과 파일 0개 (`wc -l lib/**/*.dart | sort -rn | head`)

## 참조 코드

- **배치 로딩 패턴**: sqflite `rawQuery` + IN 절 — [sqflite cookbook](https://pub.dev/packages/sqflite#batch-support)
- **AsyncNotifier 마이그레이션**: [Riverpod 2.x migration guide](https://riverpod.dev/docs/migration/from_state_notifier)
- **sealed class 에러**: Dart 3 패턴 매칭 — [dart.dev patterns](https://dart.dev/language/patterns)
- **PopScope**: Flutter 3.16+ `PopScope` 위젯 — `WillPopScope` deprecated

## 구현 순서 요약

```
Phase 1 (CRITICAL)     Phase 2 (HIGH)        Phase 3 (MEDIUM)      Phase 4 (LOW)
─────────────────      ──────────────        ────────────────      ─────────────
1-1 Provider 안전화  → 2-1 AppError 타입   → 3-1 Provider 통일  → 4-1 문자열 추출
1-2 View→VM 이동    → 2-2 Bare catch 제거 → 3-2 에러/빈 위젯   → 4-2 Magic number
1-3 Repo 에러 핸들링 → 2-3 Force unwrap    → 3-3 뒤로가기 확인  → 4-3 Parser 분리
1-4 N+1 해소        → 2-4 에러 분류       → 3-4 폼 검증        → 4-4 Build 분리
1-5 DB 마이그레이션  → 2-5 import 정리     → 3-5 접근성         → 4-5 Slidable
1-6 Golden 수정     → 2-6 레이어 정리     → 3-6 반응형         → 4-6 테스트 수정
                    → 2-7 DI 개선         → 3-7 키보드         → 4-7 DB 부가
                    → 2-8 쿼리 최적화     → 3-8 ListView Key
                    → 2-9 에러 보강       → 3-9 테스트 추가
                    → 2-10 Invalidation   → 3-10 미사용 정리
                    → 2-11 중복 제거
```

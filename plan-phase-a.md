# Plan: Phase A — 와이어프레임 필수 Gap 3건
> 날짜: 2026-04-23
> 상태: 완료 (리뷰 1회 — Claude + Codex 교차 검증 반영, Phase A 3건 + A0 선행 결함 해결)
> 전제: [docs/plan-wireframe-diff.md](docs/plan-wireframe-diff.md) Phase A 의 L-4 / A-5 / D-1 을 하나의 워크스트림으로 묶어 구현.

## 목표
MVP 필수로 분류된 3건 Gap (테이스팅 노트 UI · 아카이브 상세 · AI 실패 경고 배너) 을 와이어프레임 대로 구현해 기획서 정합성을 확보한다. **선행 결함 1건** (편집 저장 시 tastingNote CASCADE 유실) 을 함께 해결해 데이터 손실을 방지.

## 접근법
독립적 3건이지만 "기록 조회/저장 경계의 MVP 완성" 단일 서사로 함께 처리. DB 스키마/마이그레이션은 전부 불필요 — 기존 `tastingNote` / `liquorMaster.isFavorite` / `aliasesJson` / `parseSource` 활용. 상세 화면은 `Navigator.push` 로 단순 추가. `DraftReviewState` 에 `wasAiAttempted` 플래그를 추가하되, **flag set 은 API 호출 직전 (키 유효 + 쿼터 통과 후)** 에만 트리거해 오탐 배제. `DrinkLogRepository.update()` 는 **entry id 보존 upsert** 로 재설계해 FK CASCADE 로 인한 tastingNote 유실을 차단.

## 변경 파일
| 파일 | 변경 유형 | 설명 |
|------|-----------|------|
| lib/core/providers.dart | 수정 | `tastingNoteRepoProvider` 추가, `tastingNoteByEntryProvider` FutureProvider.family 추가 |
| lib/domain/entities/tasting_note.dart | 수정 | `copyWith` 추가 — nullable 필드 clear 는 전체 replacement save 방식으로 처리 |
| lib/data/drink_log_repository.dart | 수정 | **`update()` 재설계** — drinkEntry id 보존 upsert (삭제→재삽입 금지) |
| lib/data/tasting_note_repository.dart | 수정 | `getByEntryIds(List<int>)` batch 조회 메서드 추가 (archive detail 에서 활용) |
| lib/views/log/widgets/tasting_note_section.dart | **신규** | 상세에 붙는 테이스팅 노트 섹션 (향/맛/피니시/평점/메모 표시 + 편집 CTA) |
| lib/views/log/widgets/tasting_note_edit_sheet.dart | **신규** | ModalBottomSheet 편집 폼 (TextField 3 + RatingBar + memo) |
| lib/views/log/widgets/star_rating.dart | **신규** | 0~5 (0.5 단위) interactive/display 별점 위젯 |
| lib/views/log/log_detail_screen.dart | 수정 | entry 카드 아래 `TastingNoteSection(entryId)` 삽입 |
| lib/viewmodels/archive_detail_viewmodel.dart | **신규** | 브랜드 상세 데이터 집계 (기록 히스토리 + 3 지표) |
| lib/views/archive/archive_detail_screen.dart | **신규** | 아카이브 상세 화면 |
| lib/views/archive/archive_screen.dart | 수정 | `_ArchiveTile.onTap` → push `ArchiveDetailScreen` |
| lib/integrations/parser/parse_result.dart | 수정 | `OrchestrateResult.wasAiAttempted` 필드 추가 (`default=false`) |
| lib/integrations/parser/parse_orchestrator.dart | 수정 | `_tryAiParse` 가 `({_AiParseResult? result, bool wasAttempted})` 레코드 반환. wasAttempted 는 `parser.parse` 호출 직전 true 로 set (disabled/no-key/quota 케이스 제외) |
| lib/viewmodels/draft_review_viewmodel.dart | 수정 | `DraftReviewState.wasAiAttempted` + `fromParseResult(wasAiAttempted:)` + **`copyWith` 에 `bool? wasAiAttempted` param 추가** |
| lib/viewmodels/home_viewmodel.dart | 수정 | `generateDraft` 반환 객체에 `wasAiAttempted` 전달 |
| lib/views/home/home_screen.dart | 수정 | `_navigateToReview` 에 `wasAiAttempted` 주입 |
| lib/views/draft_review/draft_review_screen.dart | 수정 | 상단 MaterialBanner: `state.source == 'local_parser' && state.wasAiAttempted` 시 표시, 닫기 시 `vm.dismissAiFailBanner()` (copyWith 활용) |

## 구현 단계

### A0: 선행 결함 해결 — drinkEntry id 보존 upsert (데이터 손실 차단)
> ⚠️ L-4 구현 전 **반드시** 완료. 현재 `update()` 는 drinkEntry 전삭제 → 재삽입이고 tastingNote 의 FK 가 CASCADE 라 기록 수정 시 노트 유실.
- [ ] 0. `drink_log_repository.dart:update()` 재설계:
  ```dart
  // Before: txn.delete('drinkEntry', where: 'logId=?'); ... 재삽입
  // After: entry.id 기준 upsert
  final existingEntries = await txn.query('drinkEntry',
      where: 'logId = ?', whereArgs: [log.id]);
  final existingIds = existingEntries.map((r) => r['id'] as int).toSet();
  final incomingIds = log.entries.where((e) => e.id != null).map((e) => e.id!).toSet();
  // 1) 제거된 entry 만 delete (→ tastingNote CASCADE 허용, 의도된 삭제)
  for (final id in existingIds.difference(incomingIds)) {
    await txn.delete('drinkEntry', where: 'id = ?', whereArgs: [id]);
  }
  // 2) 기존 entry update, 신규 entry insert
  for (final entry in log.entries) {
    final map = {...entry.toMap(), 'logId': log.id, 'updatedAt': now};
    if (entry.id != null && existingIds.contains(entry.id)) {
      await txn.update('drinkEntry', map, where: 'id = ?', whereArgs: [entry.id]);
    } else {
      await txn.insert('drinkEntry', map);
    }
  }
  // drinkLogFood 는 라벨성 단순 데이터라 기존 delete→reinsert 유지 OK
  ```
- [ ] 0a. `DraftEntry` 에 `int? id` 필드 추가 필요 — log_detail._edit() 경로에서 entry.id 전달되어야 함. `DraftEntry(id: e.id)` 로 매핑.
- [ ] 0b. `test/data/drink_log_repository_test.dart` 보강 — update 후 tastingNote 유지 검증 시나리오 (인메모리 sqflite 로 통합 테스트, 선택).

### D-1: AI 실패 경고 배너
- [ ] 1. `OrchestrateResult` 에 `final bool wasAiAttempted` (기본값 false) 추가 — 기본값 덕에 기존 호출부 호환.
- [ ] 2. `ParseOrchestrator._tryAiParse` 를 `Future<({_AiParseResult? result, bool wasAttempted})>` 로 변경.
  - config disabled / key 없음 / quota 초과 → `(null, wasAttempted: false)`
  - `parser.parse(...)` **직전** (L93-94) 에 도달 → wasAttempted = true
  - parse 성공 → `(_AiParseResult, wasAttempted: true)`
  - catch 블록 → `(null, wasAttempted: true)` (기존 에러 분류 로직 유지)
- [ ] 3. `ParseOrchestrator.process` 에서 `wasAiAttempted` 를 `OrchestrateResult` 에 전달.
- [ ] 4. `DraftReviewState.wasAiAttempted` 추가 + `fromParseResult(wasAiAttempted:)` param + **`copyWith({bool? wasAiAttempted})` 확장** (dismiss 기능에 필수).
- [ ] 5. `DraftReviewViewModel.dismissAiFailBanner()` → `state = state.copyWith(wasAiAttempted: false)`.
- [ ] 6. `draft_review_screen.dart` body 상단에 `MaterialBanner`:
  ```dart
  if (state.source == 'local_parser' && state.wasAiAttempted)
    MaterialBanner(
      content: const Text('⚠ AI 실패 — 로컬 파서 결과예요. 내용을 확인해주세요.'),
      backgroundColor: Colors.orange.shade50,
      leading: const Icon(Icons.warning_amber_rounded),
      actions: [TextButton(onPressed: () => vm.dismissAiFailBanner(), child: const Text('닫기'))],
    ),
  ```

### L-4: 테이스팅 노트 UI
- [ ] 7. `TastingNote.copyWith` 추가 (nullable 필드 clear 는 필요 시 whole-object replacement 로 해결 — 현재 `save()` 는 기존 레코드 덮어쓰므로 OK).
- [ ] 8. `core/providers.dart`:
  ```dart
  final tastingNoteRepoProvider = Provider((ref) => TastingNoteRepository(ref.watch(databaseProvider).requireValue));
  final tastingNoteByEntryProvider = FutureProvider.family<TastingNote?, int>((ref, entryId) async {
    return ref.watch(tastingNoteRepoProvider).getByEntryId(entryId);
  });
  ```
- [ ] 9. `star_rating.dart` — `StarRating({required double value, ValueChanged<double>? onChanged, double size=20})` 위젯. 5 별 × 0.5 단위 (탭 좌/우 반).
- [ ] 10. `tasting_note_section.dart` — `ConsumerWidget`, `tastingNoteByEntryProvider(entryId)` 구독.
  - 데이터: 향/맛/피니시 (각각 `Text` 2 줄 ellipsis), `StarRating(value)`, 메모, 우측 edit 아이콘
  - null: `OutlinedButton.icon(Icons.edit_note, label: '테이스팅 노트 작성')` — tap → edit sheet
- [ ] 11. `tasting_note_edit_sheet.dart` — `showModalBottomSheet` 로 호출. 3 TextField + `StarRating(interactive)` + memo + 저장/취소. 저장 시 `tastingNoteRepo.save(...)` → `ref.invalidate(tastingNoteByEntryProvider(entryId))`.
- [ ] 12. `log_detail_screen.dart` 의 entry 카드 Column 마지막 자식으로 `TastingNoteSection(entry.id!)` 추가. entry.id null 이면 저장 전이므로 표시 안 함 (실제로는 DB 조회 결과라 항상 non-null).

### A-5: 아카이브 상세 화면
- [ ] 13. `archive_detail_viewmodel.dart`:
  ```dart
  class ArchiveDetailData {
    final LiquorMaster master;
    final int totalRecords;          // liquorMasterId 일치 entry 가 있는 log 의 개수
    final double? avgRating;         // tastingNote.rating 이 non-null 인 entry 만 평균, 없으면 null
    final int totalEntries;          // 해당 masterId entry 총 개수 (수량 혼재 회피 — "총 음주량" 대신 "총 기록 잔/병 항목 수")
    final List<ArchiveHistoryItem> history; // 날짜 내림차순
  }
  final archiveDetailProvider = FutureProvider.family<ArchiveDetailData, int>((ref, masterId) async {
    final logs = await ref.watch(drinkLogRepoProvider).getAll();
    final matched = logs.where((l) => l.entries.any((e) => e.liquorMasterId == masterId)).toList();
    final entryIds = matched.expand((l) => l.entries).where((e) => e.liquorMasterId == masterId).map((e) => e.id).whereType<int>().toList();
    final notes = await ref.watch(tastingNoteRepoProvider).getByEntryIds(entryIds);
    final ratings = notes.where((n) => n.rating != null).map((n) => n.rating!).toList();
    return ArchiveDetailData(
      master: (await ref.watch(liquorMasterRepoProvider).getById(masterId))!,
      totalRecords: matched.length,
      avgRating: ratings.isEmpty ? null : ratings.reduce((a,b) => a+b) / ratings.length,
      totalEntries: entryIds.length,
      history: matched.map(ArchiveHistoryItem.fromLog).toList()..sort((a,b) => b.drankAt.compareTo(a.drankAt)),
    );
  });
  ```
- [ ] 14. `archive_detail_screen.dart` — AppBar ♥ 토글 + 3 지표 카드 (`avgRating == null` → "평점 미입력") + 기록 히스토리 리스트 + 별칭 chips + "+ 추가" AlertDialog (→ `masterRepo.addAlias(id, alias)` → invalidate).
- [ ] 15. `archive_screen.dart` `_ArchiveTile` 에 `onTap` 추가: `liquorMasterId != null` 일 때만 push, null 이면 SnackBar "마스터 데이터 없음".

### 검증
- [ ] 16. `flutter analyze` 0 issues
- [ ] 17. `flutter test --exclude-tags golden` 전체 통과
- [ ] 18. 수동 smoke (Windows 앱):
  - (a) AI 오프 상태 → 로컬 파서 → **배너 미표시**
  - (b) AI on + 잘못된 API Key → 로컬 fallback → **배너 표시** + 닫기 동작
  - (c) AI on + 쿼터 초과 → 로컬 fallback → **배너 미표시** (wasAttempted=false 경로)
  - (d) 기록 상세에서 테이스팅 노트 작성/편집, 노트 0.5 단위 별점
  - (e) **편집 flow 회귀 테스트**: 기록에 노트 저장 → 기록 수정 저장 → 노트 유지 확인
  - (f) 아카이브 탭 → 상세 이동 → 별칭 추가 → 즉시 chips 반영

## 비범위
- DB 스키마 변경 / `_dbVersion` 증가
- 사진 첨부, AI 이미지 기록 (Phase C 이후)
- 통계 파이/라인 차트 (Phase B)
- 설정 데이터 섹션 (Phase B)
- 미매칭 entry 의 아카이브 상세 (masterId 없음) — Phase C 에서 이름 기반 history 검토
- `TastingNote.copyWith` 의 nullable sentinel 패턴 — 현재 단일 노트 replacement 저장으로 우회

## 트레이드오프
| 선택지 | 장점 | 단점 | 결정 |
|--------|------|------|------|
| Tasting Note 편집: BottomSheet vs 별도 화면 | 화면 전환 적음, 컨텍스트 유지 | 키보드 올라오면 영역 좁음 | **BottomSheet** — 입력 필드 4개라 무리 없음 |
| wasAiAttempted set 시점: 진입 vs parse 직전 | 진입: 구현 간단 | 진입: disabled/quota 오탐 | **parse 직전** — Codex 지적 반영, 오탐 차단 |
| update() 재설계 vs snapshot/restore | 재설계: 근본 해결, FK CASCADE 존중 | 재설계: drink_log_repository 복잡도 ↑ | **재설계** — 장기적 옳음, 검증 테스트도 쉬움 |
| 평점 0.5 단위 vs 1.0 정수 | 세밀한 표현 | 탭 UX 복잡 | **0.5** — DB 필드 이미 `double`, 와이어도 `4.0`/`4.5` 표기 |
| 별칭 추가 UI: Dialog vs inline field | 기존 DeleteConfirmDialog 재활용 패턴 | BottomSheet 보다 가벼움 | **AlertDialog + TextField** |
| 아카이브 "총 음주량" vs "총 항목 수" | 음주량: 사용자 친화적 | 단위 혼재 (잔/병/캔) 합산 정확도 불명 | **총 항목 수** — 와이어는 "5잔" 이지만 MVP 에서는 단위 혼재 처리 회피 |

## 위험 요소
- **(해결) 편집 저장 시 tastingNote CASCADE 유실** — A0 단계에서 `update()` 재설계로 entry id 보존. 검증 시나리오 (e) 로 회귀 방지.
- `wasAiAttempted` 를 `OrchestrateResult` 에 추가할 때 `home_viewmodel.generateDraft` 반환 타입/호출부 동시 수정 필요. **기본값 `false` 로 선언해 중간 빌드 호환** + 단계 1-5 를 원자 커밋.
- `TastingNote` 가 UNIQUE(entryId) 라 저장 시 "이미 존재" 분기 (save 메서드 이미 handle — 갱신됨).
- `_dbVersion` 미변경 → 기존 사용자는 UI 만 새로 보이고 DB 영향 없음 ✅ 안전.
- 아카이브 상세 로딩 시간: `getAll()` → 필터링. Phase B 에서 `drink_log_repository` 에 `getByMasterId(masterId)` 추가로 최적화 가능.
- `DraftEntry` 에 `id` 추가 시 기존 직렬화 (`toJson`/`fromJson`) 호환성 확인 필요 — `id` 는 optional 이라 JSON 에 없으면 null, 있으면 보존.

## 검증 기준 *(Sprint Contract)*
> "구현해" 승인 = 아래 기준에 합의한 것으로 간주합니다.
- [ ] `flutter analyze` 0 issues + `flutter test --exclude-tags golden` 전체 통과
- [ ] **편집 flow 회귀 무결성**: 기록에 tastingNote 저장 → 기록 수정 저장 → 노트 유지
- [ ] 기록 상세 화면의 entry 카드 아래 `TastingNoteSection` 렌더링. 노트 없을 때 "테이스팅 노트 작성" CTA, 있을 때 향/맛/피니시/별점/메모 표시
- [ ] 편집 BottomSheet 에서 저장 시 즉시 반영 (invalidate)
- [ ] 아카이브 목록에서 item tap → 상세 화면으로 이동 (단, `liquorMasterId == null` 시 SnackBar)
- [ ] 아카이브 상세: 3 지표 + 히스토리 + 별칭 + 하트 토글 동작. `avgRating` 데이터 없으면 "평점 미입력" 표시
- [ ] 별칭 "+ 추가" 다이얼로그로 신규 별칭 입력 → 저장 → 즉시 chips 에 반영
- [ ] **AI 배너 분기 정확성**: (a) AI OFF → 미표시, (b) AI ON + API 실패 → 표시, (c) AI ON + 쿼터 초과 (API 호출 안 함) → **미표시**

## 참조 코드
- 기존 `_chip()` 헬퍼 — [log_detail_screen.dart:215-224](lib/views/log/log_detail_screen.dart)
- `showDeleteConfirmDialog` 패턴 — [lib/views/common/delete_confirm_dialog.dart](lib/views/common/delete_confirm_dialog.dart)
- `FilterChip` 그룹 패턴 — [archive_screen.dart:42](lib/views/archive/archive_screen.dart)
- Dart 3 pattern match: `switch (source)` — [source_badge_widget.dart:15](lib/views/draft_review/widgets/source_badge_widget.dart)

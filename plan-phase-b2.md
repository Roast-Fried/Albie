# Plan: Phase B2 — 기록 목록/상세 + 아카이브 카드 강화
> 날짜: 2026-04-23
> 상태: 완료
> 전제: B1 완료 (`5d1987c`). 와이어프레임 Phase B 나머지 6건.

## 목표
"기록 → 회고 → 아카이브" 의 조회 경험을 와이어프레임 수준으로 마감한다.

## 변경 파일
| 파일 | 유형 | 설명 |
|------|------|------|
| lib/core/utils/date_utils.dart | 수정 | `timeOfDayKorean(DateTime)` 추가 (아침/점심/저녁/밤/새벽) |
| lib/views/log/log_list_screen.dart | 수정 | 월별 그룹 헤더 + 시간대 자연어 (L-1/L-2) |
| lib/views/log/log_detail_screen.dart | 수정 | 날짜+시간대, Entry 서브타이틀 (subcategory · 연산 · ABV), 평점 표시 (L-7) |
| lib/viewmodels/archive_viewmodel.dart | 수정 | ArchiveItem 에 `defaultAbv`, `country`, `subcategory`, `avgRating` 추가 (batch 조회) |
| lib/views/archive/archive_screen.dart | 수정 | 상단 "N종 총 N회 기록" 요약 + 카드 서브라인 국가·ABV · 평점 별 (A-1/A-2/A-4) |

## 구현 단계

### B2-A: date_utils 시간대 자연어
- [ ] 1. `timeOfDayKorean(DateTime)`:
  ```dart
  String timeOfDayKorean(DateTime dt) {
    final h = dt.hour;
    if (h < 5) return '새벽';
    if (h < 11) return '아침';
    if (h < 13) return '점심';
    if (h < 18) return '오후';
    if (h < 22) return '저녁';
    return '밤';
  }
  ```

### B2-B: log_list 월 그룹 + 시간대
- [ ] 2. `_LogListScreenState.build` 의 `ListView` 를 월별로 분할해 섹션 헤더 + 타일로 렌더.
- [ ] 3. `_LogTile` 의 dateStr 포맷을 `"M/d (E) 밤 11:30"` 형식으로 수정:
  ```dart
  final weekDay = DateFormat('M/d (E)', 'ko').format(log.drankAt);
  final tod = timeOfDayKorean(log.drankAt);
  final time = DateFormat('h:mm').format(log.drankAt);
  final dateStr = '$weekDay $tod $time';
  ```

### B2-C: log_detail 서브타이틀
- [ ] 4. `_DetailBody.dateStr` 도 "M월 d일 (E) 밤 11:30" 포맷으로.
- [ ] 5. Entry 카드의 Wrap chips → subtitle 로 변경:
  - 영문 병기: `liquorNameRaw (canonicalName)` — liquorMasterId 있을 때
  - 서브라인: `"싱글몰트 · 15년 · 43%"` (subcategory + ageStatement + alcoholPercent)
  - liquorMaster JOIN: FutureProvider.family<LiquorMaster?, int> 이미 있으면 활용, 없으면 간단 조회

### B2-D: archive 강화
- [ ] 6. `ArchiveItem` 확장 (+ defaultAbv, country, subcategory, avgRating).
- [ ] 7. `ArchiveViewModel._loadArchive` 에서 master 정보 + tastingNote batch 로 avgRating 계산.
- [ ] 8. `archive_screen` 상단에 요약 Row — "`${items.length}종 · 총 ${totalRecords}회 기록`" (recordCount 합).
- [ ] 9. `_ArchiveTile` 서브라인 "`${subcategory ?? category} · ${country} · ${abv}% ABV`" + 카드 오른쪽 영역에 별점 (if avgRating != null).

### 검증
- [ ] 10. `flutter analyze` 0 issues
- [ ] 11. `flutter test --exclude-tags golden` 전체 통과
- [ ] 12. 수동: (a) 목록에 월 헤더 표시, (b) 시간 "저녁 7:00" 형식, (c) 상세 영문 병기 + 서브라인, (d) 아카이브 상단 요약 + 카드 국가/ABV/별점

## 비범위
- D-3/D-4/D-5 검토 디테일 — Phase B3
- H-5 AI 로딩 취소 버튼 — Phase B3 (dio CancelToken 필요)
- AI-3 배너 스타일 카드화 — Phase B3
- E-1 공통 빈 상태 CTA — Phase B3
- C-3/C-4/C-5/C-8 설정 세부 (다크모드/단위/컷오프/라이선스) — Phase C

## 트레이드오프
| 선택지 | 장점 | 단점 | 결정 |
|--------|------|------|------|
| log_list 월 그룹: 전처리 vs StickyHeader 패키지 | 단순 List flatMap | 그룹 헤더 스크롤 sticky 아님 | **flatMap** — 패키지 추가 회피 |
| ArchiveItem avgRating: 매번 batch 조회 vs 필요 시만 | 즉시 UI 반영 | getAll() 추가 부하 | **매번** — 기록 수 많지 않음 |
| 영문 병기: JOIN vs raw 이름만 | 와이어 부합 | master 조회 1회 추가 | **병기** — tile 단순, Section 재사용 |

## 위험 요소
- log_list 월 그룹 변환 후 RefreshIndicator / Key 동작 점검.
- archive_viewmodel 에서 batch 로 tastingNote 조회 시, entryId 가 없는 엔트리(저장 전) 제외.
- 시간대 포맷이 integration_test 영향 여부 — 기존 assertion 은 "M/d (E) a h:mm" 가 아니라 화면 텍스트 일부라 영향 낮음.

## 검증 기준 (Sprint Contract)
- [ ] `flutter analyze` 0 issues + `flutter test --exclude-tags golden` 통과
- [ ] 기록 목록에 월별 그룹 헤더 ("4월 2026") 표시
- [ ] 목록 / 상세 dateStr 에 "저녁/밤/아침/새벽" 포함
- [ ] 기록 상세 Entry 에 영문 병기 + subcategory · 연산 · ABV 서브라인
- [ ] 아카이브 상단 "N종 · 총 N회" 요약 + 각 카드 국가 · ABV · 평점

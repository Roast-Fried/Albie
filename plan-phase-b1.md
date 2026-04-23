# Plan: Phase B1 — 통계 + 설정 + AI 로그 + 홈 보강
> 날짜: 2026-04-23
> 상태: 완료
> 전제: Phase A 완료 (`0ea5126` 기준). [docs/plan-wireframe-diff.md](docs/plan-wireframe-diff.md) Phase B 중 사용자 인지 가치가 큰 묶음을 B1 으로 묶음.

## 목표
와이어프레임의 통계 차트·설정 데이터 섹션·AI 처리 로그·홈 지표를 구현해 "기록 후 회고" 경험 완성. Phase B 24건 중 11건 해결.

## 접근법
- **fl_chart ^0.68.0** 도입 (와이어프레임 파이/라인 차트) — APK 증가는 선택 패키지라 감수.
- **설정 메인 재작성** — 현재 31줄이라 처음부터 재설계: AI 섹션(토글+사용량) + 데이터 섹션(카운트+초기화) + 정보.
- **AI 처리 로그** — 기존 `parseJob` 테이블 활용, `ParseJobRepository.getRecent` 이미 존재.
- **홈 보강** — `thisMonthCount` 는 stats 에 이미 있음, 최근 마셔본 술 chips 는 archive 집계 재활용.
- DB 스키마 변경 없음.

## 변경 파일
| 파일 | 유형 | 설명 |
|------|------|------|
| pubspec.yaml | 수정 | `fl_chart: ^0.68.0` 추가 |
| lib/views/stats/stats_screen.dart | 수정 | 기간 탭 + 파이차트 + 라인차트 + TOP5 순번 (S-1/S-2/S-3/S-4) |
| lib/viewmodels/stats_viewmodel.dart | 수정 | 기간 enum (`StatsPeriod`) + 기간별 집계 — thisMonth / last3Months / all |
| lib/views/settings/settings_screen.dart | 수정 | AI 섹션 + 일반 + 데이터 + 정보 재설계 (C-1/C-2/C-6/C-7) |
| lib/viewmodels/settings_viewmodel.dart | **신규** | `settingsDataProvider` — 기록 수 / 마셔본 술 수 / 초기화 액션 |
| lib/views/settings/ai_settings_screen.dart | 수정 | 하단에 최근 처리 로그 섹션 (AI-1) |
| lib/viewmodels/ai_settings_viewmodel.dart | 수정 | `recentParseJobsProvider` 추가 |
| lib/data/parse_job_repository.dart | 수정 | `getRecent` 는 이미 있음 — 확인 |
| lib/views/home/home_screen.dart | 수정 | 🔔 아이콘 (AI 설정 바로가기) + 이번 달 카운트 + 최근 마셔본 술 chips (H-1/H-2/H-3) |
| lib/core/providers.dart | 수정 | `thisMonthCountProvider` + `recentTopLiquorsProvider` 추가 |

## 구현 단계

### B1-A: fl_chart 도입 + 통계 화면 (S-1~S-4)
- [ ] 1. `pubspec.yaml` 에 `fl_chart: ^0.68.0` 추가, `flutter pub get`.
- [ ] 2. `stats_viewmodel.dart`:
  ```dart
  enum StatsPeriod { thisMonth, last3Months, all }
  final statsPeriodProvider = StateProvider((_) => StatsPeriod.thisMonth);
  // statsProvider 가 ref.watch(statsPeriodProvider) 해서 필터링 반영
  ```
- [ ] 3. `stats_screen.dart`:
  - 상단 `SegmentedButton<StatsPeriod>` (이번 달/3개월/전체)
  - 3 지표 카드 (기존 유지, 기간 반영)
  - `PieChart` (fl_chart) — categoryDistribution
  - TOP 5 순번 리스트 (1~5 번호 + 브랜드명 + 카운트)
  - `LineChart` (fl_chart) — monthlyTrend 6개월

### B1-B: 설정 메인 재설계 (C-1/C-2/C-6/C-7)
- [ ] 4. `settings_viewmodel.dart`:
  ```dart
  class SettingsDataSnapshot { final int totalLogs; final int totalMasters; }
  final settingsDataProvider = FutureProvider((ref) async {
    final logs = await ref.watch(drinkLogRepoProvider).count();
    final masters = await ref.watch(liquorMasterRepoProvider).countDistinctLogged();
    // 또는 drinkEntry DISTINCT liquorMasterId COUNT
    return SettingsDataSnapshot(totalLogs: logs, totalMasters: masters);
  });
  Future<void> resetAllData(WidgetRef ref) async { /* drinkLog + drinkEntry + drinkLogFood + tastingNote DELETE */ }
  ```
- [ ] 5. `settings_screen.dart` 재작성:
  - AI 섹션: `AI 사용` 토글 (aiConfigProvider.toggleEnabled), `오늘 사용량 N/10회` 표시, "AI 설정 상세 →"
  - 일반 섹션: 버전 정보 (placeholder, 향후 다크모드/단위는 Phase C)
  - 데이터 섹션: 전체 기록 수 / 마셔본 술 수 / 데이터 초기화 (DeleteConfirmDialog + resetAllData)
  - 정보: 버전 0.1.0

### B1-C: AI 설정 최근 처리 로그 (AI-1)
- [ ] 6. `ai_settings_viewmodel.dart` 에 `recentParseJobsProvider` 추가:
  ```dart
  final recentParseJobsProvider = FutureProvider<List<ParseJob>>((ref) async {
    return ref.watch(parseJobRepoProvider).getRecent(limit: 10);
  });
  ```
- [ ] 7. `ai_settings_screen.dart` 하단에 섹션:
  - 제목 "최근 처리 로그"
  - 각 row: `HH:mm` + parserUsed + durationMs + status (✓/✗)
  - 빈 상태 "기록 없음"

### B1-D: 홈 보강 (H-1/H-2/H-3)
- [ ] 8. `core/providers.dart` 에 `thisMonthCountProvider`:
  ```dart
  final thisMonthCountProvider = FutureProvider<int>((ref) async {
    final stats = await ref.watch(statsProvider.future);
    return stats.thisMonthCount;
  });
  final recentTopLiquorsProvider = FutureProvider<List<String>>((ref) async {
    // stats.topLiquors 재활용, 상위 N 브랜드명만
    final stats = await ref.watch(statsProvider.future);
    return stats.topLiquors.take(6).map((e) => e.key).toList();
  });
  ```
- [ ] 9. `home_screen.dart`:
  - AppBar actions 에 🔔 IconButton → AiSettingsScreen 으로 이동 (처리 로그 == 알림 로그 대응)
  - 하단 통계 카드 텍스트: `총 N건 기록` → `이번 달 N회 기록` (thisMonthCountProvider)
  - `RecentLogsWidget` 아래에 "최근 마셔본 술" Chips 가로 스크롤 (recentTopLiquorsProvider)

### 검증
- [ ] 10. `flutter analyze` 0 issues
- [ ] 11. `flutter test --exclude-tags golden` 전체 통과
- [ ] 12. 수동 smoke:
  - (a) 통계 탭 기간 전환 시 3 지표 / 파이 / 라인 재집계
  - (b) 설정 메인에서 AI 토글 → aiConfig 반영, 데이터 초기화 → 확인 다이얼로그 후 전체 비움
  - (c) AI 설정에서 최근 처리 로그 출력
  - (d) 홈 🔔 탭 → AI 설정, "이번 달 N회" 표시, 최근 마셔본 술 chips 노출

## 비범위
- 다크 모드 명시 선택 (C-3), 기본 수량 단위 (C-4), 6시 컷오프 토글 (C-5), 오픈소스 라이선스 (C-8) — Phase C
- 기록 목록/상세 시각 UI (L-1/L-2/L-7) — Phase B2
- 아카이브 카드 강화 (A-1/A-2/A-4) — Phase B2
- 검토 디테일 (D-3/D-4/D-5) — Phase B3
- AI 로딩 취소 (H-5), AI-3 배너 스타일, E-1 빈 상태 CTA — Phase B3
- 홈 "→ 더보기" 링크 (H-4) — Phase B3

## 트레이드오프
| 선택지 | 장점 | 단점 | 결정 |
|--------|------|------|------|
| fl_chart 추가 vs CustomPaint 직접 구현 | 빠른 구현 + 인터랙션 내장 | APK ~500KB 증가 | **fl_chart** — MVP 시간 제약 |
| 설정 메인 재설계 vs 부분 추가 | 깔끔한 카드 레이아웃 | 파일 전면 교체 | **재설계** — 기존 31 줄이라 손실 없음 |
| 홈 🔔 → AI 설정 vs 별도 "알림 로그" 화면 | parseJob 이미 AI 설정에 통합 | 의미 중복 | **AI 설정 링크** — 화면 1개 줄이기 |
| thisMonthCount: 별도 FutureProvider vs statsProvider 재사용 | Provider 분리 | statsProvider loading 낭비 | **재사용** — statsProvider 는 이미 cache |

## 위험 요소
- `fl_chart` 버전 호환: Flutter 3.41.6 에서 ^0.68 정상 동작 확인 필요. 실패 시 `^0.66` 로 다운.
- 데이터 초기화 실수 위험: 반드시 DeleteConfirmDialog + "이 기록은 복구할 수 없습니다" 문구.
- `recentTopLiquorsProvider` 는 topLiquors 이름 기반. 동일 브랜드인데 매칭 실패한 엔트리는 중복 표시될 수 있음 → 수용.
- 설정 재설계 후 `more_screen.dart` 의 네비게이션 여전히 동작하는지 확인 필요.

## 검증 기준 (Sprint Contract)
- [ ] `flutter analyze` 0 issues + `flutter test --exclude-tags golden` 통과
- [ ] 통계 탭 전환 (이번 달/3개월/전체) 시 3 지표 · 파이 · 라인 · TOP5 갱신
- [ ] 파이차트 · 라인차트 렌더링 (fl_chart)
- [ ] 설정 메인: AI 토글 · 오늘 사용량 · 데이터 섹션 3 ListTile · 데이터 초기화 확인 다이얼로그
- [ ] AI 설정 하단에 최근 처리 로그 섹션 (최대 10건, 빈 상태 문구)
- [ ] 홈 AppBar 🔔 아이콘 (AI 설정 이동), 하단 카드 "이번 달 N회", 최근 마셔본 술 가로 chips

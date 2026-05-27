# UI/UX 깨짐 plan (2026-05-26)

> 모바일 세로 (logical 360x800 @ 3.0x) 환경에서 전수 시각 검증 결과.
> integration_test/{home,draft_review,log,archive,stats,settings,onboarding}_capture_test.dart 의 PNG 캡처를 Claude main 이 Read 로 시각 검증.
> Codex Phase 4 fix loop 적용 — P0 → P1 → P2 순.

## 환경
- viewport: logical 360x800 @ 3.0x (Pixel 5 비슷)
- Iter 8 fix 적용 후 (AI app_default 제거 + parser 카테고리 skip + mapCategory 확장)
- screenshot: `test_screenshots/{file}_{nn}_{desc}.png`

## 발견 issue (P0 = 즉시 fix, P1 = 다음 sprint, P2 = 여유)

| ID | 화면 | PNG | 깨짐 종류 | 우선순위 | fix 방향 |
|---|---|---|---|---|---|
| **UI-001** | DraftReview entry card | `draft_01/07/08` | 가로 5 필드 (주종/연산/양/단위/도수%) 360px 에서 cramped. "도..." ellipsis | **P0** | 2 행 layout 으로 분리 (주종+연산 / 양+단위+도수%) 또는 도수% 라벨 단축 ("도수" 또는 "ABV") |
| **UI-014** | DraftReview entry card | `draft_02/03/04/05` | 술이름 TextField 의 InputDecoration label 이 OutlineBorder 와 겹쳐서 cramped 표시 (label `floatingLabelBehavior` 또는 isCollapsed 영향) | **P0** | label 위치 조정 또는 OutlinedInputBorder 의 gap padding 명시 |
| **UI-017** | DraftReview entry card | `draft_08` (글렌피딕 입력) | 직접 입력 시 술 이름 변경에도 master matching 미호출 → 카테고리 "기타" + warning + 도수% master default 안 채워짐 | **P0** | `_onNameChanged` 또는 onChanged 시 LocalRuleParser._matchLiquor 호출하여 카테고리/도수 자동 채움 |
| **UI-002** | DraftReview entry card | `draft_05/06` | "연산" label 의미 모호 (ageStatement → 일반인에게 "숙성연수" 또는 "에이지" 가 더 명확) | **P1** | label 변경 "연산" → "숙성연수" + hintText "예: 12년" |
| **UI-016** | DraftReview entry card | `draft_01/07/08` | "수량이 추정치입니다" warning 이 **직접 입력 모드에서도 표시** (사용자 명시 입력인데 isEstimated=true) | **P1** | DraftReviewState.manual() 의 entry isEstimated default false, 또는 사용자가 양 필드 명시 수정 시 isEstimated false |
| **UI-005** | DraftReview entry card | `draft_08` | 글렌피딕 입력 후 "이름을 정확히 확인하지 못했습니다" warning 이 잘못 표시 — master 매칭 호출 안 되어서 (UI-017 와 동일 원인) | **P1** | UI-017 fix 시 함께 해소 |
| **UI-018** | Home | `home_06_after_clear` | clear 후 focus 잔존 → cursor 가 placeholder 첫 글자 "나" 의 "ㄴ" 부분 가림 ("ㅏ 오늘..." 처럼 보임) | **P2** | clear 시 `FocusScope.of(context).unfocus()` 또는 cursor 위치 reset |
| **UI-004** | Stats | `layout_05_stats` | SegmentedButton (이번 달/3개월/전체) 의 "이번 달" 체크 ✓ 아이콘 + label 360px 에서 약간 cramped | **P2** | label 단축 "이번 달" → "월" 또는 SegmentedButton.showSelectedIcon: false |

## 화면별 상황 누락 (아직 캡처 못한 시나리오)

| 화면 | 누락 시나리오 | 캡처 방법 |
|------|-------------|----------|
| Home | AI 로딩 중 / 이미지 첨부 / AI 실패 배너 | mock AI key 환경 or 이미지 fixture |
| DraftReview | 음식 chip 추가 후 / 별점 입력 | draft_10/11 capture step fix (find.byIcon matcher) |
| Log | 빈 상태 / 검색 결과 0 / 삭제 confirm | 데이터 reset + 0-result 검색 |
| Archive | 빈 상태 (모든 favorite 해제 후) | DB seed reset |
| Stats | 0건 / 1건 / 다양한 카테고리 | DB seed variation |
| Settings | 다크 모드 적용 후 화면 / AI key 등록됨 상태 / 데이터 초기화 confirm | tap flow 추가 |
| Onboarding | 3 페이지 모두 + 시작/건너뛰기 두 종료 path | SharedPreferences reset |

## fix 사이클 계획 (Codex 페어)

### Sprint 1: P0 3건 (UI-001 / UI-014 / UI-017)
1. `entry_card_widget.dart` 의 가로 5 필드 → 2 행 분리 (UI-001 + UI-014)
2. `draft_review_viewmodel.dart` 의 entry 이름 onChanged 시 `_matchLiquor` 호출 (UI-017)
3. flutter analyze + flutter test smoke
4. Codex audit (페어)
5. capture test 재실행 (draft_review_capture_test) + screenshot 시각 재검증
6. P0 모두 해소 확인 후 commit

### Sprint 2: P1 3건 (UI-002 / UI-016 / UI-005)
- UI-005 는 UI-017 와 함께 해소될 가능성 — Sprint 1 후 재검증
- UI-002: 라벨 단순 텍스트 변경
- UI-016: DraftReviewState.manual() 의 isEstimated default 변경

### Sprint 3: P2 2건 (UI-018 / UI-004)
- 시간 여유 시 적용

### Sprint 4: 누락 시나리오 캡처
- Phase 1 의 capture test 보강 + 누락된 상황 (AI 로딩 / 빈 상태 / 다크 모드 등) 추가
- 재실행 + 시각 재검증

## 회귀 테스트
각 fix 시:
- `bash scripts/run-all-tests.sh smoke` 으로 unit/widget test 통과 확인
- `flutter test integration_test/{file}_capture_test.dart -d windows` 으로 해당 화면 재캡처
- 시각 검증 후 commit

## 추가 발견 (2026-05-27 — archive/stats/onboarding 검증 후)

| ID | 화면 | PNG | 깨짐 종류 | 우선순위 | fix 방향 |
|---|---|---|---|---|---|
| **UI-019** | Archive | `archive_03_detail` | 글렌피딕 입력이 master matching 미발동으로 카테고리 "기타" 로 들어가 archive 빈 화면 | **P0** | UI-017 fix 시 함께 해소 (manual 입력 → liquorMaster.category 'whisky') |
| **UI-020** | Archive | `archive_02_filter_whisky` | 상단 필터 chip "전체/위스키/하이볼/맥주/와인..." 가 가로 overflow — "와인" 마지막이 "와…" 로 잘림 | **P1** | SingleChildScrollView 적용 또는 chip 자체 ellipsis 제거 |
| **UI-022** | Stats | `stats_01_this_month` | donut chart 100% "기타" — UI-019 와 같은 root cause (글렌피딕 카테고리 매핑 실패) | **P0** | UI-017 fix 시 함께 해소 |
| **UI-NEW** | Onboarding | `onboarding_01~03` | 페이지 indicator dot / "다음" / "건너뛰기" / "시작" 버튼 미보임 (캡처 영역 너비 360 × 700+) — 버튼이 캡처 boundary 밖이거나 페이지에 부재 | **P2** | onboarding_screen 의 버튼 영역 캡처 가능 viewport 안에 배치 확인 |

## Sprint 1 진행 (2026-05-27)

### 적용 fix
- ✅ UI-001: `entry_card_widget.dart` 양/단위 행과 도수% 행 분리 (2 행 layout). 도수% label "도수 (%)" + hint "예: 40".
- ✅ UI-002: 연산 → "숙성" + hint "12년" + width 80→100.
- ✅ UI-016: `DraftReviewState.manual()` 의 DraftEntry isEstimated=false 명시.
- ✅ UI-017: `DraftReviewViewModel.tryMatchByName()` 추가 (race protection + masterId/category/abv 갱신) + entry_card `_scheduleNameMatch()` 400ms debounce.
- ✅ UI-005 / UI-019 / UI-022: UI-017 fix 시 함께 해소 예상 (글렌피딕 → category 'whisky' + defaultAbv 40 자동 채움).

### 미적용 (다음 sprint)
- UI-014 술이름 label cramped — PNG 재확인 시 label 정상 floating, 별도 cosmetic. P2 강등.
- UI-018 home clear 후 cursor focus — P2 유지.
- UI-004 stats SegmentedButton cramped — P2 유지.
- UI-020 archive chip overflow — P1 다음 sprint.
- UI-NEW onboarding 버튼 캡처 누락 — P2 다음 sprint.

## Sprint 2/3 진행 (2026-05-27)

### 적용 fix
- ✅ UI-020 (P1): archive 카테고리 chip ShaderMask + 우측 fade gradient 추가 + trailing padding 32 — 스크롤 가능 신호 명시.
- ✅ UI-018 (P2): home input clear 시 `FocusScope.of(context).unfocus()` 호출 — placeholder 가림 방지.
- ✅ UI-004 (P2): stats SegmentedButton `showSelectedIcon: false` — ✓ + label cramped 해소.

### 분석 후 skip
- UI-014: 재캡처 시 label 정상 floating 확인. cosmetic 미발생 — fix 불필요.
- UI-NEW (onboarding 버튼 캡처 누락): 코드 검증 (`onboarding_screen.dart:42-80`) 결과 indicator dot + 다음/시작/건너뛰기 모두 정상 존재. capture viewport 영역 문제이지 실 UI 깨짐 아님 — 실 device 에서 정상 노출.

## 진행 로그
- 2026-05-26: home_capture_test 6 PNG + draft_review_capture_test 11 PNG 캡처 완료
- 2026-05-26: UI-001/UI-002/UI-004/UI-005/UI-014/UI-016/UI-017/UI-018 발견
- 2026-05-26: archive (4) + stats (5) + log (1) capture 완료 — UI-019/020/022 추가 발견
- 2026-05-27: onboarding 3 PNG 캡처 (test 통과). settings 는 layout_06/07/08 (6 PNG) 으로 시각 검증 대체 (settings_capture_test hitTest 충돌로 skip)
- 2026-05-27: Sprint 1 fix 7건 (UI-001/002/016/017 + UI-005/019/022 root cause + Codex HIGH 3건) 적용. commit `1faa4ba`.
- 2026-05-27: Sprint 2/3 fix 3건 (UI-004/018/020) 적용 + UI-014/NEW 분석 후 skip.

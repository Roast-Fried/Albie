# Plan: Phase B3 — 검토 화면 디테일 + 네비 + 빈 상태
> 날짜: 2026-04-23
> 상태: 완료 (순차 구현 이어받음)
> 전제: B2 완료 (`16a62b8`). 와이어프레임 Phase B 잔여 5건.

## 목표
검토 화면 미매칭/추정치 시각화 + 홈 더보기 링크 + 빈 상태 CTA 일관성.

## 변경 파일
| 파일 | 유형 | 설명 |
|------|------|------|
| lib/views/draft_review/widgets/entry_card_widget.dart | 수정 | 매칭 아이콘 suffixIcon + 영문 병기 helper + 필드별 경고 텍스트 (D-3/D-4/D-5) |
| lib/views/home/widgets/recent_logs_widget.dart | 수정 | "→ 더보기" 링크 (H-4) |
| lib/views/home/home_screen.dart | 수정 | "더보기" 콜백으로 LogList 이동 |
| lib/views/log/log_list_screen.dart | 수정 | 빈 상태 CTA "+ 첫 기록 남기기" (E-1) |
| lib/views/archive/archive_screen.dart | 수정 | 빈 상태 CTA |

## 구현 단계

### B3-A: EntryCardWidget 디테일
- [ ] 1. `entry_card_widget.dart` 에 `Consumer` 로 변환 → `liquorMasterId` 있으면 `liquorMasterRepoProvider.getById` 로 master 조회 (FutureProvider.family).
- [ ] 2. 이름 TextField 의 suffixIcon:
  - master != null → `Icon(Icons.check_circle, color: Colors.green, size: 18)`
  - master == null && liquorNameRaw.isNotEmpty → `Icon(Icons.warning_amber, color: Colors.orange, size: 18)`
- [ ] 3. 이름 필드 아래 helperText (작은 글씨):
  - 매칭 안 됨 + raw 비어있지 않으면: "⚠ 이름을 정확히 확인하지 못했습니다"
  - 매칭됨 + master.canonicalName ≠ liquorNameRaw: "(${canonicalName})" 병기
- [ ] 4. 수량 필드 아래 helperText: `entry.isEstimated` 이면 "⚠ 수량이 추정치입니다"

### B3-B: RecentLogsWidget 더보기 링크
- [ ] 5. `RecentLogsWidget` 상단 "최근 기록" 텍스트 Row 에 `Spacer` + `TextButton("→ 더보기", onPressed: onMore)` 추가.
- [ ] 6. home_screen 에서 `RecentLogsWidget(logs, onMore: () => _goToLogList(context))` 로 콜백 전달.

### B3-C: 빈 상태 CTA
- [ ] 7. `log_list_screen._EmptyState` 에 CTA: `FilledButton.icon(Icons.add, '첫 기록 남기기')` — onPressed 는 Navigator.pop 으로 홈으로.
- [ ] 8. `archive_screen` 의 `Center(child: Text('기록이 없어요'))` 를 동일 스타일로 교체.

### 검증
- [ ] 9. `flutter analyze` 0 issues
- [ ] 10. `flutter test --exclude-tags golden` 전체 통과
- [ ] 11. 수동 smoke: (a) 매칭 안 된 brand 입력 시 ⚠ + 경고 텍스트, (b) 매칭 brand 는 ✓ + 영문 병기, (c) 홈 "→ 더보기" 탭 시 로그 목록 이동, (d) 목록/아카이브 비어있을 때 CTA 버튼 노출

## 비범위
- H-5 AI 로딩 취소 버튼 (CancelToken 필요) — Phase B4
- O-1/2/3 온보딩 비주얼 개선 — Phase B4
- AI-3 배너 스타일 카드화 — 이미 Card 로 구현됨 ([draft_review_screen.dart:85-104](lib/views/draft_review/draft_review_screen.dart)), 추가 작업 없음
- C-3/C-4/C-5/C-8 설정 세부 — Phase C

## 트레이드오프
| 선택지 | 장점 | 단점 | 결정 |
|--------|------|------|------|
| EntryCard 를 Consumer 로 변환 | 단일 widget 내 master 조회 | initState 로직 손봄 | **채택** — state 관리 단순화 |
| 영문 병기: helperText vs 별도 Text | 필드와 묶여 UX 명확 | 긴 문자열 시 overflow | **helperText** + maxLines |
| 빈 상태 CTA "첫 기록 남기기": Navigator.pop vs tab 직접 변경 | pop 은 이미 홈 탭에 있다는 가정 | tab index 제어 복잡 | **pop** — LogListScreen 은 항상 tab 2 위에서만 보임 |

## 위험 요소
- EntryCard 가 StatefulWidget 인데 Consumer 로 바꾸면 TextEditingController 초기값 로직 영향 — ConsumerStatefulWidget 로 전환.
- RecentLogsWidget onMore callback 옵셔널로 두어 기존 사용처 깨지지 않도록.

## 검증 기준 (Sprint Contract)
- [ ] `flutter analyze` 0 issues + `flutter test --exclude-tags golden` 통과
- [ ] 검토 화면 Entry 이름 필드에 ✓/⚠ suffixIcon 표시
- [ ] 매칭 안된 이름 + 추정 수량 → inline helperText 경고
- [ ] master 매칭 시 영문 병기 helperText
- [ ] 홈의 최근 기록 섹션에 "→ 더보기" 링크 노출 → 로그 목록 이동
- [ ] 로그 목록 / 아카이브 빈 상태에 "첫 기록 남기기" CTA

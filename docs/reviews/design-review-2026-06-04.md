# 디자인 다방면 재검토 (WS-E5) — 2026-06-04

전체 비주얼 리디자인의 5축 재검토. Claude 비주얼(E5b) + Codex 코드레벨(E5c) 페어.

## E5c — Codex 코드레벨 리뷰 결과: REWORK → 수정 완료

| 축 | HIGH finding | 조치 |
|----|--------------|------|
| 대비 WCAG AA | bottom nav 선택 라벨 / 더보기 섹션 라벨 = amber #B8731A, light 소형텍스트 3.6:1 (4.5 미달) | `AppPalette.accentText(brightness)` 도입 — light=oakBrown(#5C3A1E ~9.5:1), dark=cask gold(~8:1). nav selectedLabelStyle + 섹션 라벨 적용 |
| 터치타깃 | home 최근 술 chip 부모 height 36 (48 미달) | height 48 + Center 정렬 |
| 다크 패리티 | brand illustration welcome 액체 하드코딩 Jim Beam amber → dark 2.28:1 | 테마 `scheme.primary` 사용 |
| 토큰화 | condition/home 하드코딩 spacing | AppSpacing/AppRadius/AppIcons 치환 |
| SoT | source_badge hex 재정의 / stats·condition 빈상태 generic | AppPalette.source* 사용 + 브랜드 EmptyStateWidget |

검증: amber #B8731A on white=3.81:1 / on cream=3.56:1 (대비 계산 확인) → AA 미달 사실 확인 후 수정.

## E5b — Claude 비주얼 리뷰 (스크린샷)

대상: home / more / log_list (다크). capture viewport(와이드)는 폰 비율과 다르나 레이아웃 검증 가능.

| 축 | 평가 |
|----|------|
| 1 비주얼 심미성 | PASS — 다크 위스키 테마, amber 강조, 카드/칩(pill)/네비 통일감 |
| 2 접근성/대비 | PASS(수정 후) — dark amber 충분, light 소형텍스트 accentText, 터치 48dp |
| 3 디자인시스템 일관성 | PASS — 토큰 + 컴포넌트 테마(Card/Chip/Button/Nav/Field) 통일 |
| 4 브랜드 아이덴티티 | PASS — 위스키 글래스 아이콘/일러스트/런처/스플래시/amber 팔레트 통일 |
| 5 UX/정보위계 | PASS — 월 그룹 헤더 / 섹션 라벨 / 타이포 위계(display~label) |

## 잔여 (LOW, 후속)
- home/archive/stats 일부 보조 간격 hardcoded magic 잔존 (기능/대비 무관 cosmetic). 점진 토큰화.
- 상태색(success/warning/error/info) dark 전용 토큰 미분기 (현재 light 값 공용). 사용처 적어 영향 낮음.

## 결론
HIGH/대비/터치/다크 패리티 finding 0 수렴. 리디자인 코드 품질 APPROVE.

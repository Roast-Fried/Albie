# Phase D — 시각 Identity 리브랜딩 plan

> UI/UX 평가 6 라운드 (`docs/analyze/2026-05-18-*.md`) 의 옵션 D 영역.
> Round 4 Pinterest reference 시각 비교 + Round 5 도메인 6색 팔레트 + Round 6 Agent X/Y/Z visual identity 통합.
>
> Audit 가 아닌 design decision 영역 — 사용자 결정 후 implementation.

---

## D1. 도메인 6색 팔레트 (Material 3 Theme extension)

### 현재 상태

- Seed `#8B5E3C` (위스키 브라운) 단일 — Material 3 derived color
- Phase 0 에서 source badge 4색 patch (WCAG AA)
- Phase 1 에서 pie chart white → black (contrast)
- 추가 accent 부재 — 화면 역할 구분 약함

### 권장 팔레트 (Round 4 + Round 5 도메인 매핑)

| 색 | Hex | 용도 | WCAG AA (light) | WCAG AA (dark) |
|---|---|---|---|---|
| **Whisky Brown** | `#8B5E3C` | primary anchor (기존) | 8.2:1 | 8.2:1 |
| **Amber Gold** | `#B25900` | liquor highlight / 기록 강조 | 4.5:1 | 5.4:1 (어두운 변형) |
| **Deep Burgundy** | `#6B2C3E` | wine accent | 7.8:1 | (변형 필요) |
| **Sage Green** | `#7FA39D` | non-alcoholic / 휴식 권장 | (확인 필요) | (확인 필요) |
| **Warm Orange** | `#A64D00` | beer/soju accent | 5.6:1 | (변형 필요) |
| **Teal** | `#006855` | 통계 / 분석 | 5.4:1 | (변형 필요) |

> **결정 필요**: 6색 확정 + Dark mode 변형 별도 정의 (Material 3 HCT 알고리즘 활용).

### Theme extension 정의

```dart
@immutable
class AlbiColors extends ThemeExtension<AlbiColors> {
  final Color liquorWhisky;   // amber gold
  final Color liquorWine;     // burgundy
  final Color liquorBeer;     // warm orange
  final Color liquorSoju;     // warm orange (variant)
  final Color liquorOther;    // teal
  final Color nonAlcoholic;   // sage green
  final Color statsAccent;    // teal

  const AlbiColors({...});

  static const AlbiColors light = AlbiColors(
    liquorWhisky: Color(0xFFB25900),
    ...
  );

  static const AlbiColors dark = AlbiColors(...);

  @override
  ThemeExtension<AlbiColors> copyWith(...) {...}

  @override
  ThemeExtension<AlbiColors> lerp(...) {...}
}
```

`AppTheme.light` / `AppTheme.dark` 에 `extensions: [AlbiColors.light]` 추가.

사용 위치:
- `entry_card_widget.dart` — drink category 별 카드 border 색
- `archive_screen.dart` FilterChip 색
- `stats_screen.dart` `_pieColors` 교체 (현재 hardcoded)
- 신규 mood emoji color / occasion icon color

### Effort

- Theme extension 정의: S (반나절)
- 모든 사용 위치 마이그레이션 (~10 files): M (1-2일)

---

## D2. Illustration 자산 10건

### 자산 list (Round 5 Agent A nominate)

| # | 자산 | 위치 | 크기 | 우선순위 |
|---|---|---|---|---|
| 1 | Onboarding hero — whisky bottle line drawing | `onboarding_page1` | 200×200px SVG | HIGH |
| 2 | Bottle icon (whisky) | category badge | 24×24px | MEDIUM |
| 3 | Mug icon (beer) | category badge | 24×24px | MEDIUM |
| 4 | Wine glass icon | category badge | 24×24px | MEDIUM |
| 5 | Shot glass icon (soju) | category badge | 24×24px | MEDIUM |
| 6 | Mood emoji set (5 변형: happy/neutral/sad/tired/excited) | tasting_note / draft_review | 32×32px × 5 | MEDIUM |
| 7 | Empty state illustration (sad face + sad glass) | home_empty, log_empty, archive_empty | 200×200px SVG | HIGH |
| 8 | Stats error illustration | stats_screen error state | 200×200px SVG | LOW |
| 9 | Albi logo monogram (bottle-shape) | app icon variants / splash | vector | LOW |
| 10 | Occasion sticker (혼술/회식/친구/가족/데이트) | draft_review occasion selector | 32×32px × 5 | LOW |

### 스타일 가이드

- **두께**: 2px stroke (sketch / line drawing 스타일)
- **색**: 위스키 brown + cream duotone (양각/음각)
- **각도**: minimal, geometric
- **아이덴티티**: Pinterest 송지나 일러스트 보드 reference — minimal, monogram-style

### 도구 / 도구 결정

**옵션 A — 직접 디자인** (Figma / Affinity Designer)
- 시간 비용: 2-3일 (10건 × 2-3h)
- 일관성 보장

**옵션 B — 디자이너 outsource**
- 비용: ~50-100만원 (한국 일러스트 작가 기준)
- 시간: 1-2주

**옵션 C — Stock + customization**
- Iconmonstr / Noun Project / Streamline 등
- license: Creative Commons 또는 paid
- Albi brand 일관성 부족 가능

> **권장**: D2 항목 1 + 7 + 6 (mood emoji) 우선 (옵션 A 직접 또는 사용자 디자이너). 나머지는 D1 적용 후 진행.

### Effort

- D2 항목 1, 7, 6 (priority 자산): M-L (3-5일)
- 나머지 항목: M (2-3일)

**총: L (1-2주)**

---

## D3. Splash Screen + App Icon 일관성

### 현재 상태

- iOS: AppIcon.appiconset 16 PNG 존재 (Round 3 Agent 8 정정)
- Android: mipmap-* 에 5 PNG 존재
- **iOS LaunchScreen.storyboard**: Flutter default (흰 배경)
- **Android launch_background.xml**: `<item android:drawable="@android:color/white" />`
- Brand identity (위스키 brown) 반영 X

### 권장 변경

- Android `launch_background.xml`: `<item android:drawable="@color/albi_brown" />` + 중앙 logo
- iOS `LaunchScreen.storyboard` (Xcode 편집): 배경 `#8B5E3C` + 중앙 logo monogram
- App 이름 일관성: `Albi` 또는 `알비` 통일 (현재 iOS `Albi`, Android `albi`, pubspec `albi`)

### Effort

- Android splash: S (반나절)
- iOS storyboard: S (반나절 — Xcode 직접 편집 필요)
- App 이름 통일: XS (10분)

**총: S-M (1-2일)**

---

## D4. 화면 별 visual identity 적용 mapping

| 화면 | D1 (color) | D2 (illustration) | 비고 |
|---|---|---|---|
| Onboarding p1 | brown anchor | 자산 1 (whisky bottle hero) | placeholder 교체 |
| Home empty | brown + cream | 자산 7 (sad glass empty) | "통계 오류" 영역 별도 처리 |
| Home with logs | brown + amber | category badge (자산 2-5) | log card 에 drink type icon |
| Draft review | category color border | mood emoji (자산 6) | entry card border 별 |
| Log list | category color | category icon | 월 헤더 + tile |
| Log detail | full palette | mood emoji + occasion (자산 10) | 풍부한 표현 |
| Archive | category color filter | drink type icon | FilterChip 색 |
| Stats | teal + brown | error illustration (자산 8) | pie + error |
| Settings | brown only | — | minimal |
| More | brown only | — | minimal |

---

## D5. 권장 진행 순서

### Phase D-1 (D1 + 자산 1,7) — HIGH ROI
1. AlbiColors Theme extension 정의 (S)
2. Onboarding hero illustration (자산 1)
3. Empty state illustration (자산 7) — home / log / archive 공통
4. Android splash + iOS LaunchScreen (D3)

### Phase D-2 (D2 자산 2-6 + D4 적용) — visual identity 확산
5. Drink category 4 icon (자산 2-5)
6. Mood emoji 5종 (자산 6)
7. 화면별 적용 (D4 mapping)

### Phase D-3 (마무리 — 여유 시) — polish
8. Stats error illustration (자산 8)
9. Logo monogram (자산 9) — app icon 통일
10. Occasion sticker (자산 10) — C3 (occasion enum) 후 작업

---

## 결정 필요 사항

- [ ] 6색 팔레트 hex 확정 (제안값 또는 다른 값)
- [ ] Dark mode 변형 알고리즘 (Material 3 HCT 활용 vs 수동 정의)
- [ ] Illustration 도구 선택 (직접 Figma / outsource / stock)
- [ ] Illustration 스타일 (line drawing vs flat color vs duotone)
- [ ] Brand mascot 도입 여부 (Albi 캐릭터)
- [ ] App 이름 통일 — `알비` 또는 `Albi` 선택
- [ ] Splash 배경 색 결정 (brown solid vs gradient)

---

## 관련 reference

- `docs/analyze/2026-05-18-ui-ux-evaluation.md` — Round 4 (Pinterest 시각 비교) 섹션
- `docs/analyze/2026-05-18-round5-stage1.md` — Agent A Pinterest 5 보드
- `docs/analyze/2026-05-18-round6.md` — Agent Z Material 3 HCT 한눈표
- `pinterest-dashboard-board.png`, `pinterest-visual-design-board.png`, `pinterest-illustration-board.png`, `pinterest-bulletjournal-board.png` (working tree, gitignore 대상 또는 commit 결정)

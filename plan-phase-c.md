# Plan: Phase C — 다크모드 선택 + 라이선스 + 온보딩 비주얼
> 날짜: 2026-04-23
> 상태: 완료
> 전제: B3 완료 (`6776612`). 와이어프레임 잔여 Low 항목 중 가치 높은 3건.

## 목표
설정 세부 2건 + 온보딩 비주얼 개선으로 와이어프레임 Phase C 의 실질적 Gap 마감.

## 비범위
- C-4 기본 수량 단위 — 실효성 낮아 생략 (제공 가치 대비 UI 복잡도)
- C-5 6시 컷오프 toggle — 현재 하드코딩으로 충분 (기본 ON)
- H-5 AI 로딩 취소 — dio CancelToken + orchestrator 인터페이스 변경 필요, 난이도/가치 고려 미루기
- L-6 영문 병기 in 기록 상세 — 이미 B2 에서 반영됨

## 변경 파일
| 파일 | 유형 | 설명 |
|------|------|------|
| lib/viewmodels/theme_mode_viewmodel.dart | **신규** | SharedPreferences 에 ThemeMode 저장 (system/light/dark) + `themeModeProvider` |
| lib/app.dart | 수정 | MaterialApp `themeMode: ref.watch(themeModeProvider)` |
| lib/views/settings/settings_screen.dart | 수정 | "일반" 섹션에 다크모드 선택 + 라이선스 링크 (C-3/C-8) |
| lib/views/onboarding/onboarding_screen.dart | 수정 | 각 페이지 내부를 카드/예시 블록/benefit 그리드로 리디자인 (O-1/O-2/O-3) |

## 구현 단계

### C1: 다크 모드 선택 (C-3)
- [ ] 1. `theme_mode_viewmodel.dart`:
  ```dart
  class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
    static const _key = 'theme_mode';
    @override
    Future<ThemeMode> build() async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      return switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }
    Future<void> setMode(ThemeMode mode) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
      ref.invalidateSelf();
    }
  }
  final themeModeProvider =
      AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
  ```
- [ ] 2. `app.dart` 의 `MaterialApp` 에 `themeMode: ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system`.
- [ ] 3. `settings_screen.dart` 에 "일반" 섹션 추가 — 다크 모드 현재 라벨 + tap 시 선택 다이얼로그 (시스템/라이트/다크 라디오).

### C2: 오픈소스 라이선스 (C-8)
- [ ] 4. `settings_screen.dart` 정보 섹션에 `ListTile("오픈소스 라이선스")` → `showLicensePage(context: context, applicationName: '알비', applicationVersion: '0.1.0')`.

### C3: 온보딩 비주얼 (O-1/O-2/O-3)
- [ ] 5. 페이지 1: 기존 "한 줄 입력으로 자동 정리" 문구 아래에 **예시 변환 블록** 추가:
  ```
  🗣 "글렌피딕 12 두 잔 마셨어"
         ↓
  🥃 글렌피딕 12년 · 2잔 · 위스키
  ```
- [ ] 6. 페이지 2: 기존 문구 아래 **2 카드 병렬** (로컬 파서/AI 파서) — Container + 색상 구분.
- [ ] 7. 페이지 3: "이제 시작해요" 아래 **3 benefit 그리드** (📊 통계 / 🗃 아카이브 / ✍️ 노트) — Row with 3 Cards.

### 검증
- [ ] 8. `flutter analyze` 0 issues
- [ ] 9. `flutter test --exclude-tags golden` 전체 통과
- [ ] 10. 수동: (a) 다크모드 3가지 전환, 앱 재시작 후 유지, (b) 라이선스 페이지 진입, (c) 온보딩 3페이지 시각적 확인

## 트레이드오프
| 선택지 | 장점 | 단점 | 결정 |
|--------|------|------|------|
| ThemeMode: AsyncNotifier vs StateNotifier+init | SharedPreferences async 자연스러움 | AsyncValue unwrap 번거로움 | **AsyncNotifier** — 초기화 깔끔 |
| 라이선스: showLicensePage vs 커스텀 | Flutter 내장, 라벨 자동 수집 | 영문 UI | **내장** — 과제 범위 내 충분 |
| 온보딩 비주얼: 카드 vs 완전 리디자인 | 카드는 작은 변경 | 와이어 수준 재현은 불가 | **카드 수준** — 과제 시간 대비 적정 |

## 위험 요소
- `themeModeProvider` 는 AsyncValue 라 valueOrNull 로 fallback 필요. MaterialApp 이 빌드될 때 null 이면 system 으로 default.
- 다크/라이트 강제 시 기존 NotoSansKR + ColorScheme.fromSeed 가 정상 렌더되는지 확인 (기본 Material 3 이라 OK 기대).
- 온보딩은 페이지 상태 유지 필요 없음 (1회성).

## 검증 기준 (Sprint Contract)
- [ ] `flutter analyze` 0 issues + `flutter test --exclude-tags golden` 통과
- [ ] 설정 일반 섹션에 다크모드 선택 (현재 라벨 표시, 3 옵션 다이얼로그)
- [ ] 재시작 후 저장된 모드 유지
- [ ] 정보 섹션에 라이선스 링크 → showLicensePage 정상 진입
- [ ] 온보딩 페이지 1/2/3 에 와이어 기준 비주얼 블록 (예시/카드/그리드) 노출

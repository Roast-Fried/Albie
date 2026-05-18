# Albi UI/UX Ultraplan — Round 5+ (미탐색 0 달성까지)

> **목표 (Goal hook 활성)**: 전체 디자인/UI/UX 객관적·비판적 평가. Codex 와 양방향 피드백. 미탐색 영역이 없을 때까지 반복.
>
> **진행 상태**: Round 1~4 완료 (~95 finding). Round 4 이후 Pinterest 대시보드 + 시각디자인 보드 캡처 비교 완료.
>
> **본 ultraplan 의 핵심**: Round 5+ 가 어떤 영역을 추가로 다룰지 enumerate + 양방향 피드백 protocol + 종결 조건 정의.

---

## Round 5+ 가 다룰 미탐색 영역 (사용자 추가 요청에 따른 expansion)

### A. 다른 송지나 Pinterest 보드 캡처 (Albi 화면별 관련)
- **발표자료 디자인** (393 핀) — Albi 의 Stats / Achievement / 회고 디자인 영향
- **제안서 디자인** (331 핀) — Albi 의 Onboarding / Settings 정보 구조 디자인
- **인포그래픽** (70 핀) — Albi 의 Stats / 통계 시각화 패턴
- **일러스트** (54 핀) — Albi 의 illustration / empty state / hero
- **블렛저널** (2829 핀) — Albi 의 기록 / journal UX 패턴

### B. 글로벌 음주 도메인 앱 web visual (가능한 한)
- Untappd / Vivino / Reframe / Drinkaware 의 marketing site / 스크린샷 페이지
- 한국 음주 앱 (배달의민족 우리집술상, 와인21 등) 비교

### C. 정량 contrast / accessibility 평가
- Albi golden 의 색상 pixel level 추출 → WCAG AA contrast ratio 계산
- 위스키 brown 텍스트 vs 베이지 배경 (실측 vs 권장 4.5:1)
- 다크 모드 시뮬레이션 (theme 코드 기반 색상 mapping)

### D. Motion / Animation 우선순위 prototype
- Round 3 finding 의 "Hero / fade / sheet" 중 어떤 적용이 ROI 가장 높은지
- 실 구현 시 효과 예측 (mockup with text description)

### E. Finding cluster 분석 + ROI 매트릭스
- Round 1~4 의 ~95 finding 을 cluster 화 → 같은 root cause 그룹
- ROI = 영향 사용자 수 × 심각도 / 구현 effort 사이즈

### F. 사용자 task 시나리오별 시각 friction 매핑
- 시나리오 1: 신규 사용자 첫 기록 (onboarding → home → input → review → save → list)
- 시나리오 2: 기존 사용자 빠른 기록 (home → input → save)
- 시나리오 3: 통계 확인 (home → more → stats)
- 시나리오 4: 과거 기록 검색·수정 (log list → detail → edit → save)
- 각 시나리오에 시각 friction 누적 평가

### G. AI 사용 / 비사용 시 시각 분기
- AI ON 상태 vs OFF 상태의 화면 시각 차이 (현재 코드 기반 추론)
- 사용자가 AI 상태 즉시 인지 가능한가? (badge / banner / icon)

### H. Korean UX 표준 vs 글로벌 표준 시각 분기
- Round 2 에서 Korean UX (Toss / 배민) 패턴 다룸. 정량 visual gap 추가
- 한국 사용자 기대치 vs 글로벌 시각 트렌드 차이

---

## Round 5+ 진행 protocol (Codex 양방향 피드백)

### Stage 1 — Round 5 fan-out (3 agent)
- Claude Agent A: Pinterest 추가 보드 (B/D/E) 캡처 + 분석
- Claude Agent B: Albi golden 색상 pixel 추출 + WCAG contrast 계산
- Codex Agent C: 시나리오별 시각 friction 매핑 + cluster 분석

### Stage 2 — Codex Cross-feedback
- Codex 가 Stage 1 의 Claude 결과를 받아 검토 + counter finding emit
- 같은 finding 의 다른 해석 / 우선순위 다툼 / 추가 영역 제안

### Stage 3 — Claude Cross-feedback
- Claude 가 Codex Stage 2 결과를 받아 검토 + 보완
- Codex finding 의 false positive / blind spot 식별

### Stage 4 — Saturation 평가
- 양 측 모두 새로운 finding 0건이면 saturation 도달
- 사용자가 명시 추가 요청 없으면 종결

### 종결 조건 (미탐색 0)
1. Codex + Claude 둘 다 "이 라운드에서 새로운 finding 0건" 명시
2. 또는 사용자 명시 중단

---

## 진행 로그 위치

- 본 ultraplan: `docs/analyze/2026-05-18-ultraplan-rounds-5plus.md`
- 진행 로그: `docs/analyze/2026-05-18-progress-log.md` (라운드별 timestamped entry)
- 최종 통합: `docs/analyze/2026-05-18-ui-ux-evaluation.md` (기존 리포트 업데이트)

---

## Round 5 즉시 진행 항목

1. Pinterest 추가 보드 5개 캡처 (발표자료 / 제안서 / 인포그래픽 / 일러스트 / 블렛저널)
2. Albi golden 색상 pixel 추출 (`mcp__playwright__browser_evaluate` 활용 또는 image 분석)
3. 3 agent fan-out (Claude × 2 + Codex × 1)
4. Codex cross-feedback (Stage 2)
5. Claude cross-feedback (Stage 3)
6. Saturation 평가
7. Round 6 필요시 진행

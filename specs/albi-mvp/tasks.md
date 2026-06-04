# Albi MVP — Tasks (SDD)

> `plan.md`의 task 분해. 강의 Spec-Kit `tasks` 단계 대응. ✅=완료 / ⬜=진행.

## T1. 기반 (완료)
- ✅ Flutter 프로젝트 + MVVM + Riverpod 골격
- ✅ sqflite 8테이블 + 트랜잭션/FK/인덱스/마이그레이션
- ✅ 시드 로더 (liquor_master 553 + food + place)
- ✅ sealed AppError + 에러 위젯

## T2. 핵심 기능 (완료)
- ✅ AI 연결 관리 (secure storage + 모델 선택 + 사용량 quota)
- ✅ 자연어 입력 → ParseOrchestrator (AI / 로컬 fallback)
- ✅ 초안 검토·수정·저장 (자동저장 금지, 트랜잭션 CRUD)
- ✅ 테이스팅 노트 (향/맛/피니시/평점)
- ✅ 마셔본 술 아카이브 (집계 + 즐겨찾기 + 별칭 + 히스토리)

## T3. 선택 기능 (완료)
- ✅ 음식 태그 · 사진 첨부 · AI 이미지 보조 · AI 노트 보완
- ✅ 업적/게이미피케이션 · 통계(fl_chart 파이/라인 + 기간 탭 + TOP5)
- ✅ 음주 캘린더 (table_calendar) · 클라우드 백업(Supabase opt-in)
- ✅ 리스트/페이지 애니메이션 · 로컬 알림 4시나리오

## T4. 강의 정합 — 이전 사이클 (완료, 2026-06-02)
- ✅ Named Routes + onGenerateRoute 중앙 라우팅 + RouteErrorScreen
- ✅ `.env` 인프라 (flutter_dotenv)
- ✅ 캘린더 / Supabase / 애니메이션 (강의 기반 추가)

## T5. 강의 정합 — 본 사이클 (2026-06-04 SDD)
- ✅ **WS-A Drift 격리 데모** (컨디션 로그): 테이블/DAO/build_runner/watch/StreamBuilder/FutureBuilder + DAO 테스트 6 + 격리 검증 + `docs/drift-vs-sqflite.md`
- ✅ **WS-B Spec-Kit 산출물**: spec/plan/tasks/test.md
- ✅ **WS-C 학습성찰** + 강의개념↔코드 매핑 + 필기 요약
- ✅ **WS-E1** 디자인 토큰 (app_tokens + 테마 확장)
- ✅ **WS-E2** 런처 아이콘 + 스플래시 + 알림 아이콘
- ✅ **WS-E3** 아이콘 토큰(AppIcons) + CustomPainter 브랜드 일러스트
- 🔄 **WS-E4** 화면 리디자인 (1차: 빈상태/더보기/온보딩 완료, 나머지 진행)
- 🔄 **WS-E5** 다방면 디자인 재검토 (캡처 + Codex 5축 진행)
- ⬜ **WS-E6** 골든 갱신 + 최종 검증
- (E0 selector: 라벨·IconData 보존 + AppIcons 동일 매핑으로 충족 — 테스트 대량 재작성 회피)

## T6. 품질
- ✅ unit/widget 테스트 138 + golden 4 + integration capture
- ⬜ 리디자인 후 golden 재생성 + capture 재검증
- ⬜ (가능 시) device e2e

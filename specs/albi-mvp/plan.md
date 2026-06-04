# Albi MVP — Technical Plan (SDD)

> `spec.md`의 기술 구현 계획. 강의 Spec-Kit `plan` 단계 대응.

## 1. 기술 스택

- **프레임워크**: Flutter (Dart SDK ^3.11), Material 3.
- **상태관리**: Riverpod (StateNotifier / AsyncNotifier / FutureProvider / StateProvider / family).
- **메인 DB**: raw sqflite (8테이블, 트랜잭션/FK/인덱스/마이그레이션 직접 구현).
- **데모 DB**: Drift (격리 모듈 — 컨디션 로그, watch reactive). → `docs/drift-vs-sqflite.md`.
- **설정 저장**: shared_preferences (온보딩/테마/기본단위/6시컷오프).
- **보안 저장**: flutter_secure_storage (Gemini API Key).
- **AI**: Gemini REST (dio) + 로컬 규칙 파서 fallback.
- **클라우드(opt-in)**: supabase_flutter (이메일 인증 + 백업/복원, `.env` 미설정 시 dormant).
- **기타**: fl_chart(통계), table_calendar(캘린더), flutter_local_notifications+timezone(알림), image_picker(사진), intl(포맷), flutter_dotenv(.env).

## 2. 아키텍처 — MVVM + Riverpod

```
View (ConsumerWidget)
  → ViewModel (StateNotifier/AsyncNotifier, Riverpod provider)
    → Repository (sqflite 직접) / Integrations (parser, gemini, supabase, drift_demo)
      → Model (domain/entities)
```

- **규칙**: View는 Repository 직접 접근 금지(ViewModel 경유). AI 로직은 `integrations/parser`에만. 구현체 1개면 인터페이스 없음.
- **에러**: sealed `AppError`(Database/Network/Parse/Validation). write 경계만 try-catch, read는 raw 통과.
- **provider**: autoDispose 미사용 기본(IndexedStack 3탭 유지).

## 3. 데이터 설계

- 메인 sqflite 8테이블: drinkLog, drinkEntry, drinkLogFood, liquorMaster, tastingNote, parseJob, aiConfig, usageQuota.
- Drift 데모 1테이블: conditionLogs (격리 `albi_condition.sqlite`).
- 시드: liquor_master 553종 + food_dictionary 36 + place_keywords.

## 4. 라우팅
- 3탭(홈/기록/더보기) IndexedStack 유지.
- 보조 화면은 Named Routes + `onGenerateRoute` 중앙 라우팅(`app_routes.dart`) + 인자 타입검증 + RouteErrorScreen fallback (EffectiveNavigator 강의 패턴).

## 5. 데이터 흐름
입력 → ParseOrchestrator (AI 가능? GeminiTextParser : LocalRuleParser) → ParseResult → DraftReviewScreen(검토/수정) → DrinkLogRepository.save()(트랜잭션) → 홈/목록/아카이브/통계/캘린더 갱신 → (설정 따라) 알림 재스케줄.

## 6. 비동기 UI 패턴
- 주: Riverpod `AsyncValue.when`(로딩/에러/데이터).
- 강의 시연: 컨디션 로그 화면에서 Drift `watch()` + **StreamBuilder**, 평균 숙취도 **FutureBuilder**(setState 재실행).

## 7. 디자인 시스템 (본 사이클 리디자인)
- `app_tokens.dart`(spacing/radius/typography/semantic color) + `app_theme.dart`(컴포넌트 테마) + `app_icons.dart`(아이콘 토큰).
- 위스키 컨셉(Light: Jim Beam amber / Dark: Arran cask) 유지·고도화.
- 런처 아이콘/스플래시(flutter_launcher_icons/native_splash) + 빈상태 일러스트(flutter_svg).

## 8. 품질 게이트
- `flutter analyze` 0 · `flutter test --exclude-tags golden` green · golden green · integration capture.
- Codex 페어 리뷰 게이트(워크스트림별).
- 강의 디자인 워크플로우(Stitch→Claude Design→Figma) 정합 + 다방면 디자인 재검토(5축).

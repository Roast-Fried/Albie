# 클라우드 백업(Supabase) 설정 가이드

알비는 기본적으로 **로컬 전용**으로 동작합니다. 아래 설정을 마치면 이메일 로그인 후
음주 기록을 클라우드에 백업하고, 다른 기기에서 복원할 수 있습니다.

> 설정하지 않아도 앱의 모든 기능은 그대로 동작합니다(클라우드 메뉴만 "미설정" 표시).

## 1. Supabase 프로젝트 만들기

1. https://supabase.com 에서 무료 프로젝트 생성
2. 프로젝트 > **Settings → API** 에서 다음 두 값 복사
   - `Project URL`  → `SUPABASE_URL`
   - `anon public` key → `SUPABASE_ANON_KEY`

> `anon` 키는 클라이언트 공개 키입니다. RLS(아래 SQL)가 데이터를 보호하므로
> 앱에 포함되어도 안전합니다. (절대 `service_role` 키는 사용하지 마세요.)

## 2. 테이블 + 보안 정책 생성

프로젝트 > **SQL Editor** 에서 [docs/supabase-schema.sql](supabase-schema.sql) 전체를
붙여넣고 실행하세요. `drink_backups` 테이블과 RLS 정책이 생성됩니다.

## 3. 이메일 인증 설정

- 빠르게 쓰려면 **Authentication → Providers → Email** 에서 "Confirm email" 을 끄면
  가입 즉시 로그인됩니다.
- 켜 둔 경우 가입 후 메일 인증을 완료해야 로그인됩니다.

## 4. `.env` 채우기

프로젝트 루트의 `.env` 파일을 열어 값을 채웁니다:

```
SUPABASE_URL=https://xxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
```

> **보안 안내**: `.env` 는 git 에 추적되는 템플릿입니다. 하지만 여기 들어가는
> `SUPABASE_ANON_KEY` 는 Supabase 가 클라이언트 공개용으로 설계한 키이고 RLS 가
> 데이터를 보호하므로 커밋되어도 안전합니다. 비밀 키(Gemini 등)는 절대 `.env` 에
> 넣지 마세요 — 앱 내 설정에서 입력합니다.
>
> 그래도 개인 값을 커밋하기 싫다면:
> `git update-index --skip-worktree .env` (로컬 변경을 git 이 무시) 또는
> `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` 빌드 인자 사용
> (`.env` 보다 우선순위 낮음 → `.env` 가 비어 있을 때 적용).

## 5. 다시 빌드 → 사용

앱을 다시 빌드/실행한 뒤 **더보기 → 설정 → 클라우드 백업·동기화** 로 이동:

1. 이메일/비밀번호로 **로그인**(또는 새 계정 만들기)
2. **지금 백업하기** — 현재 기기의 모든 기록을 클라우드에 저장
3. 다른 기기에서 같은 계정으로 로그인 후 **클라우드에서 복원하기**

## 동작 원리(offline-first)

- 로컬 SQLite 가 항상 SoT(원본)입니다. 클라우드는 사용자당 1행 스냅샷 백업입니다.
- 네트워크 오류가 나도 로컬 데이터는 손상되지 않습니다(배너로만 안내).
- "복원"은 현재 기기 기록을 클라우드 백업으로 **교체**합니다(확인 후 진행).

## 범위(의도적 제외)

- 실시간 동기화 / 친구·공유 / 소셜 로그인은 음주 기록 앱 범위를 벗어나 제외했습니다.
- 백업 대상은 음주 기록(기록·항목·음식)입니다.

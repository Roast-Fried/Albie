-- 알비(Albi) 클라우드 백업 — Supabase 테이블 + RLS
-- ───────────────────────────────────────────────────────────
-- Supabase 프로젝트 > SQL Editor 에서 아래 전체를 1회 실행하세요.
-- 사용자당 1행(스냅샷)을 보관하며, RLS 로 "본인 행만" 접근 가능합니다.

create table if not exists public.drink_backups (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  payload    jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.drink_backups enable row level security;

-- 본인(auth.uid()) 행만 읽기/삽입/수정 허용.
-- anon key 는 공개되지만 RLS 가 데이터를 보호합니다.
create policy "own_backup_select" on public.drink_backups
  for select using (auth.uid() = user_id);

create policy "own_backup_insert" on public.drink_backups
  for insert with check (auth.uid() = user_id);

create policy "own_backup_update" on public.drink_backups
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- In-app feedback rows for operator dashboard (read with service role or future admin policy).

create table if not exists public.app_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  shop_id uuid references public.shops (id) on delete set null,
  category text not null,
  subject text not null,
  message text not null,
  body_context text,
  app_version text,
  platform text,
  created_at timestamptz not null default now()
);

create index if not exists idx_app_feedback_created_at
  on public.app_feedback (created_at desc);

create index if not exists idx_app_feedback_shop_id
  on public.app_feedback (shop_id);

alter table public.app_feedback enable row level security;

-- Mobile/web clients: insert only for the signed-in user (includes anonymous auth).
drop policy if exists app_feedback_insert_own on public.app_feedback;
create policy app_feedback_insert_own
  on public.app_feedback
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- No select/update/delete for app clients; operators read via Supabase Dashboard (service role)
-- or a future admin app authenticated with the service role / dedicated admin policy.

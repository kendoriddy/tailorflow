-- Global plan limits (admin edits in Supabase Table Editor or SQL).
-- All signed-in shops read the same limits; only service_role can write.

create table if not exists public.platform_config (
  key text primary key,
  value text not null,
  description text,
  updated_at timestamptz not null default now()
);

insert into public.platform_config (key, value, description)
values
  (
    'free_tier_max_customers',
    '50',
    'Max active customers (deleted_at IS NULL) on free tier before paywall.'
  ),
  (
    'free_tier_whatsapp_monthly_limit',
    '10',
    'WhatsApp handoffs per calendar month on free tier. Use -1 for unlimited.'
  )
on conflict (key) do nothing;

alter table public.platform_config enable row level security;

drop policy if exists platform_config_select_authenticated
  on public.platform_config;
create policy platform_config_select_authenticated
  on public.platform_config
  for select
  to authenticated
  using (true);

-- No insert/update/delete policies for authenticated users:
-- change limits as project admin (service role) in Supabase dashboard.

-- Paystack subscription state per shop (updated by Edge Functions / webhooks).

alter table public.shops
  add column if not exists subscription_status text not null default 'free',
  add column if not exists subscription_plan text,
  add column if not exists paystack_subscription_code text,
  add column if not exists paystack_customer_code text,
  add column if not exists subscription_period_end timestamptz,
  add column if not exists subscription_updated_at timestamptz;

comment on column public.shops.subscription_status is
  'free | active | cancelled | past_due';
comment on column public.shops.subscription_plan is 'monthly | yearly';

create table if not exists public.paystack_checkout_sessions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  reference text not null unique,
  plan text not null check (plan in ('monthly', 'yearly')),
  amount_kobo integer not null,
  status text not null default 'pending' check (status in ('pending', 'completed', 'failed')),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists idx_paystack_checkout_shop
  on public.paystack_checkout_sessions (shop_id);

alter table public.paystack_checkout_sessions enable row level security;

drop policy if exists paystack_checkout_member_select on public.paystack_checkout_sessions;
create policy paystack_checkout_member_select
  on public.paystack_checkout_sessions
  for select
  to authenticated
  using (
    user_id = auth.uid()
    and shop_id = public.current_shop_id()
  );

-- Display pricing (optional; app also has constants).
insert into public.platform_config (key, value, description)
values
  (
    'subscription_monthly_ngn',
    '2000',
    'Monthly subscription price in Naira (Paystack plan must match).'
  ),
  (
    'subscription_yearly_ngn',
    '19800',
    'Yearly subscription price in Naira (Paystack plan must match).'
  )
on conflict (key) do update set
  value = excluded.value,
  description = excluded.description,
  updated_at = now();

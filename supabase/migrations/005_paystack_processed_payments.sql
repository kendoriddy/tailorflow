-- Idempotency guard for Paystack charge.success events that do not have a
-- TailorFlow checkout session, such as recurring subscription renewals.

create table if not exists public.paystack_processed_payments (
  reference text primary key,
  shop_id uuid not null references public.shops (id) on delete cascade,
  event text not null,
  processed_at timestamptz not null default now()
);

create index if not exists idx_paystack_processed_payments_shop
  on public.paystack_processed_payments (shop_id);

create index if not exists idx_shops_paystack_subscription_code
  on public.shops (paystack_subscription_code)
  where paystack_subscription_code is not null;

create index if not exists idx_shops_paystack_customer_code
  on public.shops (paystack_customer_code)
  where paystack_customer_code is not null;

alter table public.paystack_processed_payments enable row level security;

create or replace function public.activate_paystack_processed_payment(
  p_reference text,
  p_shop_id uuid,
  p_event text,
  p_plan text,
  p_paystack_subscription_code text,
  p_paystack_customer_code text,
  p_period_end timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_plan not in ('monthly', 'yearly') then
    raise exception 'Invalid subscription plan: %', p_plan;
  end if;

  insert into public.paystack_processed_payments (reference, shop_id, event)
  values (p_reference, p_shop_id, p_event)
  on conflict (reference) do nothing;

  if not found then
    return false;
  end if;

  update public.shops
  set
    subscription_status = 'active',
    subscription_plan = p_plan,
    paystack_subscription_code = coalesce(
      p_paystack_subscription_code,
      paystack_subscription_code
    ),
    paystack_customer_code = coalesce(
      p_paystack_customer_code,
      paystack_customer_code
    ),
    subscription_period_end = p_period_end,
    subscription_updated_at = now()
  where id = p_shop_id;

  if not found then
    raise exception 'Shop not found: %', p_shop_id;
  end if;

  return true;
end;
$$;

revoke all on function public.activate_paystack_processed_payment(
  text,
  uuid,
  text,
  text,
  text,
  text,
  timestamptz
) from public;
grant execute on function public.activate_paystack_processed_payment(
  text,
  uuid,
  text,
  text,
  text,
  text,
  timestamptz
) to service_role;

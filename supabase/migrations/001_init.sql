-- TailorFlow NG Supabase bootstrap:
-- - shop-scoped multi-tenant schema
-- - auth-based row-level security
-- - helper RPC to auto-provision shop membership per signed-in user

create extension if not exists pgcrypto;

-- Tenancy tables
create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.shop_memberships (
  user_id uuid not null references auth.users(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  role text not null default 'owner',
  created_at timestamptz not null default now(),
  primary key (user_id, shop_id)
);

create index if not exists idx_shop_memberships_user_id
  on public.shop_memberships(user_id);
create index if not exists idx_shop_memberships_shop_id
  on public.shop_memberships(shop_id);

-- Helper: current user shop id from membership
create or replace function public.current_shop_id()
returns uuid
language sql
stable
as $$
  select m.shop_id
  from public.shop_memberships m
  where m.user_id = auth.uid()
  order by m.created_at asc
  limit 1;
$$;

-- Provision shop + membership for current signed-in user (idempotent)
create or replace function public.bootstrap_current_user_shop()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_shop uuid;
begin
  if v_user is null then
    raise exception 'Not authenticated';
  end if;

  select m.shop_id
  into v_shop
  from public.shop_memberships m
  where m.user_id = v_user
  limit 1;

  if v_shop is null then
    insert into public.shops(name)
    values ('My Shop')
    returning id into v_shop;

    insert into public.shop_memberships(user_id, shop_id, role)
    values (v_user, v_shop, 'owner')
    on conflict do nothing;
  end if;

  return v_shop;
end;
$$;

revoke all on function public.bootstrap_current_user_shop() from public;
grant execute on function public.bootstrap_current_user_shop() to authenticated;

-- Business tables (shop-scoped)
create table if not exists public.customers (
  id text primary key,
  shop_id uuid not null default public.current_shop_id()
    references public.shops (id) on delete restrict,
  name text not null,
  phone text,
  phone_norm text not null default '',
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint
);

create table if not exists public.measurement_profiles (
  id text primary key,
  shop_id uuid not null default public.current_shop_id()
    references public.shops (id) on delete restrict,
  customer_id text not null references public.customers (id) on delete cascade,
  label text not null,
  chest double precision,
  waist double precision,
  hip double precision,
  length double precision,
  sleeve double precision,
  shoulder double precision,
  neck double precision,
  inseam double precision,
  notes text,
  updated_at bigint not null
);

create table if not exists public.orders (
  id text primary key,
  shop_id uuid not null default public.current_shop_id()
    references public.shops (id) on delete restrict,
  customer_id text not null references public.customers (id) on delete cascade,
  title text not null,
  fabric_note text,
  due_date bigint not null,
  status text not null,
  agreed_amount_ngn bigint not null,
  created_at bigint not null,
  updated_at bigint not null
);

create table if not exists public.payments (
  id text primary key,
  shop_id uuid not null default public.current_shop_id()
    references public.shops (id) on delete restrict,
  order_id text not null references public.orders (id) on delete cascade,
  amount_ngn bigint not null,
  paid_at bigint not null,
  note text
);

-- Bring older schemas forward safely
alter table public.customers add column if not exists shop_id uuid;
alter table public.measurement_profiles add column if not exists shop_id uuid;
alter table public.orders add column if not exists shop_id uuid;
alter table public.payments add column if not exists shop_id uuid;
alter table public.measurement_profiles add column if not exists hip double precision;

do $$
begin
  begin
    alter table public.customers
      alter column shop_id set default public.current_shop_id();
  exception when others then null;
  end;
  begin
    alter table public.measurement_profiles
      alter column shop_id set default public.current_shop_id();
  exception when others then null;
  end;
  begin
    alter table public.orders
      alter column shop_id set default public.current_shop_id();
  exception when others then null;
  end;
  begin
    alter table public.payments
      alter column shop_id set default public.current_shop_id();
  exception when others then null;
  end;
end $$;

-- Ensure every existing row has a shop_id
do $$
declare
  v_legacy uuid;
begin
  select id into v_legacy from public.shops order by created_at asc limit 1;
  if v_legacy is null then
    insert into public.shops(name) values ('Legacy Shop') returning id into v_legacy;
  end if;

  update public.customers
  set shop_id = v_legacy
  where shop_id is null;

  update public.measurement_profiles mp
  set shop_id = c.shop_id
  from public.customers c
  where mp.customer_id = c.id
    and mp.shop_id is null;

  update public.orders o
  set shop_id = c.shop_id
  from public.customers c
  where o.customer_id = c.id
    and o.shop_id is null;

  update public.payments p
  set shop_id = o.shop_id
  from public.orders o
  where p.order_id = o.id
    and p.shop_id is null;
end $$;

-- Optional guard: prevent cross-shop links
create or replace function public.enforce_same_shop_relationships()
returns trigger
language plpgsql
as $$
begin
  if TG_TABLE_NAME = 'measurement_profiles' then
    if not exists (
      select 1 from public.customers c
      where c.id = NEW.customer_id
        and c.shop_id = NEW.shop_id
    ) then
      raise exception 'measurement_profiles.customer_id must belong to same shop_id';
    end if;
  elsif TG_TABLE_NAME = 'orders' then
    if not exists (
      select 1 from public.customers c
      where c.id = NEW.customer_id
        and c.shop_id = NEW.shop_id
    ) then
      raise exception 'orders.customer_id must belong to same shop_id';
    end if;
  elsif TG_TABLE_NAME = 'payments' then
    if not exists (
      select 1 from public.orders o
      where o.id = NEW.order_id
        and o.shop_id = NEW.shop_id
    ) then
      raise exception 'payments.order_id must belong to same shop_id';
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_measurement_profiles_same_shop on public.measurement_profiles;
create trigger trg_measurement_profiles_same_shop
before insert or update on public.measurement_profiles
for each row execute function public.enforce_same_shop_relationships();

drop trigger if exists trg_orders_same_shop on public.orders;
create trigger trg_orders_same_shop
before insert or update on public.orders
for each row execute function public.enforce_same_shop_relationships();

drop trigger if exists trg_payments_same_shop on public.payments;
create trigger trg_payments_same_shop
before insert or update on public.payments
for each row execute function public.enforce_same_shop_relationships();

-- Indexes
create index if not exists idx_customers_shop_id on public.customers(shop_id);
create index if not exists idx_customers_phone_norm on public.customers(phone_norm);
create index if not exists idx_customers_name on public.customers(name);
create index if not exists idx_measurement_profiles_shop_id
  on public.measurement_profiles(shop_id);
create index if not exists idx_orders_shop_id on public.orders(shop_id);
create index if not exists idx_orders_customer_id on public.orders(customer_id);
create index if not exists idx_orders_due_date on public.orders(due_date);
create index if not exists idx_payments_shop_id on public.payments(shop_id);
create index if not exists idx_payments_order_id on public.payments(order_id);

-- Enforce not-null after backfill
alter table public.customers alter column shop_id set not null;
alter table public.measurement_profiles alter column shop_id set not null;
alter table public.orders alter column shop_id set not null;
alter table public.payments alter column shop_id set not null;

-- RLS
alter table public.shops enable row level security;
alter table public.shop_memberships enable row level security;
alter table public.customers enable row level security;
alter table public.measurement_profiles enable row level security;
alter table public.orders enable row level security;
alter table public.payments enable row level security;

drop policy if exists shops_member_select on public.shops;
create policy shops_member_select
on public.shops
for select
to authenticated
using (
  exists (
    select 1 from public.shop_memberships m
    where m.shop_id = shops.id
      and m.user_id = auth.uid()
  )
);

drop policy if exists shop_memberships_member_select on public.shop_memberships;
create policy shop_memberships_member_select
on public.shop_memberships
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists customers_shop_scope on public.customers;
create policy customers_shop_scope
on public.customers
for all
to authenticated
using (
  exists (
    select 1 from public.shop_memberships m
    where m.user_id = auth.uid()
      and m.shop_id = customers.shop_id
  )
)
with check (
  exists (
    select 1 from public.shop_memberships m
    where m.user_id = auth.uid()
      and m.shop_id = customers.shop_id
  )
);

drop policy if exists measurement_profiles_shop_scope on public.measurement_profiles;
create policy measurement_profiles_shop_scope
on public.measurement_profiles
for all
to authenticated
using (
  exists (
    select 1 from public.shop_memberships m
    where m.user_id = auth.uid()
      and m.shop_id = measurement_profiles.shop_id
  )
)
with check (
  exists (
    select 1 from public.shop_memberships m
    where m.user_id = auth.uid()
      and m.shop_id = measurement_profiles.shop_id
  )
);

drop policy if exists orders_shop_scope on public.orders;
create policy orders_shop_scope
on public.orders
for all
to authenticated
using (
  exists (
    select 1 from public.shop_memberships m
    where m.user_id = auth.uid()
      and m.shop_id = orders.shop_id
  )
)
with check (
  exists (
    select 1 from public.shop_memberships m
    where m.user_id = auth.uid()
      and m.shop_id = orders.shop_id
  )
);

drop policy if exists payments_shop_scope on public.payments;
create policy payments_shop_scope
on public.payments
for all
to authenticated
using (
  exists (
    select 1 from public.shop_memberships m
    where m.user_id = auth.uid()
      and m.shop_id = payments.shop_id
  )
)
with check (
  exists (
    select 1 from public.shop_memberships m
    where m.user_id = auth.uid()
      and m.shop_id = payments.shop_id
  )
);

-- Example Supabase schema for TailorFlow NG (adjust to your tenancy model).
-- Enable RLS and tighten policies before production.

create table if not exists public.customers (
  id text primary key,
  name text not null,
  phone text,
  phone_norm text not null default '',
  created_at bigint not null,
  updated_at bigint not null,
  deleted_at bigint
);

create table if not exists public.measurement_profiles (
  id text primary key,
  customer_id text not null references public.customers (id) on delete cascade,
  label text not null,
  chest double precision,
  waist double precision,
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
  order_id text not null references public.orders (id) on delete cascade,
  amount_ngn bigint not null,
  paid_at bigint not null,
  note text
);

-- TODO: add shop_id to each table and scope policies to auth.uid() -> shop_id mapping.

alter table public.customers enable row level security;
alter table public.measurement_profiles enable row level security;
alter table public.orders enable row level security;
alter table public.payments enable row level security;

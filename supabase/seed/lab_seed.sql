-- Optional lab seed for victim tenant (run in SQL Editor with service role).
-- 1. Replace VICTIM_SHOP_UUID below with victim's shop_id from shop_memberships.
-- 2. Do NOT run on production.

-- \set victim_shop_id '00000000-0000-0000-0000-000000000001'

insert into public.customers (
  id, shop_id, name, phone, phone_norm,
  birth_day, birth_month, birth_year, birthday_consent,
  created_at, updated_at, deleted_at
) values (
  'lab-customer-attacker-001',
  '6d2cc7ad-a935-42dc-8c8c-e3b5027b98ad'::uuid,
  'Musa Ojo',
  '+2348000000010',
  '2348000000010',
  15, 6, 1990, 0,
  extract(epoch from now())::bigint * 1000,
  extract(epoch from now())::bigint * 1000,
  null
) on conflict (id) do nothing;

insert into public.measurement_profiles (
  id, shop_id, customer_id, label,
  chest, waist, hip, length, sleeve, shoulder, neck, inseam, notes, updated_at
) values (
  'lab-measure-attacker-001',
  '6d2cc7ad-a935-42dc-8c8c-e3b5027b98ad'::uuid,
  'lab-customer-attacker-001',
  'Default',
  36, 30, 38, 42, 24, 16, 14, 30, 'Lab seed measurement',
  extract(epoch from now())::bigint * 1000
) on conflict (id) do nothing;

insert into public.orders (
  id, shop_id, customer_id, title, fabric_note, due_date, status,
  agreed_amount_ngn, created_at, updated_at
) values (
  'lab-order-attacker-001',
  '6d2cc7ad-a935-42dc-8c8c-e3b5027b98ad'::uuid,
  'lab-customer-attacker-001',
  'Lab Agbada',
  'Navy cotton',
  (extract(epoch from now())::bigint + 86400000) * 1000,
  'in_progress',
  85000,
  extract(epoch from now())::bigint * 1000,
  extract(epoch from now())::bigint * 1000
) on conflict (id) do nothing;

insert into public.payments (
  id, shop_id, order_id, amount_ngn, paid_at, note
) values (
  'lab-payment-attacker-001',
  '6d2cc7ad-a935-42dc-8c8c-e3b5027b98ad'::uuid,
  'lab-order-attacker-001',
  30000,
  extract(epoch from now())::bigint * 1000,
  'Lab deposit'
) on conflict (id) do nothing;

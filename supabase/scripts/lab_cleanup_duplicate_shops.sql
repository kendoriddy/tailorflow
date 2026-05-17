-- One-time lab cleanup: user with multiple shop_memberships rows (duplicate bootstrap).
-- Run in Supabase SQL Editor. Review output before deleting.

-- 1) Find users with more than one shop
select
  u.email,
  m.user_id,
  count(*) as shop_count,
  array_agg(m.shop_id order by m.created_at) as shop_ids
from auth.users u
join public.shop_memberships m on m.user_id = u.id
group by u.email, m.user_id
having count(*) > 1;

-- 2) Per duplicate user: see which shop has data (keep oldest membership usually)
-- Replace :user_id with the attacker's uuid from step 1
/*
select s.id as shop_id, s.created_at,
  (select count(*) from public.customers c where c.shop_id = s.id) as customers,
  (select count(*) from public.orders o where o.shop_id = s.id) as orders
from public.shop_memberships m
join public.shops s on s.id = m.shop_id
where m.user_id = ':user_id'
order by m.created_at;
*/

-- 3) Delete empty duplicate shop (ONLY if that shop has zero customers/orders)
-- Example — adjust UUIDs after reviewing step 2:
/*
delete from public.shop_memberships
where user_id = ':user_id'
  and shop_id = ':empty_shop_id_to_remove';
delete from public.shops
where id = ':empty_shop_id_to_remove'
  and not exists (select 1 from public.shop_memberships m where m.shop_id = shops.id);
*/

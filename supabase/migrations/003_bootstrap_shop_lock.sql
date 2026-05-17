-- Prevent duplicate shops per user when bootstrap runs concurrently (signup + sync + main).

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

  -- Serialize bootstrap per user (signup + sync + app start can race).
  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));

  select m.shop_id
  into v_shop
  from public.shop_memberships m
  where m.user_id = v_user
  order by m.created_at asc
  limit 1;

  if v_shop is null then
    insert into public.shops(name)
    values ('My Shop')
    returning id into v_shop;

    insert into public.shop_memberships(user_id, shop_id, role)
    values (v_user, v_shop, 'owner')
    on conflict do nothing;

    select m.shop_id
    into v_shop
    from public.shop_memberships m
    where m.user_id = v_user
    order by m.created_at asc
    limit 1;
  end if;

  return v_shop;
end;
$$;

revoke all on function public.bootstrap_current_user_shop() from public;
grant execute on function public.bootstrap_current_user_shop() to authenticated;

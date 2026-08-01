-- Keep an older offline device from overwriting a newer cloud row when its
-- outbox is flushed later. The client still pulls the newer remote version
-- after the skipped write is marked processed.
create or replace function public.keep_newer_updated_at()
returns trigger
language plpgsql
as $$
begin
  if TG_OP = 'UPDATE'
     and NEW.updated_at is not null
     and OLD.updated_at is not null
     and NEW.updated_at < OLD.updated_at then
    return OLD;
  end if;

  return NEW;
end;
$$;

drop trigger if exists customers_keep_newer_updated_at
  on public.customers;
create trigger customers_keep_newer_updated_at
before update on public.customers
for each row
execute function public.keep_newer_updated_at();

drop trigger if exists measurement_profiles_keep_newer_updated_at
  on public.measurement_profiles;
create trigger measurement_profiles_keep_newer_updated_at
before update on public.measurement_profiles
for each row
execute function public.keep_newer_updated_at();

drop trigger if exists orders_keep_newer_updated_at
  on public.orders;
create trigger orders_keep_newer_updated_at
before update on public.orders
for each row
execute function public.keep_newer_updated_at();

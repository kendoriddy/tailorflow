-- Payments are editable financial rows, so they need the same stale-write
-- guard as customers, measurements, and orders.
alter table public.payments add column if not exists updated_at bigint;

alter table public.payments
  alter column updated_at set default ((extract(epoch from now()) * 1000)::bigint);

update public.payments
set updated_at = paid_at
where updated_at is null;

alter table public.payments alter column updated_at set not null;

drop trigger if exists payments_keep_newer_updated_at
  on public.payments;
create trigger payments_keep_newer_updated_at
before update on public.payments
for each row
execute function public.keep_newer_updated_at();

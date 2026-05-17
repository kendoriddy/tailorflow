# TailorFlow security lab setup

Controlled environment for IDOR / BOLA testing. **Do not use production data or production Supabase projects.**

## Prerequisites

- [Supabase](https://supabase.com) account
- [Flutter](https://docs.flutter.dev/get-started/install) 3.24+
- Optional: [Burp Suite](https://portswigger.net/burp/communitydownload) + Android emulator

## Step 0 — Create Supabase project

1. Sign up at https://supabase.com
2. **New project** → name e.g. `tailorflow-security-lab`
3. Save the database password in a password manager
4. Wait until project status is **Healthy**

## Step 1 — Apply migrations

Dashboard → **SQL Editor** → New query. Run in order:

1. Paste and run [`supabase/migrations/001_init.sql`](../supabase/migrations/001_init.sql)
2. Paste and run [`supabase/migrations/002_app_feedback.sql`](../supabase/migrations/002_app_feedback.sql)

Verify **Table Editor**: `shops`, `shop_memberships`, `customers`, `measurement_profiles`, `orders`, `payments`, `order_attachments`, `app_feedback`.

Verify **RLS** is enabled on tenant tables (policies from `001_init.sql`).

## Step 2 — Auth settings (lab only)

**Authentication → Providers → Email**

- Email enabled
- For faster labs: disable **Confirm email** (re-enable before real pilots)

## Step 3 — Local credentials file

```bash
cp lab.env.local.example lab.env.local
```

Edit `lab.env.local` with **Project URL** and **anon public** key from **Project Settings → API**.

## Step 4 — Create attacker and victim accounts

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

1. Sign up `attacker@test.com` (strong password)
2. Sign out → Sign up `victim@test.com` (different password)
3. Each user gets a separate `shop_id` via `bootstrap_current_user_shop`

Record IDs: **Settings → Sync** shows `userId` and `shopId`, or SQL Editor:

```sql
select u.email, m.user_id, m.shop_id
from auth.users u
join public.shop_memberships m on m.user_id = u.id;
```

## Step 5 — Seed fake data

**As victim@test.com:** add 1–2 customers (fake names), one measurement, one order, one payment → **Settings → Sync now**.

**As attacker@test.com:** add one customer (proves own-tenant access works).

Optional SQL seed (service role in SQL Editor only): [`supabase/seed/lab_seed.sql`](../supabase/seed/lab_seed.sql) — replace `VICTIM_SHOP_ID` placeholder first.

## Step 6 — Discover victim IDs for automated tests

**Important:** In `lab.env.local`, set `ATTACKER_PASSWORD` and `VICTIM_PASSWORD` to the **exact passwords** you used when signing up in the app. The example file’s `change_me_strong_password` / `replace_with_*` values will cause `invalid_credentials`.

```bash
chmod +x scripts/security/idor_tests.sh
./scripts/security/idor_tests.sh --check-auth        # verify both logins first
./scripts/security/idor_tests.sh --discover-victim
```

Copy printed `VICTIM_CUSTOMER_ID` and `VICTIM_SHOP_ID` into `lab.env.local`.

### Troubleshooting `invalid_credentials`

| Check                | Action                                                                                                                 |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Placeholder password | Edit `lab.env.local` — use real signup passwords                                                                       |
| User missing         | Sign up `victim@test.com` in the app, or create user in Dashboard → Authentication → Users                             |
| Email not confirmed  | Auth → Providers → Email → disable **Confirm email** for lab, or confirm via inbox                                     |
| Wrong API key        | Project Settings → API → copy **anon public** key (often starts with `eyJ`; newer projects may use `sb_publishable_…`) |

**Without curl login:** use SQL Editor (service role) after seeding:

```sql
select id, shop_id, name from public.customers order by created_at desc limit 5;
```

Paste `id` → `VICTIM_CUSTOMER_ID` and `shop_id` → `VICTIM_SHOP_ID` in `lab.env.local`.

## Step 7 — Run IDOR test matrix

```bash
./scripts/security/idor_tests.sh
```

Results print to terminal; use output for [`reports/idor-testing.md`](../reports/idor-testing.md). Add Burp screenshots under `reports/evidence/` (gitignored).

**How to read results**

| Output                                 | Meaning                                                                                 |
| -------------------------------------- | --------------------------------------------------------------------------------------- |
| Tests 1–3, 5a, 5b `PASS` with HTTP 200 | RLS hid victim data (`[]`) or denied write — **good**                                   |
| Test 4 `PASS` with HTTP 403            | Cannot create rows in victim shop — **good**                                            |
| Test 5b old script said `FAIL`         | False positive if attacker has own payments; fixed script filters `shop_id=eq.<victim>` |
| Test 7 two rows `FAIL` (old script)    | Often **duplicate shops for same user**, not IDOR — see below                           |

Apply [`supabase/migrations/003_bootstrap_shop_lock.sql`](../supabase/migrations/003_bootstrap_shop_lock.sql) on new projects to reduce duplicate shops.

### Duplicate shop / “attacker appears twice”

`shop_memberships` allows **multiple shops per user** (`primary key (user_id, shop_id)`). `bootstrap_current_user_shop` can run on signup, sign-in, app start, and sync; without locking, two calls at once may create **two shops** for one email.

**Check in SQL Editor:**

```sql
select u.email, count(*) as shops, array_agg(m.shop_id::text) as shop_ids
from auth.users u
join public.shop_memberships m on m.user_id = u.id
group by u.email
having count(*) > 1;
```

**Cleanup:** [`supabase/scripts/lab_cleanup_duplicate_shops.sql`](../supabase/scripts/lab_cleanup_duplicate_shops.sql) (review before delete).

This is a **data hygiene** issue, not broken tenant isolation — IDOR tests 1–4 still prove User A cannot read victim customers.

## Step 8 — Burp + Android emulator (optional)

1. Burp → **Proxy** → listen `127.0.0.1:8080`
2. **Proxy → Intercept** → off while mapping traffic
3. Export CA: **Proxy → TLS → Import / export CA certificate** → install on emulator
4. Emulator Wi‑Fi → proxy manual → host machine LAN IP, port `8080`
5. Run Flutter with same `--dart-define` flags as Step 4
6. Sign in as attacker, sync — confirm `*.supabase.co` in **HTTP history**

If TLS fails on emulator, run curl/script tests first, then fix CA installation.

## Flutter run shortcut

```bash
set -a && source lab.env.local && set +a
flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

## Related docs

- [api-map.md](api-map.md) — endpoints
- [../reports/idor-testing.md](../reports/idor-testing.md) — assessment report template

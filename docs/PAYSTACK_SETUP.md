# Paystack subscriptions setup

TailorFlow uses **Paystack** for recurring billing:

| Plan    | Price       | Billing     |
| ------- | ----------- | ----------- |
| Monthly | **₦2,000**  | Every month |
| Yearly  | **₦19,800** | Every year  |

The app never sees your secret key. Checkout is started and verified by **Supabase Edge Functions**.

---

## Live vs test — what goes where

| Item                           | Required?                       | Where it goes                                                                                                                                        |
| ------------------------------ | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Secret key** (`sk_live_...`) | **Yes**                         | Supabase secret `PAYSTACK_SECRET_KEY` only — never in the Flutter app                                                                                |
| **Public key** (`pk_live_...`) | **No** (this integration)       | Not used. Checkout opens Paystack’s `authorization_url` from the server; no client-side Paystack SDK                                                 |
| **Plan codes** (`PLN_...`)     | **Yes**                         | Supabase secrets `PAYSTACK_PLAN_MONTHLY` / `PAYSTACK_PLAN_YEARLY` — must be **Live** plans created while your Paystack dashboard is in **Live** mode |
| **Callback URL**               | **Yes** (dashboard + automatic) | See [Callback URL](#callback-url-live) below                                                                                                         |
| **Webhook URL**                | **Yes**                         | Paystack Dashboard → Webhooks → your `paystack-webhook` function URL                                                                                 |

Use **live** keys and **live** plan codes together. Test plan codes do not work with `sk_live_...`, and vice versa.

---

## 1. Database migration

Apply [`supabase/migrations/004_shop_subscriptions.sql`](../supabase/migrations/004_shop_subscriptions.sql) in the Supabase SQL editor (or `supabase db push`).

---

## 2. Create Paystack plans

In [Paystack Dashboard](https://dashboard.paystack.com/) → **Plans** → **Create plan**:

### Monthly plan

- Name: `TailorFlow Monthly`
- Amount: **₦2,000** (200000 kobo)
- Interval: **Monthly**
- Copy the **Plan code** (e.g. `PLN_xxxxxxxx`)

### Yearly plan

- Name: `TailorFlow Yearly`
- Amount: **₦19,800** (1980000 kobo)
- Interval: **Annually**
- Copy the **Plan code**

---

## 3. Install Supabase CLI (`command not found: supabase`)

On macOS:

```bash
brew install supabase/tap/supabase
supabase --version
```

If you still get `command not found`, **open a new terminal tab** or run:

```bash
export PATH="/opt/homebrew/bin:$PATH"
```

Link the repo to your Supabase project (one-time; opens browser to log in):

```bash
cd /path/to/tailorflow_ng
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

`YOUR_PROJECT_REF` is the id in `https://YOUR_PROJECT_REF.supabase.co` (same as in `SUPABASE_URL`).

**Dashboard alternative:** Supabase → **Project Settings** → **Edge Functions** → **Secrets** (paste the three `PAYSTACK_*` values). Function deploy still needs the CLI or another CI step.

---

## 4. Deploy Edge Functions (live)

From the repo root (CLI installed and linked):

```bash
# Live secret key from Paystack → Settings → API Keys & Webhooks (Live tab)
supabase secrets set \
  PAYSTACK_SECRET_KEY=sk_live_YOUR_LIVE_SECRET_KEY \
  PAYSTACK_PLAN_MONTHLY=PLN_YOUR_LIVE_MONTHLY_CODE \
  PAYSTACK_PLAN_YEARLY=PLN_YOUR_LIVE_YEARLY_CODE

supabase functions deploy paystack-initialize
supabase functions deploy paystack-verify
supabase functions deploy paystack-return --no-verify-jwt
supabase functions deploy paystack-webhook --no-verify-jwt
```

`paystack-initialize` and `paystack-verify` still require a signed-in user: the handler checks the `Authorization` header. `verify_jwt = false` in `config.toml` only so **browser / Flutter Web** preflight (`OPTIONS`) succeeds (avoids CORS errors).

`paystack-return` and `paystack-webhook` are public endpoints.

**CORS error on upgrade?** Redeploy after pulling latest functions:

```bash
supabase functions deploy paystack-initialize
supabase functions deploy paystack-verify
```

On **Android/iOS**, CORS does not apply; a CORS message in the console usually means you are on **Flutter Web** or the function returned an error without CORS headers (fixed in `_shared/cors.ts`).

### Flutter Web checkout

`flutter run -d chrome` opens Paystack in a **new browser tab** (not an in-app WebView). After paying, return to the app tab and tap **I've completed payment**. For in-app checkout, use **Android or iOS** (`flutter run` on a device/emulator).

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically in Edge Functions — you do not set those manually.

To confirm secrets: `supabase secrets list` (values are hidden).

---

## 5. Callback URL (live)

Two places matter:

### A) Per checkout (automatic — no extra config)

Each payment sets `callback_url` when initializing the transaction:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/paystack-return?reference=...
```

That is built in `paystack-initialize` from your project’s `SUPABASE_URL`. The in-app WebView watches for this URL, then calls `paystack-verify`. **You do not pass this in Flutter or Supabase secrets.**

Example (replace with your project ref):

```text
https://btnrkebnzuzlqkogmqel.supabase.co/functions/v1/paystack-return
```

### B) Paystack Dashboard (recommended for live)

Paystack → **Settings** → **API Keys & Webhooks** → **Live** tab → **Callback URL** (sometimes under Preferences):

Set the **base** return URL (no query string):

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/paystack-return
```

This whitelists where Paystack may redirect after successful live checkout. It should match the host/path used in (A).

You do **not** need to add the public key (`pk_live_...`) anywhere for TailorFlow’s current checkout flow.

---

## 6. Paystack webhook URL (live)

Dashboard → **Settings** → **API Keys & Webhooks** → **Live** tab → **Webhooks** → add URL:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/paystack-webhook
```

Use the same project ref as in your Supabase URL (e.g. `btnrkebnzuzlqkogmqel`).

Enable at least:

- `charge.success`
- `subscription.create`
- `subscription.disable`
- `invoice.payment_failed`

---

## 7. App build flags

Subscriptions require cloud sign-in:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=REMOTE_PAYWALL=true
```

`REMOTE_PAYWALL=true` enforces the free customer cap; subscribed shops are unlimited.

---

## 8. User flow

1. User signs in (cloud account).
2. **Settings → Upgrade** or paywall when adding customers over the free limit.
3. Chooses monthly or yearly → Paystack checkout in-app WebView.
4. On success, `shops.subscription_status` becomes `active` (webhook + verify).
5. App syncs entitlement locally on sync and after payment.

---

## Troubleshooting

| Issue                                      | Check                                                                          |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| “Paystack is not configured on the server” | Secrets `PAYSTACK_SECRET_KEY`, `PAYSTACK_PLAN_MONTHLY`, `PAYSTACK_PLAN_YEARLY` |
| Invalid key / plan errors on live          | `sk_live_` with **live** `PLN_` codes (not test plans)                         |
| Payment succeeds but app still free        | Live webhook URL; migration 004; user signed into same shop                    |
| Checkout never returns to app              | Live **Callback URL** in Paystack dashboard matches `.../paystack-return`      |
| Verify fails                               | `paystack_checkout_sessions` row exists; reference matches                     |

# Plan limits (admin-configurable)

Free-tier caps are **not hardcoded in the app**. Defaults ship in code (`PlanConfig.defaults`: 50 customers, 10 WhatsApp sends/month), but you override them globally in Supabase.

## Apply migration

Run [`supabase/migrations/003_platform_config.sql`](../supabase/migrations/003_platform_config.sql) on your Supabase project.

## Change limits (admin)

In **Supabase → Table Editor → `platform_config`**, edit `value` for:

| `key`                              | Example `value` | Meaning                                                                               |
| ---------------------------------- | --------------- | ------------------------------------------------------------------------------------- |
| `free_tier_max_customers`          | `50`            | Max active customers (`deleted_at IS NULL`) before paywall when `REMOTE_PAYWALL=true` |
| `free_tier_whatsapp_monthly_limit` | `10`            | WhatsApp handoffs per calendar month on free tier                                     |
| `free_tier_whatsapp_monthly_limit` | `-1`            | Unlimited WhatsApp on free tier                                                       |

Only the **service role** (project admin) can write this table. The app reads it when the user is signed in and sync runs.

## When limits apply

- **Customers**: enforced when `REMOTE_PAYWALL=true` at build time and the shop is not marked subscribed.
- **WhatsApp**: each successful handoff (opens `wa.me` with a prefilled message) counts once for free users. Subscribed shops are unlimited.

## Paywall & Paystack

Production billing uses Paystack subscriptions (₦2,000/month, ₦19,800/year). See [`docs/PAYSTACK_SETUP.md`](PAYSTACK_SETUP.md). Pilot builds can use the debug **Subscribed** override in Settings (debug mode only).

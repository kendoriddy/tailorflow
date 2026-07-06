# TailorFlow

Offline-first Flutter app for small tailoring shops: customers, measurements, orders, payments, and WhatsApp reminders.

Display name is **TailorFlow** (no regional suffix). Package IDs remain `tailorflow_ng` / `ng.tailorflow.*` for store continuity. To rename later, see [`docs/BRANDING.md`](docs/BRANDING.md).

## Web presence

| Surface                   | Technology                                | Purpose                                                                                  |
| ------------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| Marketing / SEO           | [`website/`](website/) — `site-config.js` | e.g. `tailorflow.kennyonifade.com` — deploy via [`website/DEPLOY.md`](website/DEPLOY.md) |
| Tailor dashboard (future) | Flutter web on a subdomain                | Signed-in analytics — reuses Supabase auth and app code                                  |
| Operator admin (future)   | Separate web app                          | Internal feedback inbox, metrics — see `docs/REMAINING_FEATURES.md`                      |

Static HTML stays best for **discoverability** (fast load, crawlable content). Flutter web is best for **authenticated product UI** after users sign in.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.24+ with Dart 3.5+

## Setup

```bash
cd tailorflow_ng
flutter pub get
flutter run
```

If Android Gradle wrapper scripts are missing in your checkout, regenerate Android/iOS host files (without clobbering `lib/`) using Flutter’s scaffolding commands for your installed SDK version, or copy `android/gradlew*` from any fresh `flutter create` project.

## Local database

The MVP uses **sqflite** (SQLite on device) as the source of truth with an **outbox** table for sync. The product plan referenced Drift; this repo keeps the same relational schema and can migrate to Drift later if you want codegen-based queries.

## Optional: Supabase backup & sync

Configure at build/run time:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

**Release APK / App Bundle:** compile-time defines are **not** read from a `.env` file. Whatever you pass to `flutter build` is baked into that binary. Example:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Use the same flags for `flutter build appbundle`. If testers install an APK built **without** those defines, `SUPABASE_URL` / `SUPABASE_ANON_KEY` are empty strings in the app and **sync will not run**—symptoms match “sync not working.” CI/CD (Codemagic, GitHub Actions, etc.) should pass the same `--dart-define=...` arguments you use locally.

See [`supabase/migrations/001_init.sql`](supabase/migrations/001_init.sql) for example RLS-oriented tables (adjust to your tenancy model). Apply [`supabase/migrations/002_app_feedback.sql`](supabase/migrations/002_app_feedback.sql) if you want in-app feedback rows stored in Supabase (for a future admin dashboard).

## Optional: Sentry

```bash
flutter run --dart-define=SENTRY_DSN=https://...@...ingest.sentry.io/...
```

## Billing / Paystack subscriptions

- **Monthly:** ₦2,000
- **Yearly:** ₦19,800

Setup (Paystack plans, Edge Functions, webhooks): [`docs/PAYSTACK_SETUP.md`](docs/PAYSTACK_SETUP.md). Apply migration [`supabase/migrations/004_shop_subscriptions.sql`](supabase/migrations/004_shop_subscriptions.sql).

The paywall is gated by `RemoteFlags.paywallEnabled` (`REMOTE_PAYWALL` dart-define, defaults off). Subscribed shops get unlimited customers and WhatsApp.

## Freemium & plan limits

Defaults: **50 active customers** and **10 WhatsApp handoffs/month** on the free tier (`customers.deleted_at IS NULL`). Limits are **admin-configurable** in Supabase `platform_config` — see [`docs/PLANS_AND_LIMITS.md`](docs/PLANS_AND_LIMITS.md). Apply migration [`supabase/migrations/003_platform_config.sql`](supabase/migrations/003_platform_config.sql).

Adding customers beyond the limit opens the paywall when `REMOTE_PAYWALL=true` and the shop is not subscribed.

## Shop branding (white-label)

Each shop can set display name, accent color, logo, and shop name used in WhatsApp copy under **Settings → Branding**. Product-level rename for store listings: [`docs/BRANDING.md`](docs/BRANDING.md).

## Play Store copy

See [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md).

## Play Store & App Store deployment

Full checklist, signing setup, build commands, and store policy notes: [`docs/STORE_DEPLOYMENT.md`](docs/STORE_DEPLOYMENT.md).

**v1 store release:** ship with default settings (no `REMOTE_PAYWALL` define) — billing UI hidden, no in-app purchases. Paystack billing remains available for direct APK builds with `--dart-define=REMOTE_PAYWALL=true`.

## Privacy (pilot)

See [`docs/PRIVACY_PILOT.md`](docs/PRIVACY_PILOT.md) for NDPR-oriented copy and data handling notes.

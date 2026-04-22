# TailorFlow NG

Offline-first Flutter app for small tailoring shops: customers, measurements, orders, payments, and WhatsApp reminders.

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

See [`supabase/migrations/001_init.sql`](supabase/migrations/001_init.sql) for example RLS-oriented tables (adjust to your tenancy model).

## Optional: Sentry

```bash
flutter run --dart-define=SENTRY_DSN=https://...@...ingest.sentry.io/...
```

## Optional: billing / Paystack

The paywall is gated by `RemoteFlags.paywallEnabled` (defaults off). Wire Paystack Customer Portal or subscription flow when you are ready to charge.

## Freemium

First **10 active customers** are free (`customers.deleted_at IS NULL`). Adding the 11th customer opens the paywall when billing is enabled.

## Privacy (pilot)

See [`docs/PRIVACY_PILOT.md`](docs/PRIVACY_PILOT.md) for NDPR-oriented copy and data handling notes.

# TailorFlow NG — remaining features & work

This document lists **what is not done yet** relative to the current codebase and the product roadmap (`docs/TODOS_PHASES_2_4.md`). Use it as a single backlog view; detailed phase notes stay in the roadmap file.

**Last updated:** 2026-05-03

---

## Current baseline (what already exists)

Roughly in place today:

- **Local-first data**: SQLite (`sqflite`) with customers, measurement profiles, orders, payments, outbox, shop settings.
- **Core flows**: customer list/profile, add customer, measurements, orders, payments (and related edit flows as implemented in `lib/`).
- **Freemium**: active customer cap with paywall **UI** when `REMOTE_PAYWALL` is enabled.
- **Optional cloud**: Supabase client bootstrap via dart-defines; **outbox flush** to mirror upserts/deletes to remote tables when Supabase is configured.
- **WhatsApp helpers**: templates / launcher utilities.
- **Optional**: Sentry, notifications scaffolding (see code under `lib/features/notifications/` and `lib/data/repos/notifications_repository.dart`).
- **Platforms**: Android, iOS, Linux, macOS, Windows, and **Web** (web uses IndexedDB-backed sqlite; `web/sqflite_sw.js` + `web/sqlite3.wasm` are committed).
- **In-app feedback (MVP)**: Settings → **Send feedback** — category (bug / idea / other), free-text details, app version + platform; mailto to the configured address (default in code); optional **Supabase insert** into `app_feedback` when sync keys are baked in and migration `002_app_feedback.sql` is applied (for a future admin UI). Subjects use a `[TailorFlow NG] …` prefix for filtering.

---

## Gaps in the current build (finish before calling “production ready”)

These are **stubbed or minimal** in code today:

### Billing & subscriptions

- **Paystack**: no real subscription or one-time payment flow; paywall opens external Paystack **documentation** only.
- **Entitlements**: `subscribed` is a **manual** `shop_settings` flag (`PaywallScreen` includes a dev-only “mark as subscribed” path). No webhook, no receipt validation, no restore purchases.
- **Remote paywall flag**: `RemoteFlags.paywallEnabled` is compile-time only (`REMOTE_PAYWALL`); no remote config service.

### Cloud backup, auth, and multi-tenant safety

- **Supabase Auth**: not integrated; **phone OTP** on `BackupScreen` is explicitly a **stub** (no `signInWithOtp`, no SMS provider).
- **Tenant model**: example SQL notes **TODO: `shop_id` + RLS** (`supabase/migrations/001_init.sql`). Outbox sync assumes tables exist and policies are correct—**production RLS and `shop_id` scoping are unfinished product work**.
- **Sync completeness**: outbox handles a **subset** of operations (see `SyncService._applyRemote`); conflict resolution, full entity coverage, and “pull” sync from server are not described as complete.
- **Backup UX**: no end-user restore story, export bundle, or device migration flow beyond “sync when online”.

### Developer environment (not app features, but blockers for some targets)

- **macOS / iOS builds** on a fresh machine need **full Xcode** and **CocoaPods** (see `flutter doctor` output when those are missing).

### Optional migrations & tooling

- **Drift** (or other codegen query layer): mentioned in `README.md` as a future migration from raw `sqflite`—not started as a project-wide migration.

---

## Phase 2 — immediate post-MVP (weeks 4–8)

_Source: `docs/TODOS_PHASES_2_4.md`_

### Photos (styles / fabric)

- Decide storage: on-device only vs cloud vs hybrid.
- Add schema (e.g. `attachments`) and sync story.
- Image picker + compression; UI attach from customer and order; viewer; delete/replace.
- Offline upload queue + resume rules; update privacy copy (NDPR).

### Basic reports

- Define metrics (e.g. monthly earnings, “top owing” customers) and timezone rules.
- UI: Reports entry; export/share text or CSV (MVP).

### Multiple shop profiles (apprentices / branches)

- `shops` table + `shop_id` on tenant data; migration from single implicit shop.
- UI: shop switcher; create/rename/archive; roles (owner vs staff) as needed.
- Sync: scope Supabase RLS and outbox by `shop_id`.
- Backup/restore per shop (export bundle).

### Export to PDF (customer receipt)

- Choose PDF approach (in-app package vs server template).
- Receipt template + system share sheet.

### Voice notes

- Permissions + record/playback UI; attach to customer/order; sync like photos.
- Optional transcription (later / Phase 4 tie-in).

### In-app feedback — follow-ups (optional)

- **Done (backend capture)**: rows in `public.app_feedback` when Supabase is configured (see Phase 5 for viewing).
- Optional screenshot or “attach last error” with explicit consent (pairs with cross-cutting “send logs”).
- Link from prominent surfaces beyond Settings (e.g. overflow menu on the home screen) if analytics show low discovery.

---

## Phase 3 — growth (months 3–6)

_Source: `docs/TODOS_PHASES_2_4.md`_

### Monetization: lifetime purchase

- Product/pricing; Paystack one-time + webhook; entitlement model; refund/chargeback playbook.

### Referral system

- Referral codes; deep links; reward rules and anti-fraud; admin/reporting.

### Basic analytics

- Peak season / order volume trends; average order value; optional precomputed rollups.

### Fabric inventory (optional module)

- Rolls, consumption, low-stock alerts; off by default.

### Mobile money integrations (payment reminders)

- Research Opay / PalmPay / etc.; templates + “reminder sent” tracking; compliance.

### Association mode (tailor unions)

- Narrow scope with a real union; auth/groups; MVP bulletin.

---

## Phase 4 — vision (year 1–2)

_Source: `docs/TODOS_PHASES_2_4.md`_

### AI-assisted measurements

- Privacy/consent; start with heuristics (“suggest from last N orders”) before full ML; optional telemetry.

### Marketplace lite

- Trust & safety; listings; payments strategy (off-platform vs escrow).

### Other artisans (horizontal expansion)

- Abstract domain model / white-label per vertical.

### Localization (English + Yoruba + Pidgin)

- i18n approach; community review; layout audit if non-LTR later.

### Web dashboard (accountants / bookkeepers)

- Invites, roles; exports; audit log; stack choice (Flutter web vs SPA).

---

## Phase 5 — admin & internal tools

_Planned after core tailor-facing roadmap; last phase for operator-facing work._

### TailorFlow admin dashboard

- Operator authentication separate from tailor shop accounts (do not expose service role keys in the tailor app; admin app uses server-side or scoped credentials).
- **Feedback inbox**: read and triage rows from `app_feedback` (submitted from the app when Supabase + migration `002_app_feedback.sql` are in use); optional status, assignment, notes.
- Later: subscription health, pilot metrics, feature-flag UI — scope as needed.

---

## Cross-cutting (any phase)

_Source: `docs/TODOS_PHASES_2_4.md`_

- Performance budgets (cold start, scroll, DB on low-end Android).
- Crash-free session targets; staged rollout.
- Support channel (partially covered by Settings → Send feedback); in-app “send logs” with consent.
- Play Console hygiene (staged releases, ANRs, pre-launch).
- Security: RLS review, secrets handling in CI, keys not in repo.

---

## How to maintain this doc

- When you ship an item, remove it from the relevant section (or move it to a “Done” section in your tracker).
- For long-form rationale and pilot notes, keep using **`docs/TODOS_PHASES_2_4.md`** and **`docs/PRIVACY_PILOT.md`**.

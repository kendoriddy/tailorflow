# TailorFlow NG — pilot privacy notes (NDPR-oriented)

This document is **not legal advice**. It is an engineering checklist for early pilots in Nigeria.

## What the MVP stores locally

- Customer **name** and optional **phone number**
- **Body measurements** and free-text notes
- **Orders** (style title, fabric note, due date, status) and **payments** (amounts, timestamps)

## Why this matters

Phone numbers, measurements tied to identifiable individuals, and payment records are **personal data** under the Nigeria Data Protection Regulation (NDPR). Treat them accordingly.

## Pilot commitments (recommended)

- Tell tailors plainly **what is stored on the phone** and **what leaves the phone** (cloud sync is optional and only when Supabase is configured).
- Use **TLS** for any network calls (Supabase does this by default).
- Avoid collecting fields you do not need for the MVP.
- Provide a simple **contact path** for access/deletion requests (even if you handle them manually at first).

## Optional cloud sync (Supabase)

If you enable Supabase:

- Configure **Row Level Security** so one tailor cannot read another tailor’s rows.
- Map each signed-in user to a stable `shop_id` tenant key.
- Review Supabase logs retention and access controls.

## Crash reporting (Sentry)

If you set `SENTRY_DSN`, crash reports may include device metadata. Prefer turning Sentry off during the very first shop-floor trials if tailors are sensitive.

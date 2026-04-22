# TailorFlow NG — pilot QA matrix (MVP)

Run these checks on a **real mid-range Android phone** before handing builds to tailors.

## Offline / airplane mode

1. Turn on airplane mode.
2. Add a customer, add measurements, create an order, record a partial payment.
3. Force-stop the app, reopen: data must still be present.
4. Turn airplane mode off, tap **Sync now** (requires Supabase configured): pending outbox ops should flush without duplicates (verify in Supabase table rows).

## Weak signal / flaky network

1. Toggle Wi‑Fi on/off while saving measurements.
2. Confirm the UI never shows a permanent spinner on the measurement screen; saves should remain local-first.

## Freemium + paywall (engineering build)

1. Build with `--dart-define=REMOTE_PAYWALL=true`.
2. Create 10 customers successfully.
3. Attempt customer #11: paywall should appear unless **Subscribed** is enabled in Settings (local stub).

## WhatsApp handoff

1. Customer must have a phone number.
2. From an order card, tap **WhatsApp ready** and confirm WhatsApp opens with a prefilled polite message.

## Money math sanity

1. Agreed ₦10,000, pay ₦2,500, balance should read **₦7,500**.
2. Pay full amount: balance should read **Fully paid** and **Add payment** should disable.

## “Never crash during a fitting”

1. Rapidly switch between tabs and customer profiles for 2 minutes.
2. Rotate device (if enabled) during edits.

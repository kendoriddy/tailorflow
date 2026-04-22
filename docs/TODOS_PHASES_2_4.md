# TailorFlow NG — roadmap todos (Phases 2–4)

Checklist-style backlog for work **after** the Phase 1 MVP. Items are grouped by phase as in the April 2026 product doc; order within a phase can change based on pilot feedback.

**How to use this file**

- Treat each `- [ ]` line as a shippable unit of work (some are epics—split when you pick them up).
- Link PRs or tickets in your tracker next to items as you start them.
- Revisit after each pilot cohort (e.g. Baba Asafe + 10–15 tailors): reorder, cut, or merge items.

---

## Phase 2 — immediate post-MVP (weeks 4–8)

### Photos (styles / fabric)

- Decide storage model: on-device only vs cloud (Supabase Storage / S3) vs hybrid (thumbnail local, full-res cloud).
- Add schema: `attachments` (or reuse `orders` / `customers` FK) with `type`, `local_uri`, `remote_url`, `created_at`, `sync_state`.
- Implement image picker + compression pipeline (max dimensions, JPEG/WebP quality) for shop-floor speed.
- UI: attach photo from customer profile and from order detail; grid + full-screen viewer; delete / replace.
- Offline: queue uploads in outbox; resume on Wi‑Fi / user toggle “upload on cellular”.
- NDPR: clarify in privacy copy what is stored, retention, and deletion when customer is removed.

### Basic reports

- Define report definitions in product copy (e.g. “this month” = calendar month in shop timezone).
- **Monthly earnings**: sum of payments received in period (cash-in) vs sum of agreed order values completed—pick one primary metric and label it clearly for tailors.
- **Top owing customers**: rank by total outstanding balance across open orders; tap-through to customer.
- UI: simple “Reports” entry from home or settings; export/share as text or CSV for MVP of reports (before PDF phase-wide).

### Multiple shop profiles (apprentices / branches)

- Model: `shops` table + `shop_id` on all tenant-scoped rows; migration from single implicit shop.
- UI: shop switcher (persistent last-selected); create/rename/archive shop (permissions: owner vs staff—start with single role if needed).
- Sync: scope Supabase RLS and outbox payloads by `shop_id`.
- Backup/restore story per shop (export bundle).

### Export to PDF (customer receipt)

- Choose PDF approach (e.g. `pdf` package, or server-side template if you add a backend).
- Receipt template: shop name, customer, order summary, amounts, balance, date, optional signature line.
- “Share PDF” via system sheet (WhatsApp, Files, print).

### Voice notes

- Platform permissions: microphone + storage; explain why in UI (one line).
- Record / pause / stop / playback UI; max duration and file size limits.
- Attach voice note to customer or order; store path + optional cloud sync same as photos.
- Accessibility: optional transcription later (Phase 4 AI could tie in)—not required for first cut.

---

## Phase 3 — growth (months 3–6)

### Monetization: lifetime purchase

- Product decision: price band (doc: ₦15k–25k), entitlement flags, and upgrade path from monthly.
- Paystack: one-time charge + webhook → set `entitlement = lifetime` on `shop` / user record.
- App: gate features on entitlement; handle refund/chargeback policy (support playbook).

### Referral system

- Generate referral codes per shop; deep link or short code for install/sign-up.
- Reward rules: “both get 1 month free” — define eligibility, fraud limits (device fingerprint / phone), and ledger in DB.
- Admin/report: list referrals and redemption status.

### Basic analytics

- **Peak season**: orders per week/month (simple chart); compare to prior year once you have history.
- **Average order value**: agreed amount and/or collected amount; segment by customer new vs returning if you add that flag.
- Performance: precompute aggregates nightly or on-device incremental rollups for large DBs.

### Fabric inventory (optional module)

- Data model: fabric rolls (length, color, purchase cost, location bin), consumption linked to orders (optional link).
- UI: low-stock alerts; “use fabric on order” picker.
- Keep module off by default to avoid clutter for tailors who do not want it.

### Mobile money integrations (payment reminders)

- Research Opay / PalmPay / others: deep links, merchant APIs, or “copy account + reference” fallback.
- Template messages: request payment with amount + reference; track “reminder sent” on order.
- Compliance: do not store full PANs; follow partner terms.

### Association mode (tailor unions)

- Problem definition with a real union: announcements, shared tips, vs shared jobs—narrow scope.
- Auth/groups: `association_id`, roles, moderation.
- MVP: read-only bulletin + admin post; no open social graph at first.

---

## Phase 4 — vision (year 1–2)

### AI-assisted measurements

- Privacy impact assessment: on-device model vs server; consent copy.
- MVP suggestion: “suggest from last 3 orders same garment type” before full ML.
- Telemetry (opt-in): measure acceptance rate of suggestions.

### Marketplace lite

- Trust & safety: listing moderation, reporting, dispute flow.
- Listings: photo, price, size, pickup area, contact via in-app message or WhatsApp.
- Payments: start with off-platform (meet + pay) vs in-app escrow—explicit product choice.

### Other artisans (horizontal expansion)

- Abstract domain model: `business_type`, configurable measurement fields, order terminology.
- Separate branding or white-label build per vertical (cobbler, hairdresser)—avoid one bloated UI.

### Localization (English + Yoruba + Pidgin)

- Choose i18n approach (`intl` / ARB / slang).
- Community review with native speakers for tone (shop-floor language, not textbook).
- RTL/layout audit if you add languages beyond LTR later.

### Web dashboard (accountants / bookkeepers)

- Auth: shop owner invites accountant email; read-only vs edit roles.
- Web stack decision (Flutter web vs separate SPA).
- Features: exports (CSV/Excel), VAT-ready fields if needed, audit log of changes.

---

## Cross-cutting (any phase)

- **Performance budgets**: cold start, scroll jank, DB query plans on low-end Android.
- **Crash-free sessions** target; staged rollout (internal → beta → production).
- **Support channel**: WhatsApp Business / phone for tailors; in-app “send logs” with consent.
- **Play Console**: staged releases, ANRs, pre-launch reports.
- **Security**: RLS review, API keys in CI, secrets not in repo.

---

## Notes

- Phase boundaries are guides; ship smallest slices that tailors ask for after each pilot interview.
- Keep the Phase 1 non-negotiables: **fast**, **offline-first**, **no tutorial required**, **stable during fittings**.
# IDOR / BOLA Security Assessment — TailorFlow

| Field               | Value                                                        |
| ------------------- | ------------------------------------------------------------ |
| **Assessment type** | Broken Object Level Authorization (BOLA / IDOR)              |
| **Application**     | TailorFlow (`tailorflow_ng`) — offline-first tailor shop app |
| **Backend**         | Supabase (GoTrue + PostgREST + PostgreSQL RLS)               |
| **Lab project**     | `tailorflow-security-lab` (isolated; no production data)     |
| **Date**            | 2026-05-16                                                   |
| **Tester**          | Kehinde Ridwan Onifade (Kenny Onifade)                       |
| **Overall result**  | **PASS** — no cross-tenant access identified                 |

---

## 1. Executive summary

TailorFlow stores multi-tenant business data (customers, measurements, orders, payments) scoped by `shop_id`. Authorization for the cloud API is enforced in **PostgreSQL Row Level Security (RLS)**, not only in the Flutter client.

This assessment asked: _Can User A (`attacker@test.com`) read, update, or create User B’s (`victim@test.com`) data by manipulating object IDs or `shop_id` in API requests?_

**Answer: No.** With User A’s valid JWT, all cross-tenant read and write attempts were blocked. PostgREST returned empty result sets (`[]`) or HTTP 403 (RLS violation) rather than victim PII.

Testing used a dedicated Supabase lab, synthetic tailor data only, and automated checks via [`scripts/security/idor_tests.sh`](../scripts/security/idor_tests.sh). A duplicate-shop data issue found during testing was **lab hygiene only** (resolved via cleanup SQL; not an IDOR finding).

---

## 2. Objective

Verify resistance to **Broken Object Level Authorization** when an authenticated attacker:

1. Targets another tenant’s resources by **primary key** (`customer_id`, order `id`, etc.)
2. Filters or writes using another tenant’s **`shop_id`**
3. Accesses related tables (`orders`, `payments`, `shop_memberships`, `app_feedback`)

**Mapping:** [OWASP API Security Top 10 2023 — API1:2023 Broken Object Level Authorization](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/)

---

## 3. Scope

### In scope

- PostgREST resources documented in [docs/api-map.md](../docs/api-map.md)
- Tables: `customers`, `measurement_profiles`, `orders`, `payments`, `order_attachments`, `shop_memberships`, `app_feedback`
- Authenticated attacker vs. victim tenant isolation

### Out of scope

- Production Supabase projects or real customer PII
- Mobile app local SQLite (offline-only mode without Supabase)
- Denial of service, credential stuffing, phishing, device theft
- Paystack / billing (not implemented in MVP)
- Supabase platform infrastructure (shared responsibility model)

---

## 4. Methodology

| Step | Action                                                                                                                            |
| ---- | --------------------------------------------------------------------------------------------------------------------------------- |
| 1    | Provisioned isolated Supabase project per [docs/SECURITY_LAB_SETUP.md](../docs/SECURITY_LAB_SETUP.md)                             |
| 2    | Applied SQL migrations `001_init.sql`, `002_app_feedback.sql`; later `003_bootstrap_shop_lock.sql` to reduce duplicate-shop races |
| 3    | Created lab users `attacker@test.com` and `victim@test.com`; seeded victim with fake customers, orders, and payments              |
| 4    | Recorded victim `customer_id` and `shop_id` via `./scripts/security/idor_tests.sh --discover-victim`                              |
| 5    | Executed IDOR matrix: `./scripts/security/idor_tests.sh` (curl + attacker JWT)                                                    |
| 6    | Optional: Burp Suite to capture/replay Flutter sync traffic                                                                       |

**Pass criteria:** No victim names, phones, measurements, order titles, or payment amounts in responses; writes to victim shop rejected.

### Test accounts

| Role              | Email               | Purpose                              |
| ----------------- | ------------------- | ------------------------------------ |
| User A (attacker) | `attacker@test.com` | JWT used for all hostile replays     |
| User B (victim)   | `victim@test.com`   | Source of target IDs and seeded data |

---

## 5. Environment

| Component        | Detail                                                                                    |
| ---------------- | ----------------------------------------------------------------------------------------- |
| **Schema**       | `supabase/migrations/001_init.sql`, `002_app_feedback.sql`, `003_bootstrap_shop_lock.sql` |
| **Client**       | Flutter app with `--dart-define=SUPABASE_URL`, `SUPABASE_ANON_KEY`                        |
| **Tools**        | curl, `scripts/security/idor_tests.sh`, Burp Suite (optional)                             |
| **ID discovery** | `lab.env.local` (`VICTIM_CUSTOMER_ID`, `VICTIM_SHOP_ID`)                                  |

---

## 6. Findings summary

| #     | Test                                              | Expected (secure)                        | Result   | Notes                                              |
| ----- | ------------------------------------------------- | ---------------------------------------- | -------- | -------------------------------------------------- |
| 1     | GET `/customers?id=eq.<victim_customer_id>`       | No victim rows                           | **PASS** | HTTP 200, body `[]`                                |
| 2     | GET `/customers?shop_id=eq.<victim_shop_id>`      | No victim rows                           | **PASS** | HTTP 200, body `[]`                                |
| 3     | PATCH victim customer (`name: "PWNED"`)           | No update / denied                       | **PASS** | HTTP 200, empty body (0 rows affected)             |
| 4     | POST customer into victim `shop_id`               | Rejected                                 | **PASS** | HTTP 403, RLS policy violation                     |
| 5a    | GET `/orders?customer_id=eq.<victim_customer_id>` | No victim orders                         | **PASS** | HTTP 200, body `[]`                                |
| 5b    | GET `/payments?shop_id=eq.<victim_shop_id>`       | No victim payments                       | **PASS** | HTTP 200, body `[]`                                |
| 6     | GET `/app_feedback`                               | No other users’ feedback                 | **PASS** | HTTP 200, body `[]` (no SELECT policy for clients) |
| 7     | GET `/shop_memberships`                           | Own membership only; no victim `shop_id` | **PASS** | HTTP 200; one row after duplicate-shop cleanup     |
| Bonus | GET `/customers` without `Authorization`          | No data leak                             | **PASS** | HTTP 200, body `[]`                                |

**Vulnerabilities identified:** None (0 Critical, 0 High, 0 Medium, 0 Low).

### Automated test output (2026-05-16)

```text
=== TailorFlow IDOR test matrix (attacker JWT) ===

Test 1  GET customer by victim id     → PASS (HTTP 200)
Test 2  GET customers by victim shop → PASS (HTTP 200)
Test 3  PATCH victim customer        → PASS (HTTP 200)
Test 4  POST customer in victim shop → PASS (HTTP 403)
Test 5a GET orders for victim customer → PASS (HTTP 200)
Test 5b GET payments in victim shop  → PASS (HTTP 200)
Test 6  GET app_feedback             → PASS (HTTP 200)
Test 7  GET shop_memberships         → PASS (HTTP 200)
Bonus   GET customers without JWT    → PASS (HTTP 200)
```

> **Note on HTTP 200 + PASS:** PostgREST often returns 200 with an empty JSON array when RLS filters out all rows. A PASS means **no victim data in the body**, not “request failed.”

---

## 7. Detailed test results

### 7.1 Test 1 — Read victim customer by ID

**Attack:** User A requests User B’s customer using a known UUID.

```http
GET /rest/v1/customers?id=eq.<VICTIM_CUSTOMER_ID>&select=id,name,shop_id HTTP/2
Host: <project>.supabase.co
apikey: <anon_key>
Authorization: Bearer <attacker_access_token>
```

| Response | Body |
| -------- | ---- |
| HTTP 200 | `[]` |

**Result:** **PASS** — Victim customer name and `shop_id` were not disclosed.

---

### 7.2 Test 2 — Read customers by victim shop_id

**Attack:** User A lists all customers in User B’s shop via `shop_id` filter.

```http
GET /rest/v1/customers?shop_id=eq.<VICTIM_SHOP_ID>&select=id,name HTTP/2
```

| Response | Body |
| -------- | ---- |
| HTTP 200 | `[]` |

**Result:** **PASS** — Shop-scoped enumeration blocked by RLS.

---

### 7.3 Test 3 — Update victim customer

**Attack:** User A attempts to rename User B’s customer.

```http
PATCH /rest/v1/customers?id=eq.<VICTIM_CUSTOMER_ID>
Content-Type: application/json

{"name":"PWNED"}
```

| Response | Body                              |
| -------- | --------------------------------- |
| HTTP 200 | `[]` (no rows updated / returned) |

**Result:** **PASS** — Cross-tenant modification denied.

---

### 7.4 Test 4 — Create row in victim shop

**Attack:** User A POSTs a new customer with User B’s `shop_id` in the JSON body.

| Response | Body                                |
| -------- | ----------------------------------- |
| HTTP 403 | RLS policy violation on `customers` |

**Result:** **PASS** — `WITH CHECK` on `customers_shop_scope` rejected the insert.

---

### 7.5 Test 5a — Read victim orders

```http
GET /rest/v1/orders?customer_id=eq.<VICTIM_CUSTOMER_ID>&select=id,title HTTP/2
```

| Response | Body |
| -------- | ---- |
| HTTP 200 | `[]` |

**Result:** **PASS**

---

### 7.6 Test 5b — Read victim payments

```http
GET /rest/v1/payments?shop_id=eq.<VICTIM_SHOP_ID>&select=id,order_id,amount_ngn HTTP/2
```

| Response | Body |
| -------- | ---- |
| HTTP 200 | `[]` |

**Result:** **PASS** — No payment amounts or order IDs from victim shop.

---

### 7.7 Test 6 — Read app feedback

```http
GET /rest/v1/app_feedback?select=id,subject&limit=10 HTTP/2
```

| Response | Body |
| -------- | ---- |
| HTTP 200 | `[]` |

**Result:** **PASS** — Clients have insert-only policy; no cross-user SELECT.

---

### 7.8 Test 7 — Read shop memberships

```http
GET /rest/v1/shop_memberships?select=user_id,shop_id HTTP/2
```

| Response | Body                                               |
| -------- | -------------------------------------------------- |
| HTTP 200 | One row: attacker’s own `user_id` / `shop_id` only |

**Result:** **PASS** — Victim’s `shop_id` did not appear. During early testing, two rows reflected duplicate shop bootstrap for the same user (data hygiene issue, fixed via [`lab_cleanup_duplicate_shops.sql`](../supabase/scripts/lab_cleanup_duplicate_shops.sql)); this was **not** cross-tenant access.

---

### 7.9 Bonus — Unauthenticated read

```http
GET /rest/v1/customers?select=id&limit=1 HTTP/2
apikey: <anon_key>
(no Authorization header)
```

| Response | Body |
| -------- | ---- |
| HTTP 200 | `[]` |

**Result:** **PASS** — No anonymous data exposure for this endpoint.

---

## 8. Answers to assessment questions

| Question                                     | Answer                                                                          |
| -------------------------------------------- | ------------------------------------------------------------------------------- |
| Can User A **read** User B’s data?           | **No** — GET by victim `id` or `shop_id` returned `[]`.                         |
| Can User A **update** User B’s data?         | **No** — PATCH returned no updated rows.                                        |
| Can User A **delete** User B’s data?         | **Not tested explicitly**; same RLS `USING` clause as UPDATE — expected **No**. |
| Can User A **create** data in User B’s shop? | **No** — POST with victim `shop_id` returned HTTP 403.                          |

---

## 9. Evidence

Artifacts live under `reports/evidence/` (gitignored). Redact tokens before sharing.

| File                                    | Status   | Description                              |
| --------------------------------------- | -------- | ---------------------------------------- |
| `evidence/test1-get-customer-by-id.png` | Optional | Burp/curl — GET by victim id, empty `[]` |
| `evidence/test4-post-403.png`           | Optional | POST to victim shop — 403 response       |
| `evidence/idor_tests_terminal.txt`      | Optional | Full script output (paste of Section 6)  |
| `evidence/burp-proxy-history.png`       | Optional | Flutter sync to `*.supabase.co`          |

Do not commit JWTs, anon keys, or passwords in screenshots.

---

## 10. Root cause analysis (why controls held)

Primary control: **Row Level Security** on tenant tables in [`supabase/migrations/001_init.sql`](../supabase/migrations/001_init.sql).

**Example — `customers_shop_scope`:**

```sql
using (
  exists (
    select 1 from public.shop_memberships m
    where m.user_id = auth.uid()
      and m.shop_id = customers.shop_id
  )
)
```

The same pattern applies to `orders`, `payments`, `measurement_profiles`, and `order_attachments`. Postgres evaluates policies **before** returning rows to PostgREST, so manipulated filters cannot bypass tenancy at the API layer.

**Supporting controls:**

| Control                                      | Role                                                          |
| -------------------------------------------- | ------------------------------------------------------------- |
| `shop_memberships` + `auth.uid()`            | Maps JWT identity → allowed `shop_id`(s)                      |
| `enforce_same_shop_relationships()` triggers | Blocks FK links across shops on insert/update                 |
| `bootstrap_current_user_shop`                | Provisions shop for signed-in user only (`SECURITY DEFINER`)  |
| `app_feedback` insert-only policy            | Prevents reading other users’ feedback from the app           |
| `003_bootstrap_shop_lock.sql`                | Advisory lock reduces duplicate shops on concurrent bootstrap |

**Client behavior:** `SyncService._payloadWithShop` attaches the attacker’s `shop_id` on upsert. Even if an attacker tampered with the body, RLS `WITH CHECK` still applies.

---

## 11. Limitations and residual risk

| Item                                  | Risk level         | Notes                                            |
| ------------------------------------- | ------------------ | ------------------------------------------------ |
| Offline mode (no Supabase configured) | Local              | No API auth; device access = full SQLite read    |
| `service_role` key exposure           | Critical if occurs | Bypasses RLS — must never ship in app            |
| Future tables without RLS             | High               | Any new table needs policies before production   |
| RLS misconfiguration on migration     | High               | Regression-test after every SQL change           |
| Anon key in APK                       | Low (expected)     | Public by design; security relies on RLS + Auth  |
| IDOR on unimplemented endpoints       | N/A                | Re-test when photos, billing, or admin APIs ship |

---

## 12. Remediation and recommendations

### Current posture (all tests passed)

1. **Maintain RLS** on every tenant-scoped table; include policy review in PR checklist for `supabase/migrations/*`.
2. **Never** embed `service_role` in Flutter builds, CI logs, or public repos.
3. **Re-run** `./scripts/security/idor_tests.sh` after auth or schema changes.
4. **Apply** `003_bootstrap_shop_lock.sql` on all environments to limit duplicate-shop races.
5. **Optional:** Add CI job that runs the IDOR script against a disposable Supabase branch.

### If a future test fails

1. Identify the table in Supabase Dashboard → **Policies**.
2. Add or fix `USING` / `WITH CHECK` to require `shop_memberships` join on `shop_id`.
3. Re-run the full matrix; update this report.
4. Rotate keys and review API logs if exposure is suspected.

---

## 13. Conclusion

TailorFlow’s Supabase-backed API **withstands the tested IDOR scenarios** in the security lab. An authenticated attacker with a valid JWT **cannot** read or modify another tailor shop’s customers, orders, or payments using direct object references or `shop_id` manipulation.

**Risk rating for tested BOLA scenarios:** **Low** (controls operating as designed).

Live testing confirms the static design review of `001_init.sql`. Continued assurance depends on keeping RLS enabled and retesting as the API surface grows.

---

## 14. References

- [OWASP API1:2023 — Broken Object Level Authorization](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/)
- [TailorFlow API map](../docs/api-map.md)
- [Security lab setup](../docs/SECURITY_LAB_SETUP.md)
- [RLS migration](../supabase/migrations/001_init.sql)
- [Bootstrap lock migration](../supabase/migrations/003_bootstrap_shop_lock.sql)
- [IDOR test script](../scripts/security/idor_tests.sh)

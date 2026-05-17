# TailorFlow API map (Supabase)

Remote API surface used by the Flutter app when `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set at build time. Base URL:

```text
https://<PROJECT_REF>.supabase.co
```

**Source of truth in code:** `grep -r "client\\.from\\|client\\.rpc\\|client\\.auth" lib/`

See also: [SECURITY_LAB_SETUP.md](SECURITY_LAB_SETUP.md), [idor-testing.md](../reports/idor-testing.md).

---

## Common headers

| Header          | When                   | Value                                                                     |
| --------------- | ---------------------- | ------------------------------------------------------------------------- |
| `apikey`        | Always (REST + Auth)   | Supabase **anon** (public) key                                            |
| `Authorization` | Authenticated REST/RPC | `Bearer <access_token>`                                                   |
| `Content-Type`  | POST/PATCH/PUT bodies  | `application/json`                                                        |
| `Prefer`        | Upserts (SDK)          | `return=representation`, `resolution=merge-duplicates` (client-dependent) |

**Never embed the `service_role` key in the mobile app.** It bypasses RLS.

---

## Authentication (GoTrue) — `/auth/v1`

| Feature                | Path                                      | Method | Code reference                                  |
| ---------------------- | ----------------------------------------- | ------ | ----------------------------------------------- |
| Sign up                | `/auth/v1/signup`                         | POST   | `lib/features/auth/auth_screen.dart` — `signUp` |
| Sign in (password)     | `/auth/v1/token?grant_type=password`      | POST   | `signInWithPassword`                            |
| Refresh session        | `/auth/v1/token?grant_type=refresh_token` | POST   | Supabase SDK (automatic)                        |
| Password reset email   | `/auth/v1/recover`                        | POST   | forgot-password dialog                          |
| Update user / password | `/auth/v1/user`                           | PUT    | `lib/features/auth/update_password_screen.dart` |
| Sign out               | `/auth/v1/logout`                         | POST   | `lib/features/settings/settings_screen.dart`    |

### Obtain JWT (lab curl)

```bash
# Values from lab.env.local — do not commit passwords
curl -s "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"attacker@test.com","password":"YOUR_PASSWORD"}'
```

Response field: `access_token` (JWT). Optional: `refresh_token`.

---

## RPC — `/rest/v1/rpc`

| Function                      | Path                                       | Method | Purpose                                                  |
| ----------------------------- | ------------------------------------------ | ------ | -------------------------------------------------------- |
| `bootstrap_current_user_shop` | `/rest/v1/rpc/bootstrap_current_user_shop` | POST   | Create shop + membership for signed-in user (idempotent) |

**Called from:** `lib/data/sync/supabase_bootstrap.dart`, `auth_screen.dart`, `sync_service.dart`, `update_password_screen.dart`

**Security notes:**

- `SECURITY DEFINER` in [`supabase/migrations/001_init.sql`](../supabase/migrations/001_init.sql)
- Granted to `authenticated` only
- Uses `auth.uid()` — cannot bootstrap another user’s shop

---

## PostgREST — `/rest/v1`

### Tenancy metadata

| Resource           | Typical request                                                     | Method | Code reference           |
| ------------------ | ------------------------------------------------------------------- | ------ | ------------------------ |
| `shop_memberships` | `/rest/v1/shop_memberships?user_id=eq.<uid>&select=shop_id&limit=1` | GET    | `settings_screen.dart`   |
| `shop_memberships` | `/rest/v1/shop_memberships?select=user_id,shop_id`                  | GET    | IDOR test / policy check |

RLS: user sees **only own** membership rows (`user_id = auth.uid()`).

### Customers

| Operation     | Path                                                                                                                                    | Method     | Outbox / sync                                  |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ---------------------------------------------- |
| List (pull)   | `/rest/v1/customers?select=id,name,phone,phone_norm,birth_day,birth_month,birth_year,birthday_consent,created_at,updated_at,deleted_at` | GET        | `_pullCustomers`                               |
| Upsert (push) | `/rest/v1/customers`                                                                                                                    | POST/PATCH | `upsertCustomer`                               |
| Soft delete   | `/rest/v1/customers?id=eq.<id>`                                                                                                         | PATCH      | `deleteCustomer` — body `{"deleted_at": <ms>}` |

**IDOR probe filters:**

```http
GET /rest/v1/customers?id=eq.<VICTIM_CUSTOMER_ID>&select=*
GET /rest/v1/customers?shop_id=eq.<VICTIM_SHOP_ID>&select=*
PATCH /rest/v1/customers?id=eq.<VICTIM_CUSTOMER_ID>
```

Sync injects `shop_id` on upsert: `lib/data/sync/sync_service.dart` — `_payloadWithShop`.

### Measurement profiles

| Operation | Path                                                                                                                            | Method     |
| --------- | ------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| List      | `/rest/v1/measurement_profiles?select=id,customer_id,label,chest,waist,hip,length,sleeve,shoulder,neck,inseam,notes,updated_at` | GET        |
| Upsert    | `/rest/v1/measurement_profiles`                                                                                                 | POST/PATCH |

### Orders

| Operation | Path                                                                                                              | Method     |
| --------- | ----------------------------------------------------------------------------------------------------------------- | ---------- |
| List      | `/rest/v1/orders?select=id,customer_id,title,fabric_note,due_date,status,agreed_amount_ngn,created_at,updated_at` | GET        |
| Upsert    | `/rest/v1/orders`                                                                                                 | POST/PATCH |

**IDOR probe:**

```http
GET /rest/v1/orders?customer_id=eq.<VICTIM_CUSTOMER_ID>&select=id,title
```

### Payments

| Operation | Path                                                           | Method     |
| --------- | -------------------------------------------------------------- | ---------- |
| List      | `/rest/v1/payments?select=id,order_id,amount_ngn,paid_at,note` | GET        |
| Upsert    | `/rest/v1/payments`                                            | POST/PATCH |

### Order attachments

| Operation | Path                                                                              | Method     |
| --------- | --------------------------------------------------------------------------------- | ---------- |
| List      | `/rest/v1/order_attachments?select=id,order_id,image_base64,mime_type,created_at` | GET        |
| Upsert    | `/rest/v1/order_attachments`                                                      | POST/PATCH |

**Note:** `image_base64` in Postgres is sensitive; large payloads — consider Storage migration (product roadmap).

### App feedback

| Operation        | Path                             | Method | Code reference                                                 |
| ---------------- | -------------------------------- | ------ | -------------------------------------------------------------- |
| Insert           | `/rest/v1/app_feedback`          | POST   | `feedback_remote.dart`, `customer_feedback_remote.dart`        |
| Select (clients) | `/rest/v1/app_feedback?select=*` | GET    | **No SELECT policy** for app users — expect `[]` or RLS denial |

Insert policy: `user_id = auth.uid()` ([`002_app_feedback.sql`](../supabase/migrations/002_app_feedback.sql)).

---

## Authorization model (summary)

| Layer        | Mechanism                                                                      |
| ------------ | ------------------------------------------------------------------------------ |
| API gateway  | JWT required for authenticated routes                                          |
| Postgres RLS | `shop_memberships` join on `shop_id` for tenant tables                         |
| Triggers     | `enforce_same_shop_relationships()` — FK consistency within shop               |
| Client       | Injects attacker’s `shop_id` on sync upsert — must still pass RLS `WITH CHECK` |

Policies defined in [`supabase/migrations/001_init.sql`](../supabase/migrations/001_init.sql): `customers_shop_scope`, `orders_shop_scope`, etc.

---

## Offline mode (no API)

If `SUPABASE_URL` / `SUPABASE_ANON_KEY` are empty, `lib/app.dart` skips auth and uses **local SQLite only**. No remote endpoints; device loss = full data exposure (separate threat).

---

## Automated IDOR checks

```bash
./scripts/security/idor_tests.sh --discover-victim
./scripts/security/idor_tests.sh
```

---

## Changelog

| Date       | Change                                |
| ---------- | ------------------------------------- |
| 2026-05-16 | Initial map from MVP sync + auth code |

#!/usr/bin/env bash
# TailorFlow IDOR / BOLA lab tests (Supabase PostgREST + RLS).
# Usage:
#   cp lab.env.local.example lab.env.local   # fill credentials
#   ./scripts/security/idor_tests.sh --discover-victim
#   ./scripts/security/idor_tests.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="${ROOT}/lab.env.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy lab.env.local.example and configure." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a && source "$ENV_FILE" && set +a

require_var() {
  if [[ -z "${!1:-}" ]]; then
    echo "Set $1 in lab.env.local" >&2
    exit 1
  fi
}

require_var SUPABASE_URL
require_var SUPABASE_ANON_KEY
require_var ATTACKER_EMAIL
require_var ATTACKER_PASSWORD

warn_placeholder_passwords() {
  local bad=0
  if [[ "${ATTACKER_PASSWORD:-}" == "change_me_strong_password" ]]; then
    echo "ERROR: ATTACKER_PASSWORD is still the example placeholder in lab.env.local." >&2
    bad=1
  fi
  if [[ "${VICTIM_PASSWORD:-}" == "change_me_strong_password" ]]; then
    echo "ERROR: VICTIM_PASSWORD is still the example placeholder in lab.env.local." >&2
    bad=1
  fi
  if [[ "$bad" -eq 1 ]]; then
    echo "" >&2
    echo "Set passwords to the EXACT values used when you signed up in the Flutter app" >&2
    echo "(or reset them in Supabase Dashboard → Authentication → Users)." >&2
    exit 1
  fi
}

auth_token() {
  local email="$1" password="$2"
  curl -sS "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}"
}

extract_access_token() {
  python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || true
}

# Prints human-readable auth failure hints (does not print passwords).
login_failed_help() {
  local role="$1" email="$2" resp="$3"
  echo "" >&2
  echo "=== $role login failed ===" >&2
  echo "$resp" >&2
  echo "" >&2
  if echo "$resp" | grep -q 'invalid_credentials'; then
    echo "Likely causes:" >&2
    echo "  • Password in lab.env.local does not match the app signup password for $email" >&2
    echo "  • User was never created — sign up in the app or Dashboard → Authentication → Users" >&2
    echo "  • Typo in VICTIM_EMAIL / ATTACKER_EMAIL" >&2
  fi
  if echo "$resp" | grep -qi 'email_not_confirmed'; then
    echo "  • Email confirmation is ON — confirm the user or disable it for the lab (Auth → Providers → Email)" >&2
  fi
  echo "" >&2
  echo "Fix: edit lab.env.local, then run: $0 --check-auth" >&2
  echo "Or discover IDs without login — Supabase SQL Editor:" >&2
  echo "  select u.email, m.shop_id from auth.users u join shop_memberships m on m.user_id = u.id;" >&2
  echo "  select id, shop_id, name from customers limit 10;" >&2
}

login_user() {
  local role="$1" email="$2" password="$3"
  local resp token
  resp="$(auth_token "$email" "$password")"
  token="$(echo "$resp" | extract_access_token)"
  if [[ -z "$token" ]]; then
    login_failed_help "$role" "$email" "$resp"
    return 1
  fi
  echo "$token"
}

check_auth() {
  warn_placeholder_passwords
  require_var VICTIM_EMAIL
  require_var VICTIM_PASSWORD
  echo "Checking lab credentials against ${SUPABASE_URL} ..."
  echo ""
  if token="$(login_user "Attacker" "$ATTACKER_EMAIL" "$ATTACKER_PASSWORD")"; then
    echo "OK  attacker ($ATTACKER_EMAIL) — JWT obtained"
  else
    echo "FAIL attacker ($ATTACKER_EMAIL)"
    exit 1
  fi
  if token="$(login_user "Victim" "$VICTIM_EMAIL" "$VICTIM_PASSWORD")"; then
    echo "OK  victim   ($VICTIM_EMAIL) — JWT obtained"
  else
    echo "FAIL victim   ($VICTIM_EMAIL)"
    exit 1
  fi
  echo ""
  echo "Auth looks good. Run: $0 --discover-victim"
}

api_get() {
  local token="$1" path="$2"
  curl -sS -w "\n%{http_code}" "${SUPABASE_URL}${path}" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/json"
}

api_patch() {
  local token="$1" path="$2" body="$3"
  curl -sS -w "\n%{http_code}" -X PATCH "${SUPABASE_URL}${path}" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "$body"
}

api_post() {
  local token="$1" path="$2" body="$3"
  curl -sS -w "\n%{http_code}" -X POST "${SUPABASE_URL}${path}" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "$body"
}

split_body_status() {
  BODY="$(echo "$1" | sed '$d')"
  STATUS="$(echo "$1" | tail -n 1)"
}

pass_if_empty_or_denied() {
  local body="$1" status="$2"
  if [[ "$status" == "403" ]] || echo "$body" | grep -qi "row-level security"; then
    echo "PASS"
    return
  fi
  if [[ "$body" == "[]" ]] || [[ "$body" == "{}" ]]; then
    echo "PASS"
    return
  fi
  # Non-empty JSON array with objects = likely data leak
  if echo "$body" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if isinstance(d,list) and len(d)>0 else 1)" 2>/dev/null; then
    echo "FAIL"
    return
  fi
  echo "PASS"
}

discover_victim() {
  warn_placeholder_passwords
  require_var VICTIM_EMAIL
  require_var VICTIM_PASSWORD
  echo "Signing in as victim to discover IDs..."
  TOKEN="$(login_user "Victim" "$VICTIM_EMAIL" "$VICTIM_PASSWORD")" || exit 1
  RAW="$(api_get "$TOKEN" "/rest/v1/customers?select=id,shop_id,name&limit=5")"
  split_body_status "$RAW"
  echo "Victim customers (first 5):"
  echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
  RAW="$(api_get "$TOKEN" "/rest/v1/shop_memberships?select=shop_id&limit=1")"
  split_body_status "$RAW"
  echo "Victim shop_memberships:"
  echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
  echo ""
  echo "Add to lab.env.local:"
  echo "  VICTIM_CUSTOMER_ID=<id from first customer row>"
  echo "  VICTIM_SHOP_ID=<shop_id uuid>"
}

run_tests() {
  warn_placeholder_passwords
  require_var VICTIM_CUSTOMER_ID
  require_var VICTIM_SHOP_ID

  echo "Signing in as attacker..."
  TOKEN="$(login_user "Attacker" "$ATTACKER_EMAIL" "$ATTACKER_PASSWORD")" || exit 1

  echo ""
  echo "=== TailorFlow IDOR test matrix (attacker JWT) ==="
  echo ""

  # Test 1
  RAW="$(api_get "$TOKEN" "/rest/v1/customers?id=eq.${VICTIM_CUSTOMER_ID}&select=id,name,shop_id")"
  split_body_status "$RAW"
  R="$(pass_if_empty_or_denied "$BODY" "$STATUS")"
  echo "Test 1  GET customer by victim id     → $R (HTTP $STATUS)"

  # Test 2
  RAW="$(api_get "$TOKEN" "/rest/v1/customers?shop_id=eq.${VICTIM_SHOP_ID}&select=id,name")"
  split_body_status "$RAW"
  R="$(pass_if_empty_or_denied "$BODY" "$STATUS")"
  echo "Test 2  GET customers by victim shop → $R (HTTP $STATUS)"

  # Test 3
  RAW="$(api_patch "$TOKEN" "/rest/v1/customers?id=eq.${VICTIM_CUSTOMER_ID}" '{"name":"PWNED"}')"
  split_body_status "$RAW"
  R="$(pass_if_empty_or_denied "$BODY" "$STATUS")"
  echo "Test 3  PATCH victim customer        → $R (HTTP $STATUS)"

  # Test 4
  NEW_ID="lab-idor-probe-$(date +%s)"
  NOW_MS="$(python3 -c "import time; print(int(time.time()*1000))")"
  BODY_JSON="$(cat <<EOF
[{"id":"${NEW_ID}","shop_id":"${VICTIM_SHOP_ID}","name":"IDOR Probe","phone_norm":"","created_at":${NOW_MS},"updated_at":${NOW_MS}}]
EOF
)"
  RAW="$(api_post "$TOKEN" "/rest/v1/customers" "$BODY_JSON")"
  split_body_status "$RAW"
  R="$(pass_if_empty_or_denied "$BODY" "$STATUS")"
  echo "Test 4  POST customer in victim shop → $R (HTTP $STATUS)"

  # Test 5a
  RAW="$(api_get "$TOKEN" "/rest/v1/orders?customer_id=eq.${VICTIM_CUSTOMER_ID}&select=id,title")"
  split_body_status "$RAW"
  R="$(pass_if_empty_or_denied "$BODY" "$STATUS")"
  echo "Test 5a GET orders for victim customer → $R (HTTP $STATUS)"

  # Test 5b — cross-tenant: payments in victim's shop (not "empty list" — attacker may have own payments)
  RAW="$(api_get "$TOKEN" "/rest/v1/payments?shop_id=eq.${VICTIM_SHOP_ID}&select=id,order_id,amount_ngn")"
  split_body_status "$RAW"
  R="$(pass_if_empty_or_denied "$BODY" "$STATUS")"
  echo "Test 5b GET payments in victim shop  → $R (HTTP $STATUS)"

  # Test 6
  RAW="$(api_get "$TOKEN" "/rest/v1/app_feedback?select=id,subject&limit=10")"
  split_body_status "$RAW"
  R="$(pass_if_empty_or_denied "$BODY" "$STATUS")"
  echo "Test 6  GET app_feedback             → $R (HTTP $STATUS)"

  # Test 7 — must not see victim's shop_id; multiple own rows = duplicate bootstrap (data issue, not IDOR)
  RAW="$(api_get "$TOKEN" "/rest/v1/shop_memberships?select=user_id,shop_id")"
  split_body_status "$RAW"
  R="$(VICTIM_SHOP_ID="$VICTIM_SHOP_ID" BODY="$BODY" python3 <<'PY'
import json, os
body = os.environ.get("BODY", "[]")
victim_shop = os.environ.get("VICTIM_SHOP_ID", "")
try:
    rows = json.loads(body)
except json.JSONDecodeError:
    print("REVIEW")
    raise SystemExit(0)
if not isinstance(rows, list):
    print("REVIEW")
    raise SystemExit(0)
for r in rows:
    if str(r.get("shop_id", "")) == victim_shop:
        print("FAIL")
        raise SystemExit(0)
if len(rows) == 0:
    print("PASS")
elif len(rows) == 1:
    print("PASS")
else:
    print(f"PASS ({len(rows)} own memberships — duplicate shop bootstrap; run lab_cleanup_duplicate_shops.sql)")
PY
)"
  echo "Test 7  GET shop_memberships         → $R (HTTP $STATUS)"

  # Bonus: no auth
  RAW="$(curl -sS -w "\n%{http_code}" "${SUPABASE_URL}/rest/v1/customers?select=id&limit=1" \
    -H "apikey: ${SUPABASE_ANON_KEY}" -H "Accept: application/json")"
  split_body_status "$RAW"
  if [[ "$STATUS" == "401" ]] || [[ "$BODY" == "[]" ]]; then
    echo "Bonus   GET customers without JWT    → PASS (HTTP $STATUS)"
  else
    echo "Bonus   GET customers without JWT    → REVIEW (HTTP $STATUS)"
  fi

  echo ""
  echo "Done. Record results in reports/idor-testing.md and add Burp screenshots to reports/evidence/"
}

case "${1:-}" in
  --check-auth)
    check_auth
    ;;
  --discover-victim)
    discover_victim
    ;;
  -h|--help)
    echo "Usage: $0 [--check-auth | --discover-victim]"
    echo ""
    echo "  --check-auth       Verify attacker + victim passwords in lab.env.local"
    echo "  --discover-victim  Print VICTIM_CUSTOMER_ID / VICTIM_SHOP_ID for lab.env.local"
    ;;
  *)
    run_tests
    ;;
esac

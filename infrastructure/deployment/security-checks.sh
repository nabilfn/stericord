#!/usr/bin/env bash
# Automated security regression suite (master prompt section 41: "Security
# testing"). Every check here asserts a specific negative -- that an attack
# a real hospital's InfoSec review would try is actually blocked -- rather
# than re-testing normal happy-path behavior already covered elsewhere.
#
# Requires a running local Supabase stack (`supabase start`) seeded with
# supabase/seed.sql. Exits non-zero if any check fails.
#
# Usage: ./security-checks.sh [db-host] [db-port] [api-url]
set -uo pipefail

DB_HOST="${1:-127.0.0.1}"
DB_PORT="${2:-54422}"
API_URL="${3:-http://127.0.0.1:54421}"
PSQL="psql -h $DB_HOST -p $DB_PORT -U postgres -d postgres -tA"
export PGPASSWORD=postgres

PASS=0
FAIL=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

HOSPITAL_A_ADMIN="00000000-0000-0000-0000-0000000a1001"
HOSPITAL_A_TECH="00000000-0000-0000-0000-0000000a1003"
HOSPITAL_B_ADMIN="00000000-0000-0000-0000-0000000b1001"
HOSPITAL_A_ORG="00000000-0000-0000-0000-000000000a01"

STRIP_TAGS='^(BEGIN|SET|ROLLBACK|COMMIT|INSERT [0-9]+ [0-9]+|UPDATE [0-9]+|DELETE [0-9]+)$'

# Runs $sql as the given user via a per-statement JWT claim, then strips psql's
# transaction/command-tag noise (BEGIN, SET, ROLLBACK, "UPDATE n") so callers get
# only the actual result rows the $sql itself selected -- those tags print
# regardless of -t, they are not result data.
as_user() {
  local user_id="$1" sql="$2"
  $PSQL <<EOF | grep -vE "$STRIP_TAGS"
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$user_id","role":"authenticated"}';
$sql
rollback;
EOF
}

echo "== Tenant isolation =="

RESULT=$(as_user "$HOSPITAL_B_ADMIN" "select count(*) from public.equipment where organization_id = '$HOSPITAL_A_ORG';")
check "Hospital B cannot read Hospital A equipment" "0" "$(echo "$RESULT" | tr -d '[:space:]')"

RESULT=$(as_user "$HOSPITAL_B_ADMIN" "select count(*) from public.audit_events where organization_id = '$HOSPITAL_A_ORG';")
check "Hospital B cannot read Hospital A audit events" "0" "$(echo "$RESULT" | tr -d '[:space:]')"


RESULT=$(as_user "$HOSPITAL_B_ADMIN" "select verify_audit_chain('$HOSPITAL_A_ORG');" 2>&1 | grep -c "ERROR\|Not authorized" || true)
check "Hospital B cannot verify Hospital A's audit chain" "1" "$RESULT"

echo "== Write-path bypass (state machines must go through SECURITY DEFINER functions only) =="

EQUIP_ID=$($PSQL -c "select id from public.equipment where organization_id = '$HOSPITAL_A_ORG' limit 1;" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
RESULT=$(as_user "$HOSPITAL_A_TECH" "update public.equipment set operating_status = 'DECOMMISSIONED' where id = '$EQUIP_ID'; select operating_status from public.equipment where id = '$EQUIP_ID';")
check "Technician cannot decommission equipment (UPDATE policy requires admin/supervisor/biomed role)" "ACTIVE" "$(echo "$RESULT" | tr -d '[:space:]')"

BEFORE=$($PSQL -c "select count(*) from public.audit_events where organization_id = '$HOSPITAL_A_ORG';" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
RESULT=$(as_user "$HOSPITAL_A_ADMIN" "delete from public.audit_events where organization_id = '$HOSPITAL_A_ORG'; select count(*) from public.audit_events where organization_id = '$HOSPITAL_A_ORG';")
check "Audit events cannot be deleted (no DELETE policy, table is append-only)" "$BEFORE" "$(echo "$RESULT" | tr -d '[:space:]')"

echo "== Role authorization on write functions =="

TEST_CYCLE_NUMBER="SEC-TEST-$(date +%s)"
CYCLE_ID=$($PSQL -c "
  insert into public.sterilization_cycles (organization_id, equipment_id, cycle_number, cycle_type, cycle_status, operator_user_id)
  values ('$HOSPITAL_A_ORG', '$EQUIP_ID', '$TEST_CYCLE_NUMBER', 'STEAM', 'PENDING_VERIFICATION', '$HOSPITAL_A_TECH')
  returning id;
" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
RESULT=$(as_user "$HOSPITAL_A_TECH" "select verify_cycle('$CYCLE_ID', 'PASS');" 2>&1 | grep -c "ERROR\|Only a CSSD supervisor" || true)
check "CSSD technician cannot verify a cycle (supervisor/admin only)" "1" "$RESULT"
$PSQL -c "delete from public.sterilization_cycles where id = '$CYCLE_ID';" > /dev/null

echo "== Storage bucket privacy =="

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/storage/v1/object/evidence/${HOSPITAL_A_ORG}/does-not-matter.jpg")
check "Anonymous request to evidence bucket is rejected" "400" "$HTTP_CODE"
# 400/401/404 are all "not served" outcomes depending on Storage API version; the one
# unacceptable result is 200 (an actual file byte-stream returned with no auth at all).
if [ "$HTTP_CODE" = "200" ]; then
  echo "FAIL: evidence bucket served a file with zero authentication"
  FAIL=$((FAIL + 1))
  PASS=$((PASS - 1))
fi

echo "== Direct PostgREST access without a JWT =="

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/rest/v1/equipment")
check "PostgREST rejects requests with no apikey/authorization at all" "401" "$HTTP_CODE"

echo ""
echo "== Summary: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]

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
HOSPITAL_A_SUPERVISOR="00000000-0000-0000-0000-0000000a1002"
HOSPITAL_A_TECH="00000000-0000-0000-0000-0000000a1003"
HOSPITAL_A_NURSE="00000000-0000-0000-0000-0000000a1004"
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

echo "== D-01: equipment audit coverage (QA finding FF-04) =="

TEST_EQUIP_CODE="AUDIT-TEST-$(date +%s)"
# Needs to actually commit (unlike as_user, which always rolls back) so the
# trigger's audit_events rows are still there to inspect afterward.
EQUIP_TEST_ID=$($PSQL <<EOF | grep -vE "$STRIP_TAGS" | tr -d '[:space:]'
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$HOSPITAL_A_ADMIN","role":"authenticated"}';
insert into public.equipment (organization_id, equipment_code, equipment_type)
  values ('$HOSPITAL_A_ORG', '$TEST_EQUIP_CODE', 'OTHER') returning id;
commit;
EOF
)
$PSQL <<EOF > /dev/null
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$HOSPITAL_A_ADMIN","role":"authenticated"}';
update public.equipment set operating_status = 'MAINTENANCE' where id = '$EQUIP_TEST_ID';
update public.equipment set location = 'Regression test room' where id = '$EQUIP_TEST_ID';
commit;
EOF
RESULT=$($PSQL -c "select string_agg(event_type::text, ',' order by occurred_at) from public.audit_events where entity_id = '$EQUIP_TEST_ID';" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
check "Equipment create+status-change+metadata-edit produce exactly EQUIPMENT_CREATED,EQUIPMENT_STATUS_CHANGED,EQUIPMENT_UPDATED" "EQUIPMENT_CREATED,EQUIPMENT_STATUS_CHANGED,EQUIPMENT_UPDATED" "$RESULT"
$PSQL -c "delete from public.equipment where id = '$EQUIP_TEST_ID';" > /dev/null

echo "== D-02: quarantine_pack atomicity (QA finding FF-06) =="

TEST_PACK_CODE="AUDIT-PACK-$(date +%s)"
EQUIP_FOR_PACK=$($PSQL -c "select id from public.equipment where organization_id = '$HOSPITAL_A_ORG' limit 1;" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
INSTRUMENT_SET=$($PSQL -c "select id from public.instrument_sets where organization_id = '$HOSPITAL_A_ORG' limit 1;" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
CYCLE_FOR_PACK=$($PSQL -c "
  insert into public.sterilization_cycles (organization_id, equipment_id, cycle_number, cycle_type, cycle_status)
  values ('$HOSPITAL_A_ORG', '$EQUIP_FOR_PACK', '$TEST_PACK_CODE', 'STEAM', 'CREATED') returning id;
" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
# Packs can only be INSERTed as PACKED (a trigger enforces it) then moved
# on by a separate UPDATE -- matches the real app's own registration flow.
PACK_TEST_ID=$($PSQL -c "
  insert into public.instrument_packs (organization_id, instrument_set_id, sterilization_cycle_id, pack_code, status)
  values ('$HOSPITAL_A_ORG', '$INSTRUMENT_SET', '$CYCLE_FOR_PACK', '$TEST_PACK_CODE', 'PACKED') returning id;
" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
$PSQL -c "update public.instrument_packs set status = 'PENDING_VERIFICATION' where id = '$PACK_TEST_ID';" > /dev/null
$PSQL <<EOF > /dev/null
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$HOSPITAL_A_SUPERVISOR","role":"authenticated"}';
select quarantine_pack('$PACK_TEST_ID', 'Regression test quarantine');
commit;
EOF
RESULT=$($PSQL -c "select count(*) from public.quarantines where scope_id = '$PACK_TEST_ID';" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
check "quarantine_pack() creates exactly one quarantines row" "1" "$RESULT"

REPEAT=$($PSQL <<EOF 2>&1 | grep -c "cannot be quarantined"
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$HOSPITAL_A_SUPERVISOR","role":"authenticated"}';
select quarantine_pack('$PACK_TEST_ID', 'Second attempt');
rollback;
EOF
)
check "Repeat quarantine_pack() on an already-quarantined pack is rejected" "1" "$REPEAT"
RESULT=$($PSQL -c "select count(*) from public.quarantines where scope_id = '$PACK_TEST_ID';" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
check "Rejected repeat attempt created no duplicate quarantines row" "1" "$RESULT"

echo "== D-03: incident lifecycle audit events (QA finding FF-14) =="

INCIDENT_TEST_ID=$($PSQL -c "
  insert into public.incidents (organization_id, source_type, related_entity_type, related_entity_id, status, priority, detected_by)
  values ('$HOSPITAL_A_ORG', 'OT_VERIFICATION_FAILURE', 'instrument_pack', gen_random_uuid(), 'ALERTED', 'CRITICAL', '$HOSPITAL_A_NURSE')
  returning id;
" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
$PSQL <<EOF > /dev/null
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$HOSPITAL_A_SUPERVISOR","role":"authenticated"}';
select acknowledge_incident('$INCIDENT_TEST_ID');
select advance_incident_status('$INCIDENT_TEST_ID', 'REPLACEMENT_DISPATCHED');
select resolve_incident('$INCIDENT_TEST_ID', 'Regression test resolution', false);
select resolve_incident('$INCIDENT_TEST_ID', 'Regression test closure', true);
commit;
EOF
RESULT=$($PSQL -c "select string_agg(event_type::text, ',' order by occurred_at) from public.audit_events where entity_id = '$INCIDENT_TEST_ID';" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
check "Full incident lifecycle emits exactly the 4 correctly-named events, no INCIDENT_CREATED copy-paste" "INCIDENT_ACKNOWLEDGED,INCIDENT_REPLACEMENT_DISPATCHED,INCIDENT_RESOLVED,INCIDENT_CLOSED" "$RESULT"

INCIDENT_TEST_ID_2=$($PSQL -c "
  insert into public.incidents (organization_id, source_type, related_entity_type, related_entity_id, status, priority, detected_by)
  values ('$HOSPITAL_A_ORG', 'OT_VERIFICATION_FAILURE', 'instrument_pack', gen_random_uuid(), 'ALERTED', 'HIGH', '$HOSPITAL_A_NURSE')
  returning id;
" | grep -vE "$STRIP_TAGS" | tr -d '[:space:]')
EMPTY_NOTES=$($PSQL <<EOF 2>&1 | grep -c "Resolution notes are required"
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$HOSPITAL_A_SUPERVISOR","role":"authenticated"}';
select resolve_incident('$INCIDENT_TEST_ID_2', '   ', false);
rollback;
EOF
)
check "Empty resolution notes are rejected" "1" "$EMPTY_NOTES"
NURSE_ADVANCE=$(as_user "$HOSPITAL_A_NURSE" "select acknowledge_incident('$INCIDENT_TEST_ID');" 2>&1 | grep -c "Not authorized")
check "Nurse cannot acknowledge an incident" "1" "$NURSE_ADVANCE"
REGRESSION=$($PSQL <<EOF 2>&1 | grep -c "cannot be moved further"
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$HOSPITAL_A_SUPERVISOR","role":"authenticated"}';
select advance_incident_status('$INCIDENT_TEST_ID', 'ACKNOWLEDGED');
rollback;
EOF
)
check "Cannot advance a CLOSED incident (terminal-state regression rejected)" "1" "$REGRESSION"

echo "== D-07: deactivated profile loses access immediately (QA finding FF-20) =="

BEFORE=$(as_user "$HOSPITAL_A_TECH" "select count(*) from public.equipment where organization_id = '$HOSPITAL_A_ORG';")
$PSQL -c "update public.profiles set is_active = false where id = '$HOSPITAL_A_TECH';" > /dev/null
AFTER=$(as_user "$HOSPITAL_A_TECH" "select count(*) from public.equipment where organization_id = '$HOSPITAL_A_ORG';")
$PSQL -c "update public.profiles set is_active = true where id = '$HOSPITAL_A_TECH';" > /dev/null
check "Deactivated profile's role-gated read returns 0 rows where an active one saw $(echo "$BEFORE" | tr -d '[:space:]')" "0" "$(echo "$AFTER" | tr -d '[:space:]')"

echo "== D-08: deactivated login/refresh returns a controlled 403, not 500 (QA retest 2026-09-06) =="

ANON_KEY=$(node -e "
  const { execSync } = require('child_process');
  const out = execSync('supabase status -o json').toString();
  console.log(JSON.parse(out).ANON_KEY);
")

token_response() {
  curl -sS -w '\n%{http_code}' -X POST "$API_URL/auth/v1/token?grant_type=$1" \
    -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -d "$2"
}

RESP=$(token_response password '{"email":"nurse@hospital-a.test","password":"SteriCord!2026"}')
REFRESH_TOKEN=$(echo "$RESP" | head -n1 | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{console.log(JSON.parse(d).refresh_token||'')}catch(e){console.log('')}})")
check "Active nurse login succeeds before deactivation" "200" "$(echo "$RESP" | tail -n1)"

$PSQL -c "update public.profiles set is_active = false where id = '$HOSPITAL_A_NURSE';" > /dev/null

RESP=$(token_response password '{"email":"nurse@hospital-a.test","password":"SteriCord!2026"}')
CODE=$(echo "$RESP" | tail -n1)
BODY=$(echo "$RESP" | head -n1)
check "Deactivated password login returns 403, not 500" "403" "$CODE"
check "Deactivated login body is the stable message, not a raw Postgres error" "1" "$(echo "$BODY" | grep -c "Account is deactivated")"
check "Deactivated login body does not leak the raw SQLSTATE/error code" "0" "$(echo "$BODY" | grep -c "P0001")"

CODE=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$API_URL/auth/v1/token?grant_type=refresh_token" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH_TOKEN\"}")
check "Refreshing a deactivated user's pre-existing token returns 403, not 500" "403" "$CODE"

CODE=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$API_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"nurse@hospital-a.test","password":"totally-wrong"}')
check "Wrong password for a deactivated user is still a normal 400 (not swallowed into 403)" "400" "$CODE"

CODE=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$API_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"technician@hospital-a.test","password":"SteriCord!2026"}')
check "A different, still-active user's login is unaffected by the hook" "200" "$CODE"

$PSQL -c "update public.profiles set is_active = true where id = '$HOSPITAL_A_NURSE';" > /dev/null

CODE=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$API_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"nurse@hospital-a.test","password":"SteriCord!2026"}')
check "Reactivated user can log in again immediately (no caching/staleness)" "200" "$CODE"

echo ""
echo "== Summary: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]

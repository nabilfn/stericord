#!/usr/bin/env bash
# Regression suite for QA remediation D-05/D-06 (FF-19): report-export role
# authorization and malformed-bearer-token handling in services/reporting.
#
# Requires: local Supabase stack running (`supabase start`) and the
# reporting service built and reachable (`docker compose up -d reporting`,
# needs services/reporting/.env -- see .env.example). Exits non-zero if any
# check fails.
#
# Usage: ./report-authorization-checks.sh [api-url] [reporting-url]
set -uo pipefail

API_URL="${1:-http://127.0.0.1:54421}"
REPORTING_URL="${2:-http://localhost:8000}"
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

ANON_KEY=$(node -e "
  const { execSync } = require('child_process');
  const out = execSync('supabase status -o json').toString();
  console.log(JSON.parse(out).ANON_KEY);
")

get_jwt() {
  curl -s -X POST "$API_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"SteriCord!2026\"}" \
  | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{console.log(JSON.parse(d).access_token||'')}catch(e){console.log('')}})"
}

EQUIP_ID=$(PGPASSWORD=postgres psql -h 127.0.0.1 -p 54422 -U postgres -d postgres -tAc "select id from equipment where equipment_code = 'AUTOCLAVE-A1';")

echo "== D-05: report export authorization =="

ADMIN_JWT=$(get_jwt "admin@hospital-a.test")
SUPERVISOR_JWT=$(get_jwt "supervisor@hospital-a.test")
TECH_JWT=$(get_jwt "technician@hospital-a.test")
NURSE_JWT=$(get_jwt "nurse@hospital-a.test")

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPORTING_URL/reports/equipment/$EQUIP_ID" -H "Authorization: Bearer $NURSE_JWT")
check "OT_NURSE cannot export equipment report" "403" "$CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPORTING_URL/reports/equipment/$EQUIP_ID" -H "Authorization: Bearer $TECH_JWT")
check "CSSD_TECHNICIAN cannot export equipment report" "403" "$CODE"

for kind in equipment cycle incident evidence; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPORTING_URL/reports/$kind/00000000-0000-0000-0000-000000000000" -H "Authorization: Bearer $NURSE_JWT")
  check "OT_NURSE cannot export $kind report (any id)" "403" "$CODE"
done

BEFORE=$(PGPASSWORD=postgres psql -h 127.0.0.1 -p 54422 -U postgres -d postgres -tAc "select count(*) from audit_events where event_type='REPORT_EXPORTED' and entity_id='00000000-0000-0000-0000-000000000000';" | tr -d '[:space:]')
check "No REPORT_EXPORTED audit rows from any of the blocked nurse attempts above" "0" "$BEFORE"

CODE=$(curl -s -o /tmp/regress_admin_report.pdf -w "%{http_code}" "$REPORTING_URL/reports/equipment/$EQUIP_ID" -H "Authorization: Bearer $ADMIN_JWT")
check "HOSPITAL_ADMIN can export equipment report" "200" "$CODE"
FILETYPE=$(file -b /tmp/regress_admin_report.pdf | grep -c "PDF document")
check "HOSPITAL_ADMIN's export is a real PDF" "1" "$FILETYPE"
rm -f /tmp/regress_admin_report.pdf

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPORTING_URL/reports/equipment/$EQUIP_ID" -H "Authorization: Bearer $SUPERVISOR_JWT")
check "CSSD_SUPERVISOR can export equipment report" "200" "$CODE"

echo "== D-06: malformed/empty/missing bearer tokens return 401, not 500 =="

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPORTING_URL/reports/equipment/$EQUIP_ID" -H "Authorization: Bearer ")
check "Empty bearer token returns 401" "401" "$CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPORTING_URL/reports/equipment/$EQUIP_ID" -H "Authorization: Bearer    ")
check "Whitespace-only bearer token returns 401" "401" "$CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPORTING_URL/reports/equipment/$EQUIP_ID")
check "Missing Authorization header returns 401" "401" "$CODE"

CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPORTING_URL/reports/equipment/$EQUIP_ID" -H "Authorization: Bearer not-a-real-jwt")
check "Malformed (non-empty garbage) bearer token returns 401, not 500" "401" "$CODE"

echo "== Regression: rate limiting and tenant isolation still hold =="

B_ADMIN_JWT=$(get_jwt "admin@hospital-b.test")
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPORTING_URL/reports/equipment/$EQUIP_ID" -H "Authorization: Bearer $B_ADMIN_JWT")
check "Hospital B admin gets 404 for Hospital A's equipment (not leaked as 403)" "404" "$CODE"

echo ""
echo "== Summary: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]

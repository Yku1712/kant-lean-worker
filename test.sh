#!/usr/bin/env bash
# End-to-end test suite for kant-lean-worker.
# Assumes the server is running on 127.0.0.1:8080.

set -u
BASE="http://127.0.0.1:8080"
PASS=0
FAIL=0

check_status() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ $name ($actual)"
    PASS=$((PASS+1))
  else
    echo "  ✗ $name (expected $expected, got $actual)"
    FAIL=$((FAIL+1))
  fi
}

check_contains() {
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "  ✓ $name"
    PASS=$((PASS+1))
  else
    echo "  ✗ $name (missing: $needle)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== 1. Index route ==="
out=$(curl -sS --max-time 5 "$BASE/")
check_contains "index responds" "lean-worker" "$out"

echo "=== 2. GET known CID (seed) ==="
out=$(curl -sS --max-time 5 "$BASE/api/erdfa/bafkda5130a0825c7afe")
check_contains "shard matches seed" '"erdfa:shard": "2,13,34"' "$out"
check_contains "crt computed" '"erdfa:crt": "154711"' "$out"

echo "=== 3. GET unknown CID (monsterHash fallback) ==="
out=$(curl -sS --max-time 5 "$BASE/api/erdfa/crank_alpha")
check_contains "monsterHash derived shard" '"erdfa:shard": "11,19,9"' "$out"

echo "=== 4. POST valid payload (Zero Trust pass) ==="
status=$(curl -sS -o /tmp/.out -w "%{http_code}" --max-time 5 -X POST "$BASE/api/erdfa/submit" \
  -H "Content-Type: application/json" \
  -d '{"cid":"test_valid_001","erdfa:shard":"26,4,44","erdfa:prime":"1","erdfa:encoding":"raw","dasl:addr":"0xda5153b060412dff","dasl:type":"5","dasl:eigenspace":"Earth","dasl:bott":"6 (R(8))","dasl:hecke":"T_71","sheaf:orbifold":"(26 mod 71, 4 mod 59, 44 mod 47)","sheaf:subgroupIndex":"erdfa:H/raw"}')
check_status "valid POST returns 200" "200" "$status"
check_contains "CRT returned" '"crt": "75996"' "$(cat /tmp/.out)"

echo "=== 5. POST tampered orbifold (should fail) ==="
status=$(curl -sS -o /tmp/.out -w "%{http_code}" --max-time 5 -X POST "$BASE/api/erdfa/submit" \
  -H "Content-Type: application/json" \
  -d '{"cid":"test_bad_orb","erdfa:shard":"26,4,44","erdfa:prime":"1","erdfa:encoding":"raw","dasl:addr":"0xda5153b060412dff","dasl:type":"5","dasl:eigenspace":"Earth","dasl:bott":"6 (R(8))","dasl:hecke":"T_71","sheaf:orbifold":"(99 mod 71, 4 mod 59, 44 mod 47)","sheaf:subgroupIndex":"erdfa:H/raw"}')
check_status "tampered orbifold returns 422" "422" "$status"

echo "=== 6. POST bad DA51 type (should fail) ==="
status=$(curl -sS -o /tmp/.out -w "%{http_code}" --max-time 5 -X POST "$BASE/api/erdfa/submit" \
  -H "Content-Type: application/json" \
  -d '{"cid":"test_bad_type","erdfa:shard":"26,4,44","erdfa:prime":"1","erdfa:encoding":"raw","dasl:addr":"0xda5153b060412dff","dasl:type":"3","dasl:eigenspace":"Earth","dasl:bott":"6 (R(8))","dasl:hecke":"T_71","sheaf:orbifold":"(26 mod 71, 4 mod 59, 44 mod 47)","sheaf:subgroupIndex":"erdfa:H/raw"}')
check_status "bad DA51 type returns 422" "422" "$status"

echo "=== 7. POST out-of-range shard (should fail) ==="
status=$(curl -sS -o /tmp/.out -w "%{http_code}" --max-time 5 -X POST "$BASE/api/erdfa/submit" \
  -H "Content-Type: application/json" \
  -d '{"cid":"test_oob","erdfa:shard":"99,4,44","erdfa:prime":"1","erdfa:encoding":"raw","dasl:addr":"0xda5153b060412dff","dasl:type":"5","dasl:eigenspace":"Earth","dasl:bott":"6 (R(8))","dasl:hecke":"T_71","sheaf:orbifold":"(99 mod 71, 4 mod 59, 44 mod 47)","sheaf:subgroupIndex":"erdfa:H/raw"}')
check_status "out-of-range shard returns 422" "422" "$status"

echo "=== 8. List endpoint ==="
out=$(curl -sS --max-time 5 "$BASE/api/erdfa/list")
check_contains "list returns count" '"count"' "$out"

echo "=== 9. Persistence round-trip ==="
curl -sS --max-time 5 -X POST "$BASE/api/erdfa/submit" \
  -H "Content-Type: application/json" \
  -d '{"cid":"test_persist_001","erdfa:shard":"10,20,30","erdfa:prime":"1","erdfa:encoding":"raw","dasl:addr":"0xda51100000000000","dasl:type":"1","dasl:eigenspace":"Earth","dasl:bott":"1 (C)","dasl:hecke":"T_13","sheaf:orbifold":"(10 mod 71, 20 mod 59, 30 mod 47)","sheaf:subgroupIndex":"erdfa:H/raw"}' > /dev/null
out=$(curl -sS --max-time 5 "$BASE/api/erdfa/test_persist_001")
check_contains "persisted section readable" '"erdfa:shard": "10,20,30"' "$out"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

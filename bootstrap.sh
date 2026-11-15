#!/usr/bin/env bash
# Populates the Lean node with reference data from Mike's screenshots and infographics.
set -e

BASE="http://127.0.0.1:8080"

echo "=== Bootstrapping kant-lean-worker with DA51 reference data ==="

# 1. Meta-Meme Fixed Point (from DA51 Crankmiming infographic)
echo "Loading Meta-Meme Fixed Point (35, 31, 23)..."
curl -sS -X POST "$BASE/api/erdfa/submit" \
  -H "Content-Type: application/json" \
  -d '{"cid":"meta_meme_fixed_point","erdfa:shard":"35,31,23","erdfa:prime":"1","erdfa:encoding":"raw","dasl:addr":"0xda51000000000023","dasl:type":"0","dasl:eigenspace":"Earth","dasl:bott":"0 (R)","dasl:hecke":"T_2","sheaf:orbifold":"(35 mod 71, 31 mod 59, 23 mod 47)","sheaf:subgroupIndex":"erdfa:H/raw"}' > /dev/null
echo "  ✓ Done"

# 2. Pi Agent Approval Screenshot
echo "Loading Pi Agent context (26, 4, 44)..."
curl -sS -X POST "$BASE/api/erdfa/submit" \
  -H "Content-Type: application/json" \
  -d '{"cid":"bafkda513060e0412dff","erdfa:shard":"26,4,44","erdfa:prime":"1","erdfa:encoding":"raw","dasl:addr":"0xda5153b060412dff","dasl:type":"5","dasl:eigenspace":"Earth","dasl:bott":"6 (R(8))","dasl:hecke":"T_71","sheaf:orbifold":"(26 mod 71, 4 mod 59, 44 mod 47)","sheaf:subgroupIndex":"erdfa:H/raw"}' > /dev/null
echo "  ✓ Done"

# 3. ZKperf Schema Example (from the text file)
echo "Loading ZKperf Schema (16, 2, 0)..."
curl -sS -X POST "$BASE/api/erdfa/submit" \
  -H "Content-Type: application/json" \
  -d '{"cid":"bafkda5130a24023b498","erdfa:shard":"16,2,0","erdfa:prime":"1","erdfa:encoding":"raw","dasl:addr":"0xda5130a24023b498","dasl:type":"3","dasl:eigenspace":"Earth","dasl:bott":"5 (C(4))","dasl:hecke":"T_17","sheaf:orbifold":"(16 mod 71, 2 mod 59, 0 mod 47)","sheaf:subgroupIndex":"erdfa:H/raw"}' > /dev/null
echo "  ✓ Done"

echo "=== Node status ==="
curl -sS "$BASE/api/erdfa/status"
echo ""

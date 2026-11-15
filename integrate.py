#!/usr/bin/env python3
"""
Integration demo: how the Python/Rust side talks to the Lean node.
"""
import json
import sys
import urllib.request
import urllib.error

BASE = "http://127.0.0.1:8080"

def monster_hash(name):
    length = len(name) % 71
    char_sum = sum(ord(c) for c in name) % 59
    distinct = len(set(name)) % 47
    return (length, char_sum, distinct)

def get_json(path):
    with urllib.request.urlopen(f"{BASE}{path}", timeout=5) as r:
        return json.loads(r.read())

def post_json(path, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{BASE}{path}", data=data, method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        body = e.read()
        try:
            return e.code, json.loads(body)
        except json.JSONDecodeError:
            return e.code, {"raw": body.decode("utf-8", errors="replace")}

def demo_hash_oracle(names):
    print("\n=== 1. Hash Oracle: local vs Lean ===")
    for name in names:
        local = monster_hash(name)
        remote = get_json(f"/api/erdfa/hash/{name}")
        remote_tuple = tuple(int(x) for x in remote["erdfa:shard"].split(","))
        match = "✓" if local == remote_tuple else "✗ MISMATCH"
        print(f"  {match} {name!r}: local={local}, lean={remote_tuple}, crt={remote['erdfa:crt']}")

def demo_submit_cycle(name):
    print(f"\n=== 2. Submit → Confirm → Contradict cycle for {name!r} ===")
    s0, s1, s2 = monster_hash(name)
    addr = f"0xda51{s0:02x}{s1:02x}{s2:02x}000000"
    assert len(addr) == 18, f"addr length is {len(addr)}, expected 18"

    base_payload = {
        "cid": f"theory_{name}",
        "erdfa:shard": f"{s0},{s1},{s2}",
        "erdfa:prime": "1",
        "erdfa:encoding": "raw",
        "dasl:addr": addr,
        "dasl:type": "0",
        "dasl:eigenspace": "Earth",
        "dasl:bott": "0 (R)",
        "dasl:hecke": "T_2",
        "sheaf:orbifold": f"({s0} mod 71, {s1} mod 59, {s2} mod 47)",
        "sheaf:subgroupIndex": "erdfa:H/raw",
    }

    status, resp = post_json("/api/erdfa/submit", base_payload)
    print(f"  First submit:  {status} ({resp.get('status', resp.get('raw'))})")

    status, resp = post_json("/api/erdfa/submit", base_payload)
    print(f"  Resubmit:      {status} ({resp.get('status', resp.get('raw'))})")

    contradict = dict(base_payload)
    contradict["erdfa:shard"] = f"{(s0+1)%71},{s1},{s2}"
    contradict["sheaf:orbifold"] = f"({(s0+1)%71} mod 71, {s1} mod 59, {s2} mod 47)"
    status, resp = post_json("/api/erdfa/submit", contradict)
    print(f"  Contradiction: {status} ({resp.get('status', resp.get('raw'))})")

def demo_knowledge_base():
    print("\n=== 3. Local Knowledge Base ===")
    index = get_json("/api/erdfa/list")
    print(f"  Total sections: {index['count']}")
    for s in index["sections"][:5]:
        print(f"    {s['cid']}: crt={s['crt']}")

if __name__ == "__main__":
    names = sys.argv[1:] or ["test_theory", "crank_alpha", "meta_meme"]
    print("=== kant-lean-worker integration demo ===")
    print(f"Target node: {BASE}")
    demo_hash_oracle(names)
    demo_submit_cycle(names[0])
    demo_knowledge_base()
    print("\nAll demos complete.")

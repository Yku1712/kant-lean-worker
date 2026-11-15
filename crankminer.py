#!/usr/bin/env python3
"""
Crankminer: Finds a string whose monsterHash equals the Hub (35, 31, 23).
Once found, it submits it to the Lean node as a valid SheafSection.
"""
import random
import string
import json
import urllib.request
import urllib.error

BASE = "http://127.0.0.1:8080"
TARGET = (35, 31, 23)

def monster_hash(name):
    length = len(name) % 71
    char_sum = sum(ord(c) for c in name) % 59
    distinct = len(set(name)) % 47
    return (length, char_sum, distinct)

def mine():
    print(f"⛏️  Mining for a string that hashes to the Hub {TARGET}...")
    # To get length 35 mod 71, we use length 35.
    # To get 23 distinct chars, we need a string with exactly 23 unique characters.
    # To get sum 31 mod 59, we adjust the characters.
    
    attempts = 0
    while True:
        attempts += 1
        if attempts % 100000 == 0:
            print(f"   ... tried {attempts} combinations")
            
        # Generate a string of length 35 with exactly 23 distinct characters
        chars = list(string.ascii_letters + string.digits)[:23]
        # Pad to length 35 by repeating random chars from the set
        while len(chars) < 35:
            chars.append(random.choice(chars[:23]))
        random.shuffle(chars)
        candidate = "".join(chars)
        
        if monster_hash(candidate) == TARGET:
            return candidate, attempts

if __name__ == "__main__":
    crank_name, tries = mine()
    print(f"🎯 FOUND A CRANK! String: '{crank_name}' (took {tries} attempts)")
    
    # Now submit it to the Lean node
    s0, s1, s2 = TARGET
    addr = f"0xda51000000000023" # Type 0, ending in 23
    
    payload = {
        "cid": f"mined_crank_{crank_name}",
        "erdfa:shard": f"{s0},{s1},{s2}",
        "erdfa:prime": "1",
        "erdfa:encoding": "raw",
        "dasl:addr": addr,
        "dasl:type": "0",
        "dasl:eigenspace": "Earth",
        "dasl:bott": "0 (R)",
        "dasl:hecke": "T_2",
        "sheaf:orbifold": f"({s0} mod 71, {s1} mod 59, {s2} mod 47)",
        "sheaf:subgroupIndex": "erdfa:H/raw"
    }
    
    print("📤 Submitting to Lean Node for Zero Trust validation...")
    req = urllib.request.Request(
        f"{BASE}/api/erdfa/submit", 
        data=json.dumps(payload).encode(), 
        method="POST",
        headers={"Content-Type": "application/json"}
    )
    
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            res = json.loads(r.read())
            print(f"✅ Success! Node responded: {res.get('status').upper()}")
            print(f"   CRT Gödel Number: {res.get('crt')}")
            print(f"   CID: {res.get('cid')}")
    except urllib.error.HTTPError as e:
        print(f"❌ Validation failed: {e.code} {e.read().decode()}")

import json
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path.cwd()
BASE = "http://127.0.0.1:9090"
checks = []

def check(name, condition):
    ok = bool(condition)
    checks.append((name, ok))
    print(("PASS " if ok else "FAIL ") + name, flush=True)

def http(method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    headers = {} if data is None else {"Content-Type": "application/json"}
    req = urllib.request.Request(
        BASE + path, data=data, headers=headers, method=method
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=6) as response:
            return response.status, response.read(65536)
    except urllib.error.HTTPError as e:
        return e.code, e.read(65536)

def json_http(method, path, payload=None):
    status, raw = http(method, path, payload)
    try:
        return status, json.loads(raw)
    except (ValueError, UnicodeDecodeError):
        return status, {}

def section(cid, shard="26,4,44"):
    x, y, z = shard.split(",")
    return {
        "cid": cid,
        "erdfa:shard": shard,
        "erdfa:prime": "1",
        "erdfa:encoding": "raw",
        "dasl:addr": "0xda5153b060412dff",
        "dasl:type": "5",
        "dasl:eigenspace": "Earth",
        "dasl:bott": "6 (R(8))",
        "dasl:hecke": "T_71",
        "sheaf:orbifold": f"({x} mod 71, {y} mod 59, {z} mod 47)",
        "sheaf:subgroupIndex": "erdfa:H/raw"
    }

def credit(name):
    status, body = json_http("GET", "/api/erdfa/wallet/" + name)
    return body.get("credits") if status == 200 else None

def wait_ready(process):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if process.poll() is not None:
            return False
        try:
            with socket.create_connection(("127.0.0.1", 9090), timeout=.25):
                return True
        except OSError:
            time.sleep(.1)
    return False

assert (ROOT / "data/wallets/default_user.json").is_file()
assert not (ROOT / "authority.sqlite3").exists()

with (ROOT / "SERVER.log").open("wb") as log:
    process = subprocess.Popen(
        [str(ROOT / ".lake/build/bin/lean-worker")],
        cwd="/work",
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT
    )
    try:
        running = wait_ready(process)
        check("01_SERVER_READY_9090", running)
        if not running:
            raise RuntimeError("SERVER_NOT_READY")

        status, raw = http("GET", "/")
        check("02_INDEX_200", status == 200)

        status, raw = http("GET", "/ui")
        check("03_UI_200", status == 200)

        check("04_INITIAL_CREDITS_30", credit("default_user") == 30)

        status, body = json_http(
            "POST", "/api/erdfa/stake/default_user:1000"
        )
        check("05_STAKE_FAIL_CLOSED",
              status == 403 and body.get("status") == "DENIED")

        status, body = json_http(
            "POST", "/api/erdfa/withdraw/default_user:5"
        )
        check("06_WITHDRAW_FAIL_CLOSED",
              status == 403 and body.get("status") == "DENIED")

        check("07_NO_ECONOMIC_MUTATION",
              credit("default_user") == 30)

        p = section("synthetic_ci03a_001")
        status, body = json_http("POST", "/api/erdfa/submit", p)
        print("CREATE_HTTP=", status, body.get("status"), flush=True)
        check("08_CREATED_201",
              status == 201 and body.get("status") == "created")

        status, body = json_http("POST", "/api/erdfa/submit", p)
        check("09_CONFIRMED_200",
              status == 200 and body.get("status") == "confirmed")

        status, body = json_http(
            "POST", "/api/erdfa/submit",
            section("synthetic_ci03a_001", "26,4,43")
        )
        check("10_CONTRADICTION_422",
              status == 422 and body.get("status") == "contradiction")

        check("11_EXPECTED_BALANCE_15",
              credit("default_user") == 15)
        check("12_TREASURY_BALANCE_10",
              credit("lean_node_worker") == 10)

        status, body = json_http(
            "GET", "/api/erdfa/synthetic_ci03a_001"
        )
        check("13_SECTION_PERSISTED",
              status == 200 and
              body.get("erdfa:shard") == "26,4,44")

        status, body = json_http("GET", "/api/erdfa/list")
        check("14_LIST_AVAILABLE",
              status == 200 and "count" in body)

        status, body = json_http(
            "POST", "/api/erdfa/sync",
            [section("synthetic_ci03a_sync")]
        )
        check("15_BATCH_SYNC",
              status == 200 and body.get("created") == 1)

        check("16_SYNC_NO_CREDIT_DEBIT",
              credit("default_user") == 15)

    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=4)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)

def wallet_file(name):
    return json.loads(
        (ROOT / "data/wallets" / (name + ".json")).read_text()
    )["credits"]

check("17_PERSISTENT_USER_BALANCE",
      wallet_file("default_user") == 15)
check("18_PERSISTENT_TREASURY_BALANCE",
      wallet_file("lean_node_worker") == 10)

passed = sum(ok for _, ok in checks)
failed = len(checks) - passed

(ROOT / "RESULT.json").write_text(json.dumps({
    "suite": "KANT-DAO-CI-03A",
    "passed": passed,
    "failed": failed,
    "checks": [{"name": n, "pass": ok} for n, ok in checks],
    "synthetic_wallets": True,
    "network_isolated": True
}, indent=2) + "\n")

print("TOTAL_PASS=", passed, flush=True)
print("TOTAL_FAIL=", failed, flush=True)
print("KANT_DAO_CI03A_RESULT=",
      "PASS" if failed == 0 else "FAIL", flush=True)
sys.exit(0 if failed == 0 else 1)

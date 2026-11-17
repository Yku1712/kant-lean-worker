import os
import re
import time
import json
import sqlite3
import hashlib
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey, Ed25519PublicKey
)
from cryptography.hazmat.primitives import serialization

ROOT = Path(__file__).resolve().parent
DB = ROOT / "authority.sqlite3"

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
ORIGIN = "http://localhost:9090"
DOMAIN = "KANT-DAO-CREATE-V1"

def b58encode(raw):
    n = int.from_bytes(raw, "big")
    result = ""
    while n:
        n, r = divmod(n, 58)
        result = ALPHABET[r] + result
    return "1" * (len(raw) - len(raw.lstrip(b"\0"))) + result

def b58decode(value):
    n = 0
    for char in value:
        if char not in ALPHABET:
            raise ValueError("Invalid base58")
        n = n * 58 + ALPHABET.index(char)
    raw = n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b""
    return b"\0" * (len(value) - len(value.lstrip("1"))) + raw

def wallet_of(private):
    raw = private.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw
    )
    return b58encode(raw)

def payload(wallet, cid, quorum, eligible, nonce, expires):
    fields = [
        DOMAIN,
        "origin=" + ORIGIN,
        "wallet=" + wallet,
        "cid=" + cid,
        "quorum=" + str(quorum),
        "eligible=" + str(eligible),
        "nonce=" + nonce,
        "expires=" + str(expires)
    ]
    return ("\n".join(fields) + "\n").encode("utf-8")

def connection():
    db = sqlite3.connect(DB, timeout=10, isolation_level=None)
    db.execute("PRAGMA busy_timeout=10000")
    return db

def initialize():
    with connection() as db:
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=FULL")
        db.executescript("""
            CREATE TABLE IF NOT EXISTS challenges (
                nonce TEXT PRIMARY KEY,
                wallet TEXT NOT NULL,
                payload BLOB NOT NULL,
                expires INTEGER NOT NULL,
                consumed INTEGER NOT NULL DEFAULT 0
                    CHECK(consumed IN (0,1))
            );
            CREATE TABLE IF NOT EXISTS proposals (
                cid TEXT PRIMARY KEY,
                wallet TEXT NOT NULL,
                quorum INTEGER NOT NULL,
                eligible INTEGER NOT NULL,
                created_at INTEGER NOT NULL
            );
        """)

def validate(cid, quorum, eligible):
    return (
        re.fullmatch(r"[A-Za-z0-9_-]{1,128}", cid) is not None
        and type(quorum) is int and 1 <= quorum <= 100
        and type(eligible) is int and 1 <= eligible <= 1000000000
    )

class Authority:
    def __init__(self, allowed_wallets):
        self.allowed_wallets = set(allowed_wallets)

    def issue(self, wallet, cid, quorum=20, eligible=100, ttl=300):
        if wallet not in self.allowed_wallets:
            return None
        if not validate(cid, quorum, eligible):
            return None
        nonce = os.urandom(32).hex()
        expires = int(time.time()) + ttl
        msg = payload(wallet, cid, quorum, eligible, nonce, expires)
        with connection() as db:
            db.execute(
                "INSERT INTO challenges VALUES (?,?,?,?,0)",
                (nonce, wallet, msg, expires)
            )
        return nonce, msg

    def submit(self, wallet, nonce, cid, quorum, eligible,
               signature, inject_failure=False):
        if wallet not in self.allowed_wallets:
            return "UNAUTHORIZED"
        if not validate(cid, quorum, eligible):
            return "INVALID_PARAMETERS"

        db = connection()
        try:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute(
                "SELECT wallet,payload,expires,consumed "
                "FROM challenges WHERE nonce=?",
                (nonce,)
            ).fetchone()

            if row is None or row[3] != 0:
                db.rollback()
                return "REPLAY_OR_UNKNOWN"

            stored_wallet, stored_msg, expires, _ = row

            if expires <= int(time.time()):
                db.rollback()
                return "EXPIRED"

            expected = payload(
                wallet, cid, quorum, eligible, nonce, expires
            )

            if stored_wallet != wallet or stored_msg != expected:
                db.rollback()
                return "BINDING_MISMATCH"

            try:
                key = b58decode(wallet)
                if len(key) != 32:
                    raise ValueError("Invalid public key")
                Ed25519PublicKey.from_public_bytes(key).verify(
                    signature, expected
                )
            except (ValueError, TypeError, Exception):
                db.rollback()
                return "BAD_SIGNATURE"

            db.execute(
                "UPDATE challenges SET consumed=1 "
                "WHERE nonce=? AND consumed=0",
                (nonce,)
            )

            if inject_failure:
                raise RuntimeError("SYNTHETIC_BEFORE_COMMIT")

            try:
                db.execute(
                    "INSERT INTO proposals VALUES (?,?,?,?,?)",
                    (cid, wallet, quorum, eligible, int(time.time()))
                )
            except sqlite3.IntegrityError:
                db.rollback()
                return "DUPLICATE"

            db.commit()
            return "CREATED"

        except Exception:
            db.rollback()
            if inject_failure:
                return "FAULT_ROLLBACK"
            raise
        finally:
            db.close()

def check(condition, label):
    assert condition, label
    print(label + "=PASS", flush=True)



import sys

MAX_REQUEST = 8192

def respond(status, **fields):
    print(json.dumps({"status": status, **fields}, separators=(",", ":")), flush=True)

def main():
    raw = sys.stdin.buffer.readline(MAX_REQUEST + 1)

    if not raw or len(raw) > MAX_REQUEST or not raw.endswith(b"\n"):
        respond("DENIED")
        return

    try:
        request = json.loads(raw)
        if not isinstance(request, dict):
            raise ValueError("Invalid request")

        operation = request.get("operation")

        if operation == "list":
            if set(request) != {"operation"} or not DB.is_file():
                respond("DENIED")
                return

            db = sqlite3.connect(
                "file:" + str(DB) + "?mode=ro",
                uri=True,
                timeout=3
            )
            try:
                rows = db.execute(
                    "SELECT cid, wallet, quorum, eligible, created_at "
                    "FROM proposals ORDER BY created_at DESC, cid DESC "
                    "LIMIT 100"
                ).fetchall()
            finally:
                db.close()

            proposals = [
                {
                    "cid": row[0],
                    "wallet": row[1],
                    "quorum": row[2],
                    "eligible": row[3],
                    "created_at": row[4]
                }
                for row in rows
            ]
            # Signed records and historical JSON records remain distinct.
            for proposal in proposals:
                proposal["source"] = "signed"
                proposal["finalized"] = False
                proposal["passed"] = False
                proposal["votesFor"] = 0
                proposal["votesAgainst"] = 0

            known_cids = {p["cid"] for p in proposals}
            legacy_dir = ROOT / "data" / "proposals"

            if legacy_dir.is_dir():
                for item in sorted(legacy_dir.glob("*.json")):
                    if not item.is_file() or item.is_symlink():
                        raise ValueError("Invalid legacy proposal file")
                    if item.stat().st_size > 1000000:
                        raise ValueError("Oversized legacy proposal")

                    historical = json.loads(item.read_text())
                    if not isinstance(historical, dict):
                        raise ValueError("Invalid historical proposal")

                    cid = historical.get("cid")
                    quorum = historical.get("quorumPercentage")
                    eligible = historical.get("totalEligibleVoters")
                    votes_for = historical.get("votesFor")
                    votes_against = historical.get("votesAgainst")
                    finalized = historical.get("finalized")
                    passed = historical.get("passed")

                    if not (
                        isinstance(cid, str)
                        and re.fullmatch(r"[A-Za-z0-9_-]{1,128}", cid)
                        and type(quorum) is int and 1 <= quorum <= 100
                        and type(eligible) is int and 1 <= eligible <= 1000000000
                        and type(votes_for) is int and votes_for >= 0
                        and type(votes_against) is int and votes_against >= 0
                        and type(finalized) is bool
                        and type(passed) is bool
                    ):
                        raise ValueError("Malformed historical proposal")

                    # Signed records take precedence for identical IDs.
                    if cid in known_cids:
                        continue

                    known_cids.add(cid)
                    proposals.append({
                        "cid": cid,
                        "wallet": None,
                        "quorum": quorum,
                        "eligible": eligible,
                        "created_at": None,
                        "source": "legacy",
                        "finalized": finalized,
                        "passed": passed,
                        "votesFor": votes_for,
                        "votesAgainst": votes_against
                    })

            respond("LIST", proposals=proposals)
            return

        allowlist_path = ROOT / "authorized_wallets.json"
        allowed = json.loads(allowlist_path.read_text())
        if not isinstance(allowed, list):
            raise ValueError("Invalid policy")
        if not all(isinstance(w, str) for w in allowed):
            raise ValueError("Invalid wallet policy")

        authority = Authority(allowed)
        initialize()

        if operation == "challenge":
            if set(request) != {
                "operation", "wallet", "cid", "quorum", "eligible"
            }:
                raise ValueError("Invalid challenge fields")

            wallet = request["wallet"]
            cid = request["cid"]
            quorum = request["quorum"]
            eligible = request["eligible"]

            if not isinstance(wallet, str) or not isinstance(cid, str):
                raise ValueError("Invalid fields")

            result = authority.issue(wallet, cid, quorum, eligible)

            if result is None:
                respond("DENIED")
                return

            nonce, message = result
            respond(
                "CHALLENGE",
                nonce=nonce,
                message=message.decode("utf-8")
            )
            return

        if operation == "submit":
            if set(request) != {
                "operation", "wallet", "cid", "quorum",
                "eligible", "nonce", "signature"
            }:
                raise ValueError("Invalid submit fields")

            wallet = request["wallet"]
            cid = request["cid"]
            nonce = request["nonce"]
            signature = request["signature"]

            if not all(isinstance(x, str) for x in (
                wallet, cid, nonce, signature
            )):
                raise ValueError("Invalid string fields")

            if len(nonce) != 64 or len(signature) > 128:
                raise ValueError("Invalid signature format")

            signature_bytes = b58decode(signature)

            if len(signature_bytes) != 64:
                raise ValueError("Invalid signature length")

            status = authority.submit(
                wallet, nonce, cid,
                request["quorum"], request["eligible"],
                signature_bytes
            )

            respond(status)
            return

        respond("DENIED")

    except Exception:
        respond("DENIED")

if __name__ == "__main__":
    main()

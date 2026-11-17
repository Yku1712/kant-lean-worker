import json
import os
import sqlite3
import time
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey, Ed25519PublicKey
)
from cryptography.hazmat.primitives import serialization

ROOT = Path(__file__).resolve().parent
DB = ROOT / "authority.sqlite3"
CID = "proposal_test_20261117_01"
LEGACY = "test_bylaw_1"
DOMAIN = "KANT-DAO-VOTE-V1"
ORIGIN = "http://localhost:9090"
ABC = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
passed = []


def check(name, ok):
    assert ok, name
    passed.append(name)
    print("PASS", name, flush=True)


def b58encode(data):
    n = int.from_bytes(data, "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = ABC[r] + out
    return "1" * (len(data) - len(data.lstrip(b"\0"))) + out


def b58decode(s):
    n = 0
    for c in s:
        if c not in ABC:
            raise ValueError("bad base58")
        n = n * 58 + ABC.index(c)
    return b"\0" * (len(s) - len(s.lstrip("1"))) + (
        n.to_bytes((n.bit_length() + 7) // 8, "big")
    )


def wallet_of(key):
    pub = key.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw
    )
    return b58encode(pub)


def connect():
    db = sqlite3.connect(DB, timeout=5, isolation_level=None)
    db.execute("PRAGMA busy_timeout=5000")
    db.execute("PRAGMA foreign_keys=ON")
    return db


def message(cid, wallet, choice, nonce, expires):
    return ("\n".join([
        DOMAIN,
        "origin=" + ORIGIN,
        "cid=" + cid,
        "wallet=" + wallet,
        "choice=" + choice,
        "nonce=" + nonce,
        "expires=" + str(expires),
    ]) + "\n").encode()


def setup():
    with connect() as db:
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=FULL")
        db.executescript("""
        CREATE TABLE vote_policy (
          cid TEXT PRIMARY KEY REFERENCES proposals(cid),
          enabled INTEGER NOT NULL CHECK(enabled IN (0,1))
        );
        CREATE TABLE vote_eligibility (
          cid TEXT NOT NULL REFERENCES proposals(cid),
          wallet TEXT NOT NULL,
          PRIMARY KEY(cid,wallet)
        );
        CREATE TABLE vote_challenges (
          nonce TEXT PRIMARY KEY,
          cid TEXT NOT NULL,
          wallet TEXT NOT NULL,
          choice TEXT NOT NULL CHECK(choice IN ('yes','no')),
          payload BLOB NOT NULL,
          expires INTEGER NOT NULL,
          consumed INTEGER NOT NULL DEFAULT 0
            CHECK(consumed IN (0,1))
        );
        CREATE TABLE vote_ballots (
          cid TEXT NOT NULL REFERENCES proposals(cid),
          wallet TEXT NOT NULL,
          choice TEXT NOT NULL CHECK(choice IN ('yes','no')),
          created_at INTEGER NOT NULL,
          PRIMARY KEY(cid,wallet)
        );
        """)


def permitted(db, cid, wallet):
    return db.execute("""
        SELECT 1 FROM proposals p
        JOIN vote_policy pol ON pol.cid=p.cid AND pol.enabled=1
        JOIN vote_eligibility e ON e.cid=p.cid AND e.wallet=?
        WHERE p.cid=?
        """, (wallet, cid)).fetchone() is not None


def challenge(cid, wallet, choice):
    if choice not in ("yes", "no"):
        return None
    with connect() as db:
        db.execute("BEGIN IMMEDIATE")
        if not permitted(db, cid, wallet):
            db.rollback()
            return None
        nonce = os.urandom(32).hex()
        expires = int(time.time()) + 300
        payload = message(cid, wallet, choice, nonce, expires)
        db.execute(
            "INSERT INTO vote_challenges VALUES (?,?,?,?,?,?,0)",
            (nonce, cid, wallet, choice, payload, expires)
        )
        db.commit()
        return nonce, payload


def cast(cid, wallet, choice, nonce, signature):
    if choice not in ("yes", "no"):
        return "INVALID_CHOICE"
    with connect() as db:
        db.execute("BEGIN IMMEDIATE")
        if not permitted(db, cid, wallet):
            db.rollback()
            return "DENIED"
        row = db.execute(
            "SELECT cid,wallet,choice,payload,expires,consumed "
            "FROM vote_challenges WHERE nonce=?",
            (nonce,)
        ).fetchone()
        if row is None or row[5]:
            db.rollback()
            return "REPLAY_OR_UNKNOWN"
        stored_cid, stored_wallet, stored_choice, stored, exp, _ = row
        expected = message(cid, wallet, choice, nonce, exp)
        if (
            stored_cid != cid or stored_wallet != wallet
            or stored_choice != choice or stored != expected
        ):
            db.rollback()
            return "BINDING_MISMATCH"
        if exp <= int(time.time()):
            db.rollback()
            return "EXPIRED"
        try:
            pub = b58decode(wallet)
            if len(pub) != 32:
                raise ValueError("invalid key")
            Ed25519PublicKey.from_public_bytes(pub).verify(
                signature, expected
            )
        except Exception:
            db.rollback()
            return "BAD_SIGNATURE"
        if db.execute(
            "SELECT 1 FROM vote_ballots WHERE cid=? AND wallet=?",
            (cid, wallet)
        ).fetchone():
            db.rollback()
            return "DUPLICATE"
        db.execute(
            "INSERT INTO vote_ballots VALUES (?,?,?,?)",
            (cid, wallet, choice, int(time.time()))
        )
        db.execute(
            "UPDATE vote_challenges SET consumed=1 WHERE nonce=?",
            (nonce,)
        )
        db.commit()
        return "VOTED"


def main():
    setup()
    a = Ed25519PrivateKey.generate()
    b = Ed25519PrivateKey.generate()
    wa, wb = wallet_of(a), wallet_of(b)

    check("SIGNED_PROPOSAL_EXISTS",
          connect().execute(
              "SELECT 1 FROM proposals WHERE cid=?", (CID,)
          ).fetchone() is not None)

    check("DEFAULT_DENY_NO_VOTE_POLICY",
          challenge(CID, wa, "yes") is None)

    check("LEGACY_PROPOSAL_NOT_AUTO_ELIGIBLE",
          challenge(LEGACY, wa, "yes") is None)

    with connect() as db:
        db.execute(
            "INSERT INTO vote_policy VALUES (?,1)", (CID,)
        )

    check("POLICY_ALONE_NOT_ENOUGH",
          challenge(CID, wa, "yes") is None)

    with connect() as db:
        db.execute(
            "INSERT INTO vote_eligibility VALUES (?,?)", (CID, wa)
        )

    check("UNLISTED_WALLET_DENIED",
          challenge(CID, wb, "yes") is None)

    check("INVALID_CHOICE_DENIED",
          challenge(CID, wa, "abstain") is None)

    issued = challenge(CID, wa, "yes")
    check("ELIGIBLE_WALLET_CHALLENGE", issued is not None)
    nonce, msg = issued

    check("FORGED_VOTE_DENIED",
          cast(CID, wa, "yes", nonce, b.sign(msg))
          == "BAD_SIGNATURE")

    check("SIGNED_VOTE_ACCEPTED",
          cast(CID, wa, "yes", nonce, a.sign(msg))
          == "VOTED")

    check("SIGNED_VOTE_REPLAY_DENIED",
          cast(CID, wa, "yes", nonce, a.sign(msg))
          == "REPLAY_OR_UNKNOWN")

    with connect() as db:
        db.execute(
            "UPDATE vote_policy SET enabled=0 WHERE cid=?", (CID,)
        )

    check("DISABLED_POLICY_FAILS_CLOSED",
          challenge(CID, wa, "no") is None)

    with connect() as db:
        check("ONE_DURABLE_BALLOT",
              db.execute(
                  "SELECT COUNT(*) FROM vote_ballots WHERE cid=?", (CID,)
              ).fetchone()[0] == 1)
        check("SNAPSHOT_SQLITE_INTEGRITY",
              db.execute("PRAGMA integrity_check").fetchone()[0] == "ok")

    report = {
        "result": "PASS",
        "assertions": len(passed),
        "live_server_modified": False,
        "live_database_modified": False,
        "synthetic_voters_only": True,
        "voting_policy_approved": False,
        "runtime_voting_enabled": False
    }
    (ROOT / "REPORT.json").write_text(json.dumps(report, indent=2) + "\n")
    print("TOTAL_ASSERTIONS=", len(passed))
    print("KANT_PROPOSAL_55_RESULT=PASS")


if __name__ == "__main__":
    main()

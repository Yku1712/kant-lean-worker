import json
import sys

import vote_engine as v

MAX_REQUEST = 4096


def respond(status, **fields):
    print(json.dumps(
        {"status": status, **fields},
        separators=(",", ":")
    ), flush=True)


def main():
    raw = sys.stdin.buffer.readline(MAX_REQUEST + 1)
    if not raw or len(raw) > MAX_REQUEST or not raw.endswith(b"\n"):
        respond("DENIED")
        return

    try:
        request = json.loads(raw)
        if not isinstance(request, dict):
            raise ValueError("Not an object")

        op = request.get("operation")

        if op == "vote_challenge":
            if set(request) != {
                "operation", "cid", "wallet", "choice"
            }:
                raise ValueError("Invalid challenge fields")

            cid = request["cid"]
            wallet = request["wallet"]
            choice = request["choice"]

            if not all(type(x) is str for x in (cid, wallet, choice)):
                raise ValueError("Invalid field types")

            result = v.challenge(cid, wallet, choice)
            if result is None:
                respond("DENIED")
            else:
                nonce, message = result
                respond(
                    "CHALLENGE",
                    nonce=nonce,
                    message=message.decode("utf-8")
                )
            return

        if op == "vote_submit":
            if set(request) != {
                "operation", "cid", "wallet",
                "choice", "nonce", "signature"
            }:
                raise ValueError("Invalid submit fields")

            cid = request["cid"]
            wallet = request["wallet"]
            choice = request["choice"]
            nonce = request["nonce"]
            signature = request["signature"]

            if not all(type(x) is str for x in (
                cid, wallet, choice, nonce, signature
            )):
                raise ValueError("Invalid field types")

            if len(nonce) != 64 or len(signature) > 128:
                respond("DENIED")
                return

            try:
                signature_bytes = v.b58decode(signature)
            except Exception:
                respond("DENIED")
                return

            result = v.cast(
                cid, wallet, choice, nonce, signature_bytes
            )
            respond(result)
            return

        respond("DENIED")
    except (ValueError, TypeError, KeyError):
        respond("DENIED")
    except Exception:
        respond("ERROR")


if __name__ == "__main__":
    main()

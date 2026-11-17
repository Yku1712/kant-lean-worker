
import os
import sys
import json
import uuid
from pathlib import Path

def fail(code, message):
    print(message, file=sys.stderr)
    sys.exit(code)

def main():
    if len(sys.argv) != 3:
        fail(20, "INVALID_ARGUMENT_COUNT")

    cid, payload = sys.argv[1:]

    if not (1 <= len(cid) <= 128):
        fail(20, "INVALID_CID_LENGTH")
    if not all(c.isascii() and (c.isalnum() or c in "-_") for c in cid):
        fail(20, "INVALID_CID_CHARACTERS")

    try:
        record = json.loads(payload)
    except ValueError:
        fail(20, "INVALID_JSON")

    if not isinstance(record, dict) or record.get("cid") != cid:
        fail(20, "CID_MISMATCH")

    directory = Path("data/proposals")
    directory.mkdir(parents=True, exist_ok=True)

    final = directory / (cid + ".json")
    temporary = directory / (".pending-" + uuid.uuid4().hex)

    data = json.dumps(
        record, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")

    try:
        fd = os.open(
            temporary,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL,
            0o600
        )
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())

        try:
            os.link(temporary, final)
        except FileExistsError:
            fail(10, "PROPOSAL_ALREADY_EXISTS")

        dir_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)

        print("CREATED")
    finally:
        temporary.unlink(missing_ok=True)

if __name__ == "__main__":
    try:
        main()
    except OSError as exc:
        fail(20, f"IO_ERROR:{type(exc).__name__}")

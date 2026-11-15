#!/usr/bin/env bash
# Creates a timestamped archive of the local knowledge base.
# Can be uploaded to Archive.org or IPFS for long-term preservation.
set -e

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
ARCHIVE_NAME="lean-worker-backup-$TIMESTAMP.tar.gz"

if [ ! -d "data" ]; then
  echo "No data directory found. Run the server first."
  exit 1
fi

tar -czf "$ARCHIVE_NAME" data/
SHA256=$(sha256sum "$ARCHIVE_NAME" | cut -d' ' -f1)

echo "Backup created: $ARCHIVE_NAME"
echo "SHA256: $SHA256"
echo "To preserve, upload to: https://archive.org/upload/"

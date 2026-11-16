# SFM site recovery — security review branch

This branch preserves selected Lean governance sources
and adds an informational notice to the public UI.

The original local development code remains preserved
in a separate private backup.

Excluded intentionally:
- Generated Solana validator ledger and binaries
- RPC credentials
- Experimental server accepting wallet private keys
- Browser UI requesting wallet private keys
- Generated per-recipient encryption capsules

The encrypted-message reader is not enabled.
This branch is not a production security approval.

The local Main.lean and experimental UI changes still
require separate security review and integration.

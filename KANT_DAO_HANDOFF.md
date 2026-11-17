# KANT DAO — Unified Governance Dashboard Handoff

Date: 2026-11-17

Status: local integration validated; not production-approved.

## Unified dashboard

Target: http://localhost:9090/ui

Components:
- LeanIO HTTP server
- Phantom Solana wallet integration
- Signed proposal creation using Ed25519
- SQLite durable proposal registry
- Historical proposal listing
- Signed voting challenge and submission API
- Governance voting policy: disabled by default

## Verified development milestones

- P47: signed Create Proposal persisted in SQLite
- P50–51: systemd user service and linger
- P53: Ed25519 voting engine, replay protection
- P54: multiprocess contention and abrupt-exit rollback
- P55: voting registry binding and default-deny eligibility
- P56-R1: policy revocation, eligibility revocation, expiry
- P57: HTTP signed voting prototype
- P58A–B: LeanIO to Python to SQLite integration
- P59A–C: Phantom vote interface and synthetic UI tests;
  P59C original failed and must not be reported as PASS
- P60–64: unified candidate construction and diagnostics
- P65: successful live cutover on port 9090
- P66–68: legacy vote UI removal and experimental cleanup
- P69: dashboard and Vote Proposal inspected in browser

## Security boundaries

Voting is fail-closed until an authoritative eligibility
policy is defined.

Current local voting-power and credit displays do not
constitute a verified governance eligibility snapshot.

A signed proposal is not automatically an IPFS publication
or a Solana on-chain transaction.

No production readiness or governance approval is claimed.

## Pending decisions

- Senate membership / eligible voter registry
- Weighting model: wallet, token, credits, delegation
- Eligibility snapshot authority and revocation
- Quorum and majority semantics
- Proposal finalization authority
- Browser end-to-end security and production deployment
- Independent review of security assumptions

## Publication rules

The public package must exclude:
- authority.sqlite3 and SQLite journals
- authorized_wallets.json
- .env files, tokens, credentials, private keys
- private runtime state and user-specific wallet data

Review this package before GitHub push or IPFS publication.

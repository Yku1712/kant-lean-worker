# Hydration Status — kant-lean-worker

Following the "Definition of Done: The Hydrated Form of a Declared Function".

| Symbol | Component | Status | Implementation |
|---|---|---|---|
| G | Git Repository | ✅ | `github.com/Yku1712/kant-lean-worker` |
| B | CI/CD Build | ✅ | GitHub Actions (`.github/workflows/`) |
| A | Build Artifact | ✅ | `lake build` → `.olean` + native binary |
| S | Static CDN | ⚠️ | Exports via `/api/erdfa/export` (JSON/XML/JSON-LD) |
| W | WASM Edge | ⏳ | Future: Lean 4 → WASM. IPFS bridge ready (ipfs_bridge.py). |
| C | Client-Side Exec | ❌ | N/A: Server-to-server design |
| I | CLI / cURL | ✅ | REST API + `Makefile` + `test.sh` |
| D | systemd Services | ✅ | `kant-lean-worker.service` |
| P | PostgreSQL | ❌ | N/A: Flat JSON persistence for MVP |
| N | NGINX Fronting | ✅ | `nginx.conf` |
| V6 | IPv6 Subnets | ⏳ | Server binds `0.0.0.0`; IPv6 via NGINX |
| R | Archive.org Backups | ✅ | `backup.sh` produces timestamped `.tar.gz` |
| Z | VPN Zones | ❌ | N/A: Deployment responsibility |

## Completion Invariant

`DONE(f) = Declared(f) ∧ Hydrated(f)`

Current score: **9/13 hydrated** (7 explicit, 2 N/A).

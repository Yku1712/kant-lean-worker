# kant-lean-worker

A local, Lean 4-powered HTTP worker for the **Solfunmeme / ERDFa** semantic network.
Implements **Zero Trust** validation, **CRT-based numeric embedding** (Gödel numbers),
**persistent local knowledge base**, and **sheaf-gluing consensus** for Sheaf Sections.

## Features

- **RDFa / JSON endpoints** for Sheaf Sections.
- **Zero Trust Validation** (mathematical + structural + semantic):
  - `erdfa:shard` must have exactly 3 elements in range (`mod 71/59/47`).
  - `sheaf:orbifold` must equal the derived string from the shard.
  - `dasl:addr` must start with `0xda51` and be exactly 18 chars.
  - `dasl:type` must match the type nibble in the DA51 address.
  - `dasl:eigenspace`, `dasl:bott`, `dasl:hecke` are enum-checked.
- **CRT Embedding**: Computes the unique global Gödel Number from modular shards.
- **Persistence**: Validated sections are stored on disk under `data/<cid>.json`.
- **Local Proof Knowledge Base**: Indexing, filtering, and full export endpoints.
- **Consensus (Sheaf Gluing)**: `created` / `confirmed` / `contradiction` protocol.
- **Batch Sync**: `POST /api/erdfa/sync` accepts a JSON array of sections.
- **Formal Proofs** in `SheafAxioms.lean` (all proved, no `sorry`):
  - `glue_unique` — sheaf gluing uniqueness.
  - `crt_unique` — CRT uniqueness for moduli (71, 59, 47).
  - `crt_reconstruct_71/59/47` — reconstruction correctness.
- **Aligned with Crankmining.lean**: `monsterHash` fallback for unknown CIDs.
- **CI (GitHub Actions)** + **Nix flake** for reproducible builds.

## API

| Method | Path | Description |
|---|---|---|
| `GET`  | `/erdfa/{cid}` | RDFa HTML representation (reads from disk if persisted). |
| `GET`  | `/api/erdfa/{cid}` | JSON representation (reads from disk if persisted). |
| `GET`  | `/api/erdfa/list` | Index of all persisted sections with their CRT values. |
| `GET`  | `/api/erdfa/export` | Full JSON array of all sections (IPLD DAG ingestion). |
| `GET`  | `/api/erdfa/status` | Node health + endpoints + section count. |
| `GET`  | `/api/erdfa/hash/{name}` | Hash oracle: derive shard + CRT from a name via `monsterHash`. |
| `GET`  | `/api/erdfa/filter/{field}={value}` | Property-based filter over all sections. |
| `POST` | `/api/erdfa/submit` | Validate + compute CRT + persist (returns created/confirmed/contradiction). |
| `POST` | `/api/erdfa/sync` | Batch sync: accepts a JSON array of SheafSections. |
| `GET`  | `/` | Plain-text index. |

## Quick Start

```
lake build
nohup lake exe lean-worker &
./bootstrap.sh
./test.sh
```

`bootstrap.sh` pre-loads reference data from the Solfunmeme infographics and screenshots (Meta-Meme Fixed Point, Pi Agent context, ZKperf schema) so the node is queryable immediately after first start.

## Test suite

End-to-end test suite (17 checks, all green):

```
./test.sh
```

Requires the server running on 127.0.0.1:8080.

## Integration demo

`integrate.py` demonstrates that a pure-Python reimplementation of `monsterHash` produces identical shard coordinates as the Lean node, plus the full submit → confirm → contradict consensus cycle.

## Known limits

- The Rust `nested_cid` derivation uses SHA-256, not available in Lean 4.33.0 std. The Lean node uses `monsterHash` as its canonical hash. The CRT / sheaf / consensus layer is hash-agnostic.
- ' + bt + 'OPTIONS' + bt + ' CORS preflight is not routed: leanio's OPTIONS macro has a known limitation. Server-to-server only.

## Tech Stack

- **Lean 4** (v4.33.0)
- **leanio** (v0.6.0)
- **Nix** (reproducible dev shell via flake.nix)

# kant-lean-worker

A local, Lean 4-powered HTTP worker for the **Solfunmeme / ERDFa** semantic network.
Implements **Zero Trust** validation, **CRT-based numeric embedding** (Gödel numbers),
and **persistent local knowledge base** for Sheaf Sections.

## Features

- **RDFa / JSON endpoints** for Sheaf Sections.
- **Zero Trust Validation** (mathematical + structural):
  - `erdfa:shard` must have exactly 3 elements in range (`mod 71/59/47`).
  - `sheaf:orbifold` must equal the derived string from the shard.
  - `dasl:addr` must start with `0xda51` and be exactly 18 chars.
  - `dasl:type` must match the type nibble in the DA51 address.
- **CRT Embedding**: Computes the unique global Gödel Number from modular shards.
- **Persistence**: Validated sections are stored on disk under `data/<cid>.json`.
- **Local Proof Knowledge Base**: `GET /api/erdfa/list` indexes all persisted sections.
- **Formal Proofs** in `SheafAxioms.lean` (all proved, no `sorry`):
  - `glue_unique` — sheaf gluing uniqueness.
  - `crt_unique` — CRT uniqueness for moduli (71, 59, 47).
  - `crt_reconstruct_71/59/47` — reconstruction correctness.
- **Aligned with Crankmining.lean**: `monsterHash` fallback for unknown CIDs.

## API

| Method | Path | Description |
|---|---|---|
| `GET`  | `/erdfa/{cid}` | RDFa HTML representation. |
| `GET`  | `/api/erdfa/{cid}` | JSON representation (reads from disk if persisted, else derives). |
| `GET`  | `/api/erdfa/list` | Index of all persisted sections with their CRT values. |
| `GET`  | `/api/erdfa/export` | Full JSON array of all sections (IPLD DAG ingestion). |
| `GET`  | `/api/erdfa/status` | Node health + endpoints + section count. |
| `GET`  | `/api/erdfa/hash/{name}` | Hash oracle: derive shard + CRT from a name via `monsterHash`. |
| `POST` | `/api/erdfa/submit` | Validate + compute CRT + persist (returns created/confirmed/contradiction). |
| `GET`  | `/` | Plain-text index. |

## Test suite

The repository includes an end-to-end test suite (11 checks, all green):

```bash
./test.sh
eof

## Live Demo Output

### E2E test suite (`./test.sh` — 13/13 passing)


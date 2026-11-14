# kant-lean-worker

A local, Lean 4-powered HTTP worker for the **Solfunmeme / ERDFa** semantic network. 
Implements **Zero Trust** validation and **CRT-based numeric embedding** (Gödel numbers) for Sheaf Sections.

## Features

- **RDFa / JSON endpoints** for Sheaf Sections.
- **Zero Trust Validation**: Strict mathematical checks on all incoming payloads (`POST /api/erdfa/submit`).
- **CRT Embedding**: Computes the unique global Gödel Number from modular shards (mod 71, 59, 47).
- **Formal Proofs**: Machine-checked Lean 4 proofs for Sheaf Gluing and CRT Uniqueness. No `sorry`.

## API

| Method | Path | Description |
|---|---|---|
| `GET` | `/erdfa/{cid}` | RDFa HTML representation of a Sheaf Section. |
| `GET` | `/api/erdfa/{cid}` | JSON representation, including computed `erdfa:crt` (Gödel number). |
| `POST` | `/api/erdfa/submit` | Accepts a JSON payload, validates it mathematically, returns the CRT Gödel number. |

### Example: Zero Trust Submit

```bash
curl -X POST http://127.0.0.1:8080/api/erdfa/submit \
-H "Content-Type: application/json" \
-d '{"cid":"bafkda513060e0412dff","erdfa:shard":"26,4,44","erdfa:prime":"1","erdfa:encoding":"raw","dasl:addr":"0xda5153b060412dff","dasl:type":"5","dasl:eigenspace":"Earth","dasl:bott":"6 (R(8))","dasl:hecke":"T_71","sheaf:orbifold":"(26 mod 71, 4 mod 59, 44 mod 47)","sheaf:subgroupIndex":"erdfa:H/raw"}'

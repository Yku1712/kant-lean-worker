# Kant Lean Worker — Project Status

**Purpose**: A formal-methods node for the Solfunmeme / ERDFa semantic network,
serving Sheaf Sections with strict Zero Trust validation, CRT-based numeric
embedding (Gödel numbers), and distributed consensus.

## What's working

| Layer | Status | Evidence |
|---|---|---|
| HTTP server (Lean 4 + leanio) | ✅ Running | `lake exe lean-worker` on port 8080 |
| Zero Trust validation (math) | ✅ | `test.sh` tests 5–7 return 422 on tampered orbifold, out-of-range shard, bad DA51 type |
| Zero Trust validation (structure) | ✅ | DA51 prefix + type + length check |
| Zero Trust validation (semantic) | ✅ | Enum-checked eigenspace, Bott class, Hecke prime |
| CRT Gödel numbers | ✅ | `crtCombine` + `crt_reconstruct_71/59/47` (proved, no `sorry`) |
| Persistence | ✅ | JSON to `data/<cid>.json` on disk |
| Consensus (sheaf gluing) | ✅ | `created` / `confirmed` / `contradiction` (tests 10–12) |
| Hash oracle | ✅ | `/api/erdfa/hash/{name}` aligned with `Crankmining.lean` `monsterHash` |
| Export (IPLD-ready) | ✅ | `/api/erdfa/export` returns full JSON array |
| Health endpoint | ✅ | `/api/erdfa/status` |
| Python integration demo | ✅ | `integrate.py` matches local hash vs Lean node |
| E2E test suite | ✅ 17/17 | `./test.sh` |
| CI (GitHub Actions) | ✅ | `.github/workflows/lean-test.yml` |
| Reproducible env (Nix) | ✅ | `flake.nix` |

## Formal proofs (`SheafAxioms.lean`)

All proved, no `sorry`:
- `glue_unique` — sheaf gluing uniqueness
- `crt_unique` — CRT uniqueness for moduli 71, 59, 47
- `crt_reconstruct_71` / `_59` / `_47` — reconstruction correctness

## Alignment with `Crankmining.lean`

- `monsterHash` ported verbatim: `len % 71`, `charSum % 59`, `distinct % 47`
- Meta-Meme Fixed Point `(35, 31, 23)` validated → CRT `128474` → persisted
- `glue_unique` and `crt_unique` formalize the "agreement" the DA51 infographic calls out

## Known limits

- The Rust `nested_cid` derivation uses SHA-256, **not available in Lean 4.33.0 std**.
  The Lean node uses `monsterHash` as its canonical hash. The CRT / sheaf / consensus
  layer is hash-agnostic — swapping in a SHA-256 port later requires no changes to
  validation, persistence, or consensus logic.
- CORS `OPTIONS` preflight is not routed: `leanio`'s `OPTIONS` macro currently
  requires an `IntoResponse` for `Unit → ...` that the std lib doesn't ship.
  This is server-to-server only; if a browser UI is needed, we'll patch `leanio` upstream.

## Next milestones

1. Multi-node sync protocol (peer-to-peer `POST /api/erdfa/sync` with delta exchange)
2. `nested_cid` SHA-256 port (requires `Std.Crypto` or FFI to Rust/OpenSSL)
3. IPLD DAG emitter — transform `/api/erdfa/export` output to dag-cbor
4. ZK proof of section validity (SNARK over `crt_reconstruct_*`)

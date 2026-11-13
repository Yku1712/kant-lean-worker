
## Known Issues (Inherited from Lean Std.Http)

Testing with `eumemic/stdhttp-verify` revealed that the underlying `Std.Http` server (Lean 4.33.0) has a strict query string parser.
- **Bug:** Query parameters containing multiple `=` signs (e.g., Base64 tokens like `?token=YWJj==`) are rejected with `400 Bad Request`.
- **Impact:** Base64 payloads in query strings will fail. Use JSON bodies or percent-encoded values (`%3D`) as a workaround.
- **Status:** Confirmed via `curl -si "http://127.0.0.1:8080/erdfa/test-cid?token=YWJj=="`. Known upstream issue (leanprover/lean4#16021).

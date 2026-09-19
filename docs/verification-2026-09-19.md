# Compatibility Verification — 2026-09-19

Distribution repo `fluixa-runtimes` ↔ consumer `fluixa/crates/runtime-store`
(CATALOG_SPEC_VERSION = 1, RTS-V1.1). All numbers below are measured, none
hand-written.

## Artifact identity (measured)

| file | size (bytes) | sha256 |
|---|---|---|
| `artifacts/python/3.11.10/cpython-3.11.10+20241016-x86_64-apple-darwin-install_only_stripped.tar.gz` | 18011078 | `575b49a7aa64e97b06de605b7e947033bf2310b5bc5f9aedb9859d4745033d91` |
| `assets/yt-dlp-zipimport` (version read from zipapp: **2026.08.19**) | 3072469 | `1fa6733c37ea6fb51c99ad8fe785e7b7e5f3246c9b980230329d4fb72ed8d4d6` |
| `assets/cacert.pem` (certifi 2026.7.22) | 240216 | `9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f` |

Tarball sha256 equals the **official pbs `20241016` SHA256SUMS** line for the
same file (cross-checked twice: `verify_catalog.py --upstream` and the
installer's own verification during install).

## Verification results

### 1. Catalog validation (`scripts/verify_catalog.py --upstream --check-urls --expect …`)

```
PASS: 5 ok, 2 warn, 0 fail
```

- WARN ×2 = GitHub/Gitee release URLs 404 (**pending publication** — designed
  bootstrap state; installs fall through to the live upstream source).
- Upstream source reachable; sha256 == official SHA256SUMS; local artifact
  bytes re-verified; `checksums/SHA256SUMS` consistent (3 files).

### 2. Closed loop with the real consumer (main repo, additive gated e2e
`crates/runtime-store/tests/distribution_compat_e2e.rs`)

```sh
FLUIXA_RTS_DIST_E2E=1 \
FLUIXA_RUNTIME_CATALOG=<repo>/catalog.json \
  cargo test -p fluixa-runtime-store --test distribution_compat_e2e -- --nocapture
```

```
catalog entry: 3.11.10/darwin (3 source(s))
pending-mirror probe: structured Fetch error ok
install+activate in 22.53s → …/runtimes/python/3.11.10/darwin-x86_64
interpreter --version: Python 3.11.10
interpreter yt-dlp --version: 2026.08.19
test result: ok. 1 passed
```

Chain exercised end-to-end with the distribution catalog:

```
catalog.json → load_catalog → select("python")
  → negative probe: unpublished mirrors only → structured Fetch error
    ("all 2 download source(s) failed"), nothing published
  → full urls[]: fallback → upstream download → size+SHA-256 verify
  → extract → RUNTIME_MANIFEST.json + extras (yt-dlp, cacert.pem)
  → atomic publish + CURRENT.json activate
  → RuntimeStore::resolve → interpreter + tool + SSL_CERT_FILE
  → Python 3.11.10 / yt-dlp 2026.08.19 actually executed
  → installed CA bundle byte-identical to the app asset
```

### 3. Consumer regression (unchanged code)

```
runtime-store: 21 lib + 7 hermetic + 3 gated e2e (skip-clean offline) — all pass
main-repo production diff: NONE (only the additive compat e2e test file)
```

## Environment

- macOS darwin-x86_64; consumer `fluixa` @ `bb26a06` (Runtime Store V1.1)
- Network via `ALL_PROXY=socks5://127.0.0.1:7891` (curl honors it; ureq
  proxy-from-env inside the installer as shipped)

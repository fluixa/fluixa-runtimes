# fluixa-runtimes

> 简体中文版本：[README.zh-CN.md](./README.zh-CN.md)

Fluixa Runtime Distribution — the independent distribution layer for Fluixa
runtime artifacts. **Catalog → Artifact → SHA-256 verify → GitHub / Gitee /
future CDN → Fluixa Runtime Installer → `~/.fluixa/runtimes/` → Runtime
Resolver.**

This repo owns ONLY distribution: what artifacts exist, where to download
them, and their byte identity. It never executes anything and never depends
on any Fluixa component. The consumer (`fluixa` main repo,
`crates/runtime-store`) discovers this catalog at:

```
https://raw.githubusercontent.com/fluixa/fluixa-runtimes/main/catalog.json
```

(override with `FLUIXA_RUNTIME_CATALOG` — URL or local file).

## Repository locations

```text
GitHub: fluixa/fluixa-runtimes
Gitee:  fluixa/fluixa-runtimes
```

## Repository layout

```text
catalog.json              ← the published catalog (repo root, main branch)
assets/                   ← per-runtime auxiliary files, published as Release assets
  yt-dlp-zipimport          yt-dlp 2026.08.19 zipapp (platform-independent)
  cacert.pem                certifi 2026.7.22 CA bundle
artifacts/                ← local artifact cache (gitignored; re-downloadable
  python/3.11.10/…          via verify_catalog.py --fetch)
checksums/SHA256SUMS      ← committed fingerprints of artifacts/ + assets/
scripts/
  gen_catalog.py            catalog ↔ artifact byte consistency (--update/--fetch)
  verify_catalog.py         release-gating validation (schema/dup/mirrors/bytes/urls)
  release.sh                GitHub draft release + Gitee mirror checklist
docs/
  catalog-v1.md             catalog schema spec (mirror of runtime-store semantics)
  release.md                naming / tags / GitHub-Gitee-CDN mirroring
  verification-*.md         dated compatibility verification records
```

## Quick start

```sh
python3 scripts/verify_catalog.py --fetch          # download missing artifacts + full verify
python3 scripts/verify_catalog.py --upstream --check-urls   # + official cross-check + url probe
python3 scripts/gen_catalog.py --update            # refresh size/sha256 + checksums/SHA256SUMS
scripts/release.sh python-3.11.10                  # publish a draft GitHub release
```

## How Fluixa consumes this

```text
catalog.json → load_catalog → select(kind)
   → install_from_catalog: urls[] fallback (primary→mirror1→…)
       → size + SHA-256 verify (mismatch ABORTS, never bypassed)
       → extract → RUNTIME_MANIFEST.json + extras (yt-dlp, cacert.pem)
       → atomic publish → ~/.fluixa/runtimes/<kind>/<version>/<platform-arch>/
   → CURRENT.json → Runtime Resolver → interpreter / tool / SSL_CERT_FILE
```

The installer copies the auxiliary files (`assets/yt-dlp-zipimport`,
`assets/cacert.pem`) into each instance as *extras*. The Fluixa app ships the
same files inside its bundle (byte-identical, same SHA-256) and passes them to
the installer — the catalog itself stays pure metadata.

## Current status

| kind | version | platform-arch | state |
|---|---|---|---|
| python | 3.11.10 | darwin-x86_64 | **published, verified end-to-end** |
| python | 3.11.10 | darwin-aarch64 / windows-x86_64 / linux-* | not built yet |
| node | — | — | protocol-reserved only, no entries |

Download sources for `python@3.11.10:darwin-x86_64` (ordered fallback):
1. GitHub release `fluixa/fluixa-runtimes` `python-3.11.10` — **published**
2. Gitee mirror — **published** (Gitee renames `+` → space in asset names;
   the catalog URL uses the actual name, `%20`-encoded — see docs/release.md)
3. upstream `astral-sh/python-build-standalone` `20241016` — **same-bytes fallback source**

All three sources are verified byte-identical: SHA-256 (`575b49a7…`) is the
artifact's identity (mirror filename renames included). `verify_catalog.py
--check-urls` probes every source; unpublished sources are reported as WARN.

## Security invariants

- Every `urls[]` entry must serve **the same bytes** — one `sha256` for all
  mirrors; a checksum mismatch aborts the install (mirrors are never
  "worked around").
- `size` + `sha256` are always measured from real artifact bytes
  (`gen_catalog.py`), never hand-written.
- The catalog is pure metadata: it cannot change a runtime `kind`, execute
  anything, or bypass verification.
- Schema versioning is deterministic: `spec_version != 1` is a hard parse
  failure in the consumer.

## Documentation

English:

- Release Guide — [docs/release.md](./docs/release.md)
- Catalog V1 — [docs/catalog-v1.md](./docs/catalog-v1.md)
- Verification Records — [docs/verification-2026-09-20.md](./docs/verification-2026-09-20.md)

简体中文:

- Release 发布指南 — [docs/release.zh-CN.md](./docs/release.zh-CN.md)
- Catalog V1 规范 — [docs/catalog-v1.zh-CN.md](./docs/catalog-v1.zh-CN.md)
- Verification 验证记录 — [docs/verification-2026-09-20.md](./docs/verification-2026-09-20.md)（英文）

## Compatibility

`catalog.json` targets `fluixa` `crates/runtime-store` **CATALOG_SPEC_VERSION
= 1** (RTS-V1.1). Schema changes require a spec bump + a documented migration;
consumers reject newer specs deterministically rather than guessing.

License: see [LICENSE](./LICENSE).

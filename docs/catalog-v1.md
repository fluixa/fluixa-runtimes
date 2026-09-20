# Runtime Catalog V1 — Schema Spec

> 简体中文版本：[catalog-v1.zh-CN.md](./catalog-v1.zh-CN.md)

Consumer baseline: `fluixa/crates/runtime-store` `CATALOG_SPEC_VERSION = 1`
(RTS-V1.1). This document mirrors the consumer's semantics 1:1 — when they
disagree, the Rust code wins and this doc must be fixed.

## Document

```json
{
  "spec_version": 1,
  "entries": [ { …CatalogEntry… } ]
}
```

| field | type | rules |
|---|---|---|
| `spec_version` | u32 | must be `1`; anything else is a deterministic parse failure in the consumer |
| `entries` | array | may be empty (consumer accepts; this repo keeps ≥ 1) |

## CatalogEntry

```json
{
  "kind": "python",
  "version": "3.11.10",
  "platform": "darwin",
  "arch": "x86_64",
  "size": 18011078,
  "sha256": "575b49a7aa64e97b06de605b7e947033bf2310b5bc5f9aedb9859d4745033d91",
  "urls": [
    "https://github.com/fluixa/fluixa-runtimes/releases/download/<tag>/<asset>",
    "https://gitee.com/fluixa/fluixa-runtimes/releases/download/<tag>/<asset-plus-encoded-as-%20>",
    "https://github.com/astral-sh/python-build-standalone/releases/download/20241016/<asset>"
  ],
  "entrypoints": {
    "interpreter": "python/bin/python3.11",
    "tool": "yt-dlp"
  },
  "ca_bundle": "cacert.pem"
}
```

| field | type | rules |
|---|---|---|
| `kind` | string | runtime family (`python`, …). Non-empty. Future: `node` (protocol-reserved, no entries published yet) |
| `version` | string | runtime version. Non-empty. Becomes the store directory `<kind>/<version>/<platform-arch>/` |
| `platform` | string | `darwin` / `windows` / `linux` |
| `arch` | string | `x86_64` / `aarch64` |
| `size` | u64 | archive size in **bytes, measured from the real artifact** (`gen_catalog.py`). Pre-check after download; `0` skips the pre-check (sha256 stays authoritative) |
| `sha256` | string | 64 lowercase hex of the archive. **Identical across all mirrors** — a mismatch ABORTS the install, the next mirror is never tried |
| `urls` | string[] | ordered download sources: primary → mirror1 → mirror2 → …; a transport failure (network/HTTP) falls through, a checksum mismatch does not. Mirrors must serve byte-identical content (sha256-pinned); **filename** may differ only via documented mirror transformations — Gitee normalizes `+` → space at upload, so its catalog URL carries the actual name (`%20`-encoded) |
| `entrypoints` | map name→path | paths relative to the instance directory; copied verbatim into `RUNTIME_MANIFEST.json`; must be non-empty; the installer makes them executable |
| `ca_bundle` | string? | path relative to the instance directory; the resolver emits `SSL_CERT_FILE=<abs>` when present |

Unspecified fields are ignored by the consumer (serde default) but are
**forbidden in this repo** — the catalog stays pure metadata and schema-clean.

## Validation rules (enforced by consumer + `verify_catalog.py`)

1. `spec_version == 1`, else deterministic failure.
2. `kind`/`version`/`platform`/`arch` non-empty.
3. `sha256` = 64 hex chars.
4. `urls` non-empty; `entrypoints` non-empty.
5. No duplicate `(kind, version, platform, arch)`.
6. Repo convention (this repo only): `python` entries require `interpreter` +
   `tool` entrypoints and a `ca_bundle`.

## Python layout convention (pbs `install_only`)

The python artifact is the upstream
`python-build-standalone` `install_only_stripped` tarball: the archive's top
directory `python/` is preserved inside the instance, so:

- instance root = `<store>/python/<version>/<platform-arch>/`
- interpreter   = `<instance>/python/bin/python3.11`
- extras (copied at install time from app-provided files):
  `<instance>/yt-dlp` (executable zipapp), `<instance>/cacert.pem`

## Adding a new entry (checklist)

```sh
# 1. place the real archive at
#    artifacts/<kind>/<version>/<asset-name>   (asset name = urls basename)
# 2. add the entry to catalog.json with size/sha256 = 0/placeholder
# 3. python3 scripts/gen_catalog.py --update     # measures bytes, regenerates SHA256SUMS
# 4. python3 scripts/verify_catalog.py --upstream --check-urls
# 5. add release tag docs if a new version family (docs/release.md)
```

`kind=node` extension: same shape; `entrypoints` would be e.g.
`{"bin": "node/bin/node"}`. Nothing else in the schema changes — do NOT
publish node entries until a real artifact exists.

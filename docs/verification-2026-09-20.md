# Compatibility Verification — 2026-09-20 (Gitee mirror filename)

Follow-up to [verification-2026-09-19.md](./verification-2026-09-19.md):
the Gitee release was published and immediately exposed a mirror-side
filename transformation. Scope of the fix: distribution layer only —
**no schema change, no installer change, no artifact rename, GitHub/pbs
URLs untouched.**

## Gitee behavior (probed, not assumed)

Gitee normalizes `+` in release-asset file names to a space at upload time:

| URL form | probe |
|---|---|
| `…/python-3.11.10/cpython-3.11.10%20202410116-…tar.gz` (space, %20-encoded) | **200** |
| `…/python-3.11.10/cpython-3.11.10+20241016-…tar.gz` (original name) | **404** |

## Mirror byte identity (measured)

Downloaded the actually-served Gitee file and hashed it:

```
size   = 18011078
sha256 = 575b49a7aa64e97b06de605b7e947033bf2310b5bc5f9aedb9859d4745033d91
```

→ identical to the catalog entry, the GitHub asset, and the official pbs
SHA256SUMS. The rename is metadata-only; byte identity (the actual safety
property) is intact and remains enforced by size+sha256 on every install.

## Changes

- `catalog.json`: Gitee URL now uses the actually-served name
  (`%20`-encoded). GitHub + pbs URLs keep the original name; local artifact
  path convention (derived from `urls[0]`) unchanged.
- `scripts/verify_catalog.py`: mirror-filename check rewritten —
  percent-decode then allow the documented Gitee `+` → space
  transformation (→ OK); any other drift → WARN (bytes stay sha256-pinned;
  filenames are metadata, never identity).
- `scripts/gen_catalog.py` docstring, `scripts/release.sh` Gitee checklist
  note, `docs/release.md` (§Release assets + new §Gitee `+` → space
  normalization), `docs/catalog-v1.md` (`urls` field rule + example),
  `README.md` status: **Gitee = published**.

## Verification results

```text
verify_catalog.py --fetch       PASS: 3 ok, 0 warn, 0 fail
verify_catalog.py --upstream    PASS: 4 ok, 0 warn, 0 fail
verify_catalog.py --check-urls  Gitee → OK (200); GitHub release → WARN 404
                                (pending publication, expected); 0 fail
```

Consumer compatibility: no main-repo code change — the installer walks
`urls[]` in order and pins every download with size+sha256, so the renamed
mirror needs no installer awareness.

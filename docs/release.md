# Release & Mirroring

## Naming conventions

### Artifact file name

Passthrough artifacts keep their upstream name (bytes are upstream-identical;
the name is the tracking handle):

```
cpython-<pyver>+<pbs-tag>-<rust-triple>-install_only_stripped.tar.gz
# e.g.
cpython-3.11.10+20241016-x86_64-apple-darwin-install_only_stripped.tar.gz
```

Repo-local cache path mirrors the catalog key:

```
artifacts/<kind>/<version>/<asset-name>
# artifacts/python/3.11.10/cpython-3.11.10+20241016-x86_64-apple-darwin-install_only_stripped.tar.gz
```

Auxiliary assets keep fixed names (`assets/yt-dlp-zipimport`,
`assets/cacert.pem`) — their versions are documented in `checksums/SHA256SUMS`
and the release notes, not in the file name.

### Release tag

```
<kind>-<version>          # e.g. python-3.11.10
```

`kind` must not contain `-` (python, node, …). One tag per kind+version;
assets for every `platform-arch` of that entry are attached to the same tag.

### Release assets

Every platform-arch archive of the entry + the auxiliary `assets/*` files.
GitHub and Gitee releases must carry **byte-identical** files — SHA-256 is
checked downstream and a mismatching mirror aborts installs.

## Platform matrix

| kind | version | darwin-x86_64 | darwin-aarch64 | windows-x86_64 | linux-x86_64 | linux-aarch64 |
|---|---|---|---|---|---|---|
| python | 3.11.10 | ✅ published | not built | not built | not built | not built |

Add a row only when a real artifact has been verified
(`verify_catalog.py --upstream` green).

## Publishing procedure

```sh
python3 scripts/verify_catalog.py --fetch              # 1. artifacts local + verified
scripts/release.sh python-3.11.10                      # 2. verify gate → gh draft release
# 3. review + publish the draft on GitHub
# 4. mirror to Gitee (below)
# 5. re-verify mirrors:
python3 scripts/verify_catalog.py --check-urls
```

`release.sh` runs `verify_catalog.py --upstream` as a hard gate, attaches all
entry artifacts + `assets/*` to a **draft** GitHub release on
`fluixa-project/fluixa-runtimes`, and prints the Gitee checklist.

## GitHub (primary)

- Repo: `fluixa-project/fluixa-runtimes`, branch `main`, `catalog.json` at the
  repo root — this IS the consumer's `DEFAULT_CATALOG_URL`
  (`raw.githubusercontent.com/fluixa-project/fluixa-runtimes/main/catalog.json`).
- Release assets via `gh release create <tag> --draft …` (see `scripts/release.sh`).

## Gitee (mirror 1)

Manual (web) or API with `GITEE_TOKEN`:

```sh
# create release
curl -X POST "https://gitee.com/api/v5/repos/fluixa-project/fluixa-runtimes/releases" \
  -H "Content-Type: application/json" \
  -d '{"access_token":"…","tag_name":"python-3.11.10","name":"Runtime python-3.11.10","target_commitish":"main"}'
# upload attachment (per file; release_id from the create response)
curl -X POST "https://gitee.com/api/v5/repos/fluixa-project/fluixa-runtimes/releases/<release_id>/attach_files" \
  -H "Content-Type: multipart/form-data" -H "access_token: …" -F "file=@<path>"
```

The public download URL then matches the catalog entry:
`https://gitee.com/fluixa-project/fluixa-runtimes/releases/download/<tag>/<asset>`.

## Official CDN (future)

Append the CDN URL to the entry's `urls[]` — position defines fallback
priority (earlier = preferred). No other change is needed; the CDN must serve
the same bytes (same basename, verified by `sha256` + `size`).

## Bootstrap note

Until the GitHub/Gitee releases are published, their urls resolve 404 and the
installer falls through to the upstream pbs source (live). This is the
designed fallback behavior — `verify_catalog.py` reports it as WARN, not
FAIL, and `--strict-urls` escalates it once the release is live.

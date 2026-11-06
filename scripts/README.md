# Runtime Builder — scripts/

Dev/publish-stage tooling that prepares, validates and packages the shared
runtime artifacts of this repository. **Never runs on end-user machines** —
user-facing downloads are owned by the main app's Runtime Manager
(Runtime Preflight → catalog → installer).

```
scripts/
├── fetch-runtime.sh      unified entry: arg parsing, common checks, temp
│                         dir, logging, module dispatch
├── release.sh            publish a catalog version as a GitHub Release
│                         (draft) + Gitee mirror checklist
├── runtimes/
│   ├── ffmpeg.sh         ffmpeg runtime module (migrated from
│                         fluixa/extensions/media/scripts/fetch-tools.sh v2)
│   └── python.sh         thin module — python artifacts are upstream
│                         passthroughs; local-verify delegates to
│                         verify_catalog.py
├── lib/
    ├── common.sh         logging / exit codes / temp dirs / proxy curl / JSON
    ├── checksum.sh       sha256 + size verification
    ├── archive.sh        zip/tar extraction + binary location
    ├── platform.sh       platform detection + BLOCKED/PENDING source matrix
    └── release_tag.sh    release-tag parser (catalog-kind longest-prefix;
                          hyphenated versions like
                          ffmpeg-128263-g9f9b9548583-lgpl stay intact)
└── tests/
    └── test_release_parse.sh   tag-parser tests (real catalog read-only +
                                temp fixtures; no artifacts touched)
```

## Usage

```sh
# ffmpeg: fetch upstream → validate → assemble artifact (2×26MB download)
./scripts/fetch-runtime.sh ffmpeg --platform darwin-x86_64

# ffmpeg: regression against the EXISTING local artifact — no download,
# no overwrite (sha256 vs catalog, both binaries execute, version pair
# matches, full capability gates: palettegen/paletteuse, videotoolbox+libwebp, no-GPL, mp4
# encode → ffprobe read-back, GIF pipeline)
./scripts/fetch-runtime.sh ffmpeg local-verify

# python: offline catalog verification of existing artifacts
./scripts/fetch-runtime.sh python local-verify

# release (maintainer): verify_catalog gate → asset collection → draft release
# Release classes (a release carries ONLY its own class's assets):
#   python-<version>  → artifacts/python/<version>/* only
#   ffmpeg-<version>  → artifacts/ffmpeg/<version>/* only (ffmpeg+ffprobe pair)
#   shared-assets     → assets/cacert.pem only
#   media-tools       → assets/yt-dlp-zipimport only
./scripts/release.sh python-3.11.10
./scripts/release.sh ffmpeg-128263-g9f9b9548583-lgpl   # hyphenated version — OK
./scripts/release.sh ffmpeg-128263-g9f9b9548583-lgpl --dry-run   # print, don't publish
./scripts/release.sh shared-assets --dry-run
./scripts/release.sh media-tools --dry-run

# tag parser tests (read-only; run after touching release.sh/release_tag.sh)
./scripts/tests/test_release_parse.sh
# release asset classification tests (assert no cross-class leakage +
# ffmpeg artifact sha256 unchanged)
./scripts/tests/test_release_assets.sh
# release notes tempfile tests (macOS mktemp pattern: trailing X-run, no
# fixed suffix, cleanup trap on all exit paths)
./scripts/tests/test_release_tmpfile.sh
```

Options: `--version <build-id>` (pin; mismatch = fail, never substitute),
`--proxy socks5h://host:port` (or `FLUIXA_FETCH_PROXY`), `--force`
(ffmpeg build: allow overwriting an existing artifact — re-audit first,
existing release artifacts are otherwise NEVER overwritten).

## Exit codes

| code | meaning |
|---|---|
| 0 | success |
| 1 | validation/environment failure |
| 2 | **BLOCKED** — no audited upstream source for the platform; zero artifacts are produced (never fabricate) |

## Platform source matrix

| runtime | platform | source | state |
|---|---|---|---|
| ffmpeg | darwin-x86_64 | evermeet.cx Info API (version-pinned URL + size + .sig; legacy `get*` endpoints 410 — do not use) | implemented |
| ffmpeg | darwin-aarch64 | — | **BLOCKED** (evermeet is x86_64-only; needs a source build with recorded buildconf + sha256) |
| ffmpeg | windows-x86_64 | gyan.dev / BtbN (both publish SHA-256) | **PENDING** |
| python | darwin-x86_64 | upstream passthrough (astral-sh/python-build-standalone 20241016) | published |

Keep this matrix in sync with `lib/platform.sh` and the audit docs
(`docs/ffmpeg-*.md`).

## ffmpeg module — preserved invariants (fetch-tools.sh v2 heritage)

- ffmpeg/ffprobe must come from the SAME upstream build (build id enforced).
- Per-binary: size vs Info API, Mach-O arch check, executable bit,
  `-version` build-id match, sha256.
- License audit: GPL flags recorded as facts; `--enable-nonfree` aborts.
- Capability gates (real execution, never version-string judgments):
  palettegen + paletteuse filters, videotoolbox/libwebp encoders, NO-GPL audit, decoder-count sanity,
  end-to-end `lavfi → videotoolbox → mp4 → ffprobe read-back`, real GIF
  palette pipeline.
- Catalog JSON snippet printed for review; artifact protection refuses to
  clobber existing release artifacts (use `--force` only after a
  documented re-audit).
- License audit enforces **LGPL-only** (GPL flags → abort); see `licenses/ffmpeg-lgpl/` before
  publishing — commercial redistribution needs legal review; LGPL build
  plan documented there too.

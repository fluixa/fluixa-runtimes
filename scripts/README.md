# Runtime Builder — scripts/

Dev/publish-stage tooling that prepares, validates and packages the shared
runtime artifacts of this repository. **Never runs on end-user machines** —
user-facing downloads are owned by the main app's Runtime Manager
(Runtime Preflight → catalog → installer).

```
scripts/
├── fetch-runtime.sh      unified entry: arg parsing, common checks, temp
│                         dir, logging, module dispatch
├── runtimes/
│   ├── ffmpeg.sh         ffmpeg runtime module (migrated from
│                         fluixa/extensions/media/scripts/fetch-tools.sh v2)
│   └── python.sh         thin module — python artifacts are upstream
│                         passthroughs; local-verify delegates to
│                         verify_catalog.py
└── lib/
    ├── common.sh         logging / exit codes / temp dirs / proxy curl / JSON
    ├── checksum.sh       sha256 + size verification
    ├── archive.sh        zip/tar extraction + binary location
    └── platform.sh       platform detection + BLOCKED/PENDING source matrix
```

## Usage

```sh
# ffmpeg: fetch upstream → validate → assemble artifact (2×26MB download)
./scripts/fetch-runtime.sh ffmpeg --platform darwin-x86_64

# ffmpeg: regression against the EXISTING local artifact — no download,
# no overwrite (sha256 vs catalog, both binaries execute, version pair
# matches, full capability gates: palettegen/paletteuse, libx264, mp4
# encode → ffprobe read-back, GIF pipeline)
./scripts/fetch-runtime.sh ffmpeg local-verify

# python: offline catalog verification of existing artifacts
./scripts/fetch-runtime.sh python local-verify
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
  palettegen + paletteuse filters, libx264 encoder, decoder-count sanity,
  end-to-end `lavfi → libx264 → mp4 → ffprobe read-back`, real GIF
  palette pipeline.
- Catalog JSON snippet printed for review; artifact protection refuses to
  clobber existing release artifacts (use `--force` only after a
  documented re-audit).
- GPL-3+ binaries: read `docs/ffmpeg-128263-g9f9b9548583.md` before
  publishing — commercial redistribution needs legal review; LGPL build
  plan documented there too.

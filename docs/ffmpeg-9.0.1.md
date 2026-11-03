# FFmpeg 9.0.1 Runtime — Build Audit & Distribution Notes

> **SUPERSEDED (2026-11-03)**: 该条目已从 catalog 移除——ffprobe 无法从
> evermeet 取得（per-tool 端点 410），由版本匹配的
> **128263-g9f9b9548583**（ffmpeg+ffprobe 成对）取代，
> 见 `docs/ffmpeg-128263-g9f9b9548583.md`。本文件保留作审计存证。

> 审计日期：2026-11-03。发布前必须保留本文件与 Release 资产同步。

## Artifact

```
kind        ffmpeg
version     9.0.1
platform    darwin
arch        x86_64
asset       ffmpeg-9.0.1-tessus-x86_64-apple-darwin.tar.gz
size        26931791 bytes
sha256      b63d5f20c4dfa96f99d9833b917b462aeaaa07d8fbdbdb570b71311992f85d48
layout      ffmpeg/bin/ffmpeg          (single static executable)
release tag ffmpeg-9.0.1
```

Archive layout follows the repo convention (top-level `ffmpeg/` preserved
inside the store instance, mirroring the python `python/` convention):
entrypoints `{"ffmpeg": "ffmpeg/bin/ffmpeg"}` resolve against the instance
root.

## Provenance

- Upstream binary: **evermeet.cx** ("tessus") build, fetched by the media
  extension's `fetch-tools.sh` (`https://evermeet.cx/ffmpeg/getrelease/zip`,
  unmodified passthrough — same bytes Fluixa has shipped in
  `extensions/media/tools/darwin-x86_64/ffmpeg` and field-verified across
  Screen Recording M1 real-machine testing).
- Build: Apple clang 17.0.0, statically linked (system frameworks only —
  `otool -L` shows Foundation/AudioToolbox/AVFoundation/VideoToolbox/…, no
  third-party dylibs to redistribute).

## License — READ THIS (not LGPL)

`ffmpeg -version` configuration includes **`--enable-gpl --enable-version3`
plus `--enable-libx264 --enable-libx265`** (and libaom/libvidstab/…).

→ The distributed **binary is GPL-3.0-or-later** (FFmpeg + enabled external
components). Distributing the unmodified binary is permitted under GPL with
source availability; the FFmpeg source for this exact build is
`https://evermeet.cx/ffmpeg/` (per-version source links are published
there). Fluixa's own code does not link FFmpeg — it invokes a separate
process — so the GPL does not extend to the Fluixa application itself, but
this must be re-confirmed by legal before commercial redistribution terms
are finalized.

No `--enable-nonfree` is present (verified in buildconf).

## Capability verification (executed 2026-11-03, this exact binary)

| Requirement | Result |
|---|---|
| `ffmpeg -version` | 9.0.1-tessus, libav* 61/63/63/12/10/7 |
| `ffmpeg -buildconf` | recorded above (GPL, static) |
| GIF palettegen / paletteuse | ✅ both present |
| Video decoding (common codecs) | ✅ 273 video decoders |
| Video encoding (libx264) | ✅ present (+ aac audio encoder) |
| MP4 probe | ✅ field-verified (recording preview probe chain) |
| Frame extraction (`-frames:v 1`) | ✅ field-verified (M1 frame extraction) |
| `ffprobe` | ❌ **NOT included — see gap below** |

## Known gap: ffprobe

The darwin-x86_64 artifact ships **ffmpeg only**. ffprobe is pending:

- evermeet.cx removed its `getrelease/<tool>/zip` API endpoints (HTTP 410,
  "exorbitant abuse") while this runtime was being packaged, and no local
  ffprobe 9.0.1 binary exists to audit.
- Impact is contained: the consumer (`apps/desktop/src/recording_media.rs`)
  already degrades to parsing `ffmpeg -i` stderr when ffprobe is absent
  (duration/resolution probing works — field-verified 2026-11-02).
- Next step: pick a ffprobe source with pinning + SHA-256 (e.g. build from
  FFmpeg 9.0.1 source, or a distribution that publishes checksums), then
  add the `ffprobe` entrypoint to this entry and re-release the asset.

## Platform matrix (this runtime)

| platform-arch | status |
|---|---|
| darwin-x86_64 | ✅ packaged, audited, catalog entry ready |
| darwin-aarch64 | ❌ PENDING — no audited binary; needs an arm64 build with recorded buildconf + sha256 (candidate: FFmpeg 9.0.1 source build, or a pinned third-party build with checksums) |
| windows-x86_64 | ❌ PENDING — needs a pinned build (candidates: gyan.dev / BtbN GitHub builds, both publish SHA-256) + zip packaging; Windows recording backend itself is still pending, so this entry is not urgent |

**Do not publish a release tag until every catalog entry it carries has a
real, locally verified artifact** (`verify_catalog.py` green).

## Publishing (when ready)

```sh
python3 scripts/verify_catalog.py            # offline gate
scripts/release.sh ffmpeg-9.0.1              # gh draft release
# review + publish on GitHub, then mirror to Gitee (byte-identical assets)
```

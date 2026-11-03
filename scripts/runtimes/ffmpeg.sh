#!/bin/bash
# Fluixa Runtime Builder — ffmpeg module.
#
# Migrated verbatim-in-behavior from extensions/media/scripts/fetch-tools.sh
# v2 (2026-11-03, real-download verified); only restructured into functions
# with lib/ helpers. Preserved capabilities: version pinning via the
# evermeet.cx Info API, ffmpeg/ffprobe same-build check, size/arch/exec/
# version/sha256 validation per binary, license flag audit (nonfree
# refused), palettegen/paletteuse + libx264 + decoder-count capability
# gates, end-to-end mp4 encode → ffprobe read-back, real GIF pipeline,
# catalog JSON snippet output, BLOCKED-platform zero-artifact semantics.
#
# Modes (dispatched by fetch-runtime.sh):
#   build         fetch from upstream → validate → assemble artifact
#                 (REFUSES to overwrite an existing artifact unless --force)
#   local-verify  regression against the EXISTING local artifact: unpack,
#                 verify sha256 vs catalog, run both binaries, check the
#                 pair versions match. No download, no writes.
#
# Env/args (set by the entry): FRT_PROXY, RUNTIMES_DIR, WORK, FFMPEG_VERSION
# (optional pin), FFMPEG_PLATFORM, FFMPEG_MODE, FFMPEG_FORCE.
# shellcheck shell=bash

FFMPEG_INFO_BASE="https://evermeet.cx/ffmpeg/info"

# ------------------------------------------------------------
# Upstream fetch (evermeet.cx Info API — the only live endpoint family;
# getrelease/zip and get/<tool>/zip returned 410 during the 2026-11-03
# audit — do NOT fall back to them).
# ------------------------------------------------------------

frt_ffmpeg_probe_tool() {
    # $1 tool-name → echoes nothing; writes $WORK/<tool>.info.json/.version
    local tool="$1"
    local info_url="${FFMPEG_INFO_BASE}/${tool}"
    local info_file="$WORK/${tool}.info.json"

    frt_info "Probing Info API: $info_url"
    local status
    status="$(frt_curl_status "$info_url")"
    if [ "$status" != "200" ]; then
        frt_error "Info API returned HTTP $status for $tool (expected 200)."
        frt_error "evermeet.cx may have changed its API — record and re-audit;"
        frt_error "do NOT substitute another build."
        exit 2
    fi
    frt_curl "$info_file" "$info_url" 60

    local version
    version="$(frt_json_field "$info_file" "d['version']")" || exit 2
    frt_info "$tool version: $version"

    # Version pinning: refuse silently-swapped builds.
    if [ -n "${FFMPEG_VERSION:-}" ] && [ "$version" != "$FFMPEG_VERSION" ]; then
        frt_error "Version mismatch for $tool:"
        frt_error "  requested: $FFMPEG_VERSION"
        frt_error "  upstream:  $version"
        frt_error "Refusing to substitute a different build."
        exit 2
    fi
    echo "$version" > "$WORK/${tool}.version"
}

frt_ffmpeg_download_tool() {
    # $1 tool-name → downloads the version-resolved zip (size-verified).
    local tool="$1"
    local info_file="$WORK/${tool}.info.json"
    local zip_url zip_size out="$WORK/${tool}.zip"
    zip_url="$(frt_json_field "$info_file" "d['download']['zip']['url']")" || exit 2
    zip_size="$(frt_json_field "$info_file" "d['download']['zip']['size']")" || exit 2

    frt_info "$tool zip url:  $zip_url"
    frt_info "$tool zip size: $zip_size"
    frt_info "Downloading $tool zip..."
    frt_curl "$out" "$zip_url" 900

    frt_verify_size "$out" "$zip_size" "$tool zip" || exit 2
    frt_sha256 "$out" > "$WORK/${tool}.zip.sha256"
    frt_info "$tool zip sha256: $(cat "$WORK/${tool}.zip.sha256")"

    # Preserve the publisher's detached signature for the release audit.
    local sig_status
    sig_status="$(frt_curl_status "${zip_url}.sig")"
    if [ "$sig_status" = "200" ]; then
        frt_curl "$WORK/${tool}.zip.sig" "${zip_url}.sig" 60
        frt_info "$tool detached signature saved (release audit)."
    else
        frt_warn "$tool signature unavailable (HTTP $sig_status) — recorded."
    fi
}

# ------------------------------------------------------------
# Per-binary validation
# ------------------------------------------------------------

frt_ffmpeg_validate_binary() {
    # $1 bin-path $2 tool-name $3 expected-version $4 expected-arch
    local bin="$1" tool="$2" expected_version="$3" expected_arch="$4"

    frt_info "Validating $tool..."
    local file_type
    file_type="$(file "$bin")"
    echo "$file_type"

    if ! echo "$file_type" | grep -q "$expected_arch"; then
        frt_error "$tool architecture mismatch: expected $expected_arch."
        exit 2
    fi
    frt_ok "$tool architecture is $expected_arch."

    local version_line
    version_line="$("$bin" -version 2>/dev/null | head -1)" || {
        frt_error "$tool -version failed to execute."
        exit 2
    }
    echo "$version_line"

    if ! echo "$version_line" | grep -q "$expected_version"; then
        frt_error "$tool binary version does not match Info API version:"
        frt_error "  binary: $version_line"
        frt_error "  info:   $expected_version"
        exit 2
    fi
    frt_ok "$tool version matches the Info API ($expected_version)."

    # License audit flags — GPL must stay a RECORDED FACT, never stripped.
    if [ "$tool" = "ffmpeg" ]; then
        local conf
        conf="$("$bin" -version 2>/dev/null | grep '^configuration:')"
        frt_info "$tool configuration: $conf"
        local flag
        for flag in --enable-gpl --enable-version3 --enable-libx264 --enable-libx265; do
            if echo "$conf" | grep -q -- "$flag"; then
                frt_info "build flag present: $flag"
            else
                frt_warn "build flag absent: $flag (record in the audit doc)"
            fi
        done
        if echo "$conf" | grep -q -- "--enable-nonfree"; then
            frt_error "--enable-nonfree build — NOT distributable. Abort."
            exit 2
        fi
    fi
}

# ------------------------------------------------------------
# Capability gates — never judge by version string alone.
# ------------------------------------------------------------

frt_ffmpeg_validate_capabilities() {
    local ffmpeg="$1" ffprobe="$2"

    frt_info "Capability checks..."

    local filters
    filters="$("$ffmpeg" -hide_banner -filters 2>/dev/null)"
    local f
    for f in palettegen paletteuse; do
        if echo "$filters" | grep -q " $f "; then
            frt_ok "filter present: $f"
        else
            frt_error "required filter missing: $f"
            exit 2
        fi
    done

    if "$ffmpeg" -hide_banner -encoders 2>/dev/null | grep -q "libx264"; then
        frt_ok "encoder present: libx264"
    else
        frt_error "required encoder missing: libx264"
        exit 2
    fi

    if [ "$("$ffmpeg" -hide_banner -decoders 2>/dev/null | grep -c '^ V')" -lt 50 ]; then
        frt_error "implausibly few video decoders — build looks broken."
        exit 2
    fi
    frt_ok "video decoders present."

    # End-to-end probe: synth frame → encode → ffprobe stream info.
    local sample="$WORK/sample.mp4"
    if ! "$ffmpeg" -hide_banner -loglevel error -f lavfi -i testsrc=duration=1:size=128x96:rate=10 \
            -c:v libx264 -pix_fmt yuv420p -y "$sample" 2>/dev/null; then
        frt_error "end-to-end encode failed (lavfi/libx264)."
        exit 2
    fi
    frt_ok "end-to-end encode (lavfi → libx264 → mp4)."

    if ! "$ffprobe" -v error -select_streams v:0 \
            -show_entries stream=codec_name,width,height -of csv=p=0 "$sample" \
            | grep -q "^h264,128,96"; then
        frt_error "ffprobe failed to report the encoded stream."
        exit 2
    fi
    frt_ok "ffprobe stream probe (h264 128x96)."

    # GIF pipeline used by Screen Recording post-processing.
    if "$ffmpeg" -hide_banner -loglevel error -i "$sample" \
            -vf "fps=10,palettegen" -y "$WORK/palette.png" 2>/dev/null \
        && "$ffmpeg" -hide_banner -loglevel error -i "$sample" -i "$WORK/palette.png" \
            -lavfi "fps=10 [x]; [x][1:v] paletteuse" -y "$WORK/out.gif" 2>/dev/null \
        && [ -s "$WORK/out.gif" ]; then
        frt_ok "GIF palettegen/paletteuse pipeline."
    else
        frt_error "GIF palette pipeline failed."
        exit 2
    fi
}

# ------------------------------------------------------------
# MODE: build (upstream → validate → assemble)
# ------------------------------------------------------------

frt_ffmpeg_build() {
    # Phase 1: probe BOTH tools (cheap) — resolves versions before any
    # heavy download, so artifact protection can fail fast.
    frt_ffmpeg_probe_tool "ffmpeg"
    frt_ffmpeg_probe_tool "ffprobe"

    local ff_version fp_version
    ff_version="$(cat "$WORK/ffmpeg.version")"
    fp_version="$(cat "$WORK/ffprobe.version")"

    if [ "$ff_version" != "$fp_version" ]; then
        frt_error "ffmpeg ($ff_version) and ffprobe ($fp_version) builds differ."
        frt_error "The pair must come from the same build. Aborting."
        exit 2
    fi
    frt_ok "ffmpeg + ffprobe are the same upstream build: $ff_version"

    # Artifact protection BEFORE downloading 2×26MB.
    local out_dir="$RUNTIMES_DIR/artifacts/ffmpeg/$ff_version"
    local asset_name="ffmpeg-${ff_version}-x86_64-apple-darwin.tar.gz"
    if [ -e "$out_dir/$asset_name" ] && [ "${FFMPEG_FORCE:-0}" != "1" ]; then
        frt_error "Artifact already exists (protected): $out_dir/$asset_name"
        frt_error "Existing release artifacts are never overwritten."
        frt_error "Use --force only after a documented re-audit."
        exit 1
    fi

    # Phase 2: heavy download + validation.
    frt_ffmpeg_download_tool "ffmpeg"
    frt_ffmpeg_download_tool "ffprobe"

    local ff_bin fp_bin
    ff_bin="$(frt_locate_binary "$(frt_extract_zip "$WORK/ffmpeg.zip" "$WORK/x1" && echo "$WORK/x1")" ffmpeg)"
    fp_bin="$(frt_locate_binary "$(frt_extract_zip "$WORK/ffprobe.zip" "$WORK/x2" && echo "$WORK/x2")" ffprobe)"

    # evermeet publishes x86_64 Mach-O for darwin.
    frt_ffmpeg_validate_binary "$ff_bin" ffmpeg "$ff_version" "x86_64"
    frt_ffmpeg_validate_binary "$fp_bin" ffprobe "$fp_version" "x86_64"

    frt_ffmpeg_validate_capabilities "$ff_bin" "$fp_bin"

    local ff_sha fp_sha
    ff_sha="$(frt_sha256 "$ff_bin")"
    fp_sha="$(frt_sha256 "$fp_bin")"
    frt_info "ffmpeg  sha256: $ff_sha"
    frt_info "ffprobe sha256: $fp_sha"

    local asset_path="$out_dir/$asset_name"

    local stage="$WORK/ffmpeg/bin"
    mkdir -p "$stage"
    cp "$ff_bin" "$stage/ffmpeg"
    cp "$fp_bin" "$stage/ffprobe"
    chmod 755 "$stage/ffmpeg" "$stage/ffprobe"

    mkdir -p "$out_dir"
    tar -czf "$asset_path" -C "$WORK" ffmpeg

    local art_sha art_size
    art_sha="$(frt_sha256 "$asset_path")"
    art_size="$(frt_file_size "$asset_path")"

    echo
    echo "============================================================"
    echo " FFmpeg Runtime artifact assembled"
    echo "============================================================"
    echo
    frt_ok "artifact:"
    echo "     $asset_path"
    echo "     size:   $art_size"
    echo "     sha256: $art_sha"
    echo
    frt_info "ffmpeg  build id: $ff_version"
    echo "[INFO] archive zips: ffmpeg=$(cat "$WORK/ffmpeg.zip.sha256")"
    echo "                     ffprobe=$(cat "$WORK/ffprobe.zip.sha256")"
    echo
    frt_info "Catalog entry to review before committing (urls point at the"
    frt_info "release tag ffmpeg-$ff_version — PUBLISH before any store"
    frt_info "client can resolve this entry):"
    echo
    cat <<EOF
    {
      "kind": "ffmpeg",
      "version": "$ff_version",
      "platform": "darwin",
      "arch": "x86_64",
      "size": $art_size,
      "sha256": "$art_sha",
      "urls": [
        "https://github.com/fluixa/fluixa-runtimes/releases/download/ffmpeg-${ff_version}/$asset_name",
        "https://gitee.com/fluixa/fluixa-runtimes/releases/download/ffmpeg-${ff_version}/$asset_name"
      ],
      "entrypoints": {
        "ffmpeg": "ffmpeg/bin/ffmpeg",
        "ffprobe": "ffmpeg/bin/ffprobe"
      }
    }
EOF
    echo
    frt_info "License: GPL-3+ build (libx264/x265) — see docs/ffmpeg-*.md"
    frt_info "before publishing."
}

# ------------------------------------------------------------
# MODE: local-verify (regression against the EXISTING local artifact —
# no download, no overwrite)
# ------------------------------------------------------------

frt_ffmpeg_local_verify() {
    local platform="${FFMPEG_PLATFORM:-$(frt_detect_platform)}"
    # Catalog convention: separate "platform" ("darwin") and "arch" ("x86_64")
    # fields; the builder uses combined "<os>-<arch>" identifiers.
    local cat_platform="${platform%%-*}"
    local arch="${platform##*-}"

    # Resolve the EXPECTED version from the catalog first, then locate the
    # local artifact by that exact version (never lexicographic — e.g.
    # "9.0.1" sorts after "128263-…" but is the OLDER entry).
    local catalog="$RUNTIMES_DIR/catalog.json"
    local cat_version cat_sha
    cat_version="$(frt_json_field "$catalog" "[e for e in d['entries'] if e['kind']=='ffmpeg' and e['platform']=='$cat_platform' and e['arch']=='$arch'][0]['version']")" || {
        frt_exit_fail "No ffmpeg catalog entry for platform $platform."
    }
    cat_sha="$(frt_json_field "$catalog" "[e for e in d['entries'] if e['kind']=='ffmpeg' and e['platform']=='$cat_platform' and e['arch']=='$arch'][0]['sha256']")" || exit 1

    local artifact="$RUNTIMES_DIR/artifacts/ffmpeg/$cat_version/ffmpeg-${cat_version}-${arch}-apple-darwin.tar.gz"
    if [ ! -f "$artifact" ]; then
        frt_exit_fail "Local artifact missing for catalog version $cat_version:"
        frt_error "  expected: $artifact"
    fi
    frt_info "Local artifact:"
    frt_info "  $artifact"

    # Catalog cross-check: sha256 must match catalog.json.
    local art_sha
    art_sha="$(frt_sha256 "$artifact")"
    if [ "$art_sha" != "$cat_sha" ]; then
        frt_error "Artifact sha256 does NOT match catalog:"
        frt_error "  artifact: $art_sha"
        frt_error "  catalog:  $cat_sha"
        frt_error "Stopping — existing release artifacts are never overwritten;"
        frt_error "investigate the difference instead."
        exit 1
    fi
    frt_ok "artifact sha256 matches catalog entry ($cat_version)."

    # Unpack to an ISOLATED temp dir and run both binaries.
    frt_extract_tar_gz "$artifact" "$WORK/unpacked"
    local ff_bin fp_bin
    ff_bin="$(frt_locate_binary "$WORK/unpacked/ffmpeg" ffmpeg)"
    fp_bin="$(frt_locate_binary "$WORK/unpacked/ffmpeg" ffprobe)"

    frt_ffmpeg_validate_binary "$ff_bin" ffmpeg "$cat_version" "x86_64"
    frt_ffmpeg_validate_binary "$fp_bin" ffprobe "$cat_version" "x86_64"
    frt_ffmpeg_validate_capabilities "$ff_bin" "$fp_bin"

    frt_ok "local-verify PASS: $artifact (version $cat_version, sha256 unchanged)"
}

# ------------------------------------------------------------
# Dispatch
# ------------------------------------------------------------

case "${FFMPEG_MODE:-}" in
    build)        frt_ffmpeg_build ;;
    local-verify) frt_ffmpeg_local_verify ;;
    *)
        frt_error "ffmpeg: unknown mode '${FFMPEG_MODE:-}' (expected build|local-verify)."
        exit 1
        ;;
esac

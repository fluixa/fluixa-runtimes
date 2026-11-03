#!/bin/bash
#
# Fluixa Runtime Builder — unified entry.
#
# DEV/PUBLISH-STAGE ONLY: prepares, validates and packages shared runtime
# artifacts for THIS repository. Never runs on end-user machines — user-
# facing downloads are owned by the main app's Runtime Manager
# (Runtime Preflight → catalog → installer).
#
# Usage:
#   ./scripts/fetch-runtime.sh <runtime> [mode] [options]
#
#   runtimes:  ffmpeg | python
#   modes:     build (default)        fetch upstream → validate → assemble
#              local-verify           regression against the EXISTING local
#                                     artifact — no download, no overwrite
#   options:   --platform <os-arch>   default: auto-detect (darwin-x86_64…)
#              --version <id>         pin the upstream build (mismatch = fail)
#              --proxy <url>          socks5h://… or http://… (or
#                                     FLUIXA_FETCH_PROXY env)
#              --force                ffmpeg build: allow overwriting an
#                                     existing artifact (re-audit first!)
#
# Examples:
#   ./scripts/fetch-runtime.sh ffmpeg --platform darwin-x86_64
#   ./scripts/fetch-runtime.sh ffmpeg local-verify
#   ./scripts/fetch-runtime.sh python local-verify
#
# Exit codes: 0 success; 1 validation/environment failure; 2 BLOCKED
# (no audited upstream source for the platform — zero artifacts).

set -e

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIMES_DIR="${FLUIXA_RUNTIMES_REPO:-$(cd "$SCRIPTS_DIR/.." && pwd)}"

RUNTIME_KIND=""
RUNTIME_MODE="build"
PLATFORM=""
VERSION_PIN=""
PROXY="${FLUIXA_FETCH_PROXY:-}"
FORCE=0

while [ $# -gt 0 ]; do
    case "$1" in
        ffmpeg|python)
            RUNTIME_KIND="$1"
            shift
            ;;
        build|local-verify)
            RUNTIME_MODE="$1"
            shift
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --version)
            VERSION_PIN="$2"
            shift 2
            ;;
        --proxy)
            PROXY="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        -h|--help)
            sed -n '2,26p' "$0"
            exit 0
            ;;
        *)
            echo "[runtime-builder] [ERROR] Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

[ -n "$RUNTIME_KIND" ] || { sed -n '2,26p' "$0"; exit 1; }
[ -d "$RUNTIMES_DIR/scripts" ] || {
    echo "[runtime-builder] [ERROR] Not a fluixa-runtimes checkout: $RUNTIMES_DIR" >&2
    exit 1
}

# lib + module plumbing.
export FRT_PROXY="$PROXY"
. "$SCRIPTS_DIR/lib/common.sh"
. "$SCRIPTS_DIR/lib/checksum.sh"
. "$SCRIPTS_DIR/lib/archive.sh"
. "$SCRIPTS_DIR/lib/platform.sh"

frt_require_commands curl file shasum awk grep find head uname tar python3

[ -f "$RUNTIMES_DIR/catalog.json" ] || frt_exit_fail "catalog.json missing in $RUNTIMES_DIR"

# Platform: explicit flag wins; otherwise detect. The BLOCKED/PENDING
# matrix lives in lib/platform.sh (single source of truth).
if [ -z "$PLATFORM" ]; then
    PLATFORM="$(frt_detect_platform)" || frt_exit_fail "Unsupported host platform."
fi
frt_assert_runtime_platform "$RUNTIME_KIND" "$PLATFORM"

WORK="$(frt_make_workdir)"
trap 'rm -rf "$WORK"' EXIT INT TERM

echo
echo "============================================================"
echo " Fluixa Runtime Builder — $RUNTIME_KIND / $PLATFORM / $RUNTIME_MODE"
echo "============================================================"
echo
frt_info "Repository: $RUNTIMES_DIR"
frt_info "Work dir:   $WORK"
[ -n "$VERSION_PIN" ] && frt_info "Version pin: $VERSION_PIN"

case "$RUNTIME_KIND" in
    ffmpeg)
        export FFMPEG_MODE="$RUNTIME_MODE"
        export FFMPEG_PLATFORM="$PLATFORM"
        export FFMPEG_VERSION="$VERSION_PIN"
        export FFMPEG_FORCE="$FORCE"
        . "$SCRIPTS_DIR/runtimes/ffmpeg.sh"
        ;;
    python)
        export PYTHON_MODE="$RUNTIME_MODE"
        . "$SCRIPTS_DIR/runtimes/python.sh"
        ;;
    *)
        frt_exit_fail "Unknown runtime kind: $RUNTIME_KIND"
        ;;
esac

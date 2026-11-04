#!/usr/bin/env bash
# release.sh — publish runtime artifacts as GitHub Release (draft) + Gitee mirror
# checklist. Git-tree hygiene: artifacts are Release assets, never committed.
#
# Usage:
#   scripts/release.sh <tag> [--dry-run]
#
# Release classes (assets are CLASSIFIED — a release carries ONLY its own
# class, see scripts/lib/release_assets.sh):
#   python-<version>   python runtime artifact only
#   ffmpeg-<version>   ffmpeg + ffprobe artifact only
#   shared-assets      cacert.pem only
#   media-tools        yt-dlp-zipimport only
#
# Prerequisites:
#   - gh CLI installed + authenticated (github.com)
#   - artifacts/ populated locally: python3 scripts/verify_catalog.py --fetch
#
# Gitee mirroring is manual (web UI or API) — see docs/release.md §Gitee.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=0
ARGS=()
for A in "$@"; do
    case "$A" in
        --dry-run) DRY_RUN=1 ;;
        *) ARGS+=("$A") ;;
    esac
done
TAG="${ARGS[0]:-usage: release.sh <tag> [--dry-run]  (e.g. python-3.11.10)}"

case "$TAG" in
    shared-assets|media-tools)
        # Fixed-asset release classes — not catalog entries, no --expect gate.
        KIND="$TAG"
        VERSION=""
        ;;
    *)
        cd "$ROOT"
        . "$(dirname "$0")/lib/release_tag.sh"

        # Parse <kind>-<version> against the CATALOG kinds (longest prefix
        # match). ${TAG%-*} would corrupt hyphenated versions like
        # ffmpeg-128263-g9f9b9548583 → (ffmpeg-128263 / g9f9b9548583).
        PARSED="$(parse_release_tag "$TAG" catalog.json)" || {
            echo "ERROR: cannot resolve release tag '$TAG'." >&2
            exit 1
        }
        KIND="${PARSED%% *}"; VERSION="${PARSED#* }"
        ;;
esac
cd "$ROOT"
echo "==> tag: kind=$KIND version=$VERSION"

if [ "$KIND" != "shared-assets" ] && [ "$KIND" != "media-tools" ]; then
    echo "==> 1/4 verify catalog (release gate)"
    python3 scripts/verify_catalog.py --upstream --expect "${KIND}@${VERSION}:darwin-x86_64"
else
    echo "==> 1/4 verify catalog (fixed-asset class — full offline gate)"
    python3 scripts/verify_catalog.py
fi

. "$(dirname "$0")/lib/release_assets.sh"

echo "==> 2/4 collect release assets for $TAG"
ASSET_FILES="$(collect_release_assets "$KIND" "$VERSION" catalog.json "$ROOT")" || exit 1
echo "    assets:$ASSET_FILES"
[ -n "$ASSET_FILES" ] || { echo "ERROR: no assets for tag $TAG" >&2; exit 1; }

echo "==> 3/4 checksums"
python3 scripts/gen_catalog.py

echo "==> 4/4 GitHub draft release"
GH_CMD=(gh release create -R fluixa/fluixa-runtimes "$TAG" --draft --title "Runtime $TAG")
# macOS BSD mktemp: the X-run must TRAIL the template — a suffix like
# `XXXX.md` makes mkstemp fail ("File exists"). Use ${TMPDIR:-/tmp} + a
# trailing X-run; gh --notes-file does not care about the extension.
NOTES="$(mktemp "${TMPDIR:-/tmp}/fluixa-release-notes-XXXXXXXX")"
trap 'rm -f "${NOTES:-}"' EXIT INT TERM
{
    echo "Runtime distribution $TAG"
    echo ""
    echo "| asset | size | sha256 |"
    echo "|---|---|---|"
    for F in $ASSET_FILES; do
        printf '| %s | %s | %s |\n' "$(basename "$F")" "$(stat -f '%z' "$F")" \
            "$(shasum -a 256 "$F" | cut -d' ' -f1)"
    done
    echo ""
    echo "Mirrors serve identical bytes; SHA-256 is the identity (catalog.json)."
    echo "Origin and audit trail: docs/ in this repo (per-runtime audit docs)."
} > "$NOTES"
GH_CMD+=(--notes-file "$NOTES")
for F in $ASSET_FILES; do GH_CMD+=("$F"); done

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] would execute:"
    printf '    %q ' "${GH_CMD[@]}"; echo
    echo "[DRY-RUN] notes file (kept for review): $NOTES"
    echo "[DRY-RUN] no release was created."
    CLEANUP_NOTES=0
    trap - EXIT INT TERM
    exit 0
fi

command -v gh >/dev/null 2>&1 || {
    echo "gh CLI not found — create the release manually:"
    echo "  repo: fluixa/fluixa-runtimes  tag: $TAG"
    echo "  assets:$ASSET_FILES"
    echo "  notes file (kept for review): $NOTES"
    CLEANUP_NOTES=0
    trap - EXIT INT TERM
    exit 2
}
"${GH_CMD[@]}"
trap - EXIT INT TERM
rm -f "$NOTES"
echo ""
echo "Published (draft). After review: publish the release, then mirror to Gitee:"
echo "  1. Gitee repo fluixa/fluixa-runtimes → 发行版 → 新建 $TAG"
echo "  2. upload the SAME files (bytes must be identical; SHA-256 enforced downstream)"
echo "     NOTE: Gitee renames '+' to space in asset names — expected behavior;"
echo "     put the resulting name into catalog.json urls[] (space → %20)"
echo "  3. verify mirrors: python3 scripts/verify_catalog.py --check-urls"

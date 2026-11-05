#!/bin/bash
# Tests for scripts/lib/release_assets.sh — release asset CLASSIFICATION.
# Read-only against the real catalog + artifacts (sha256 asserted, never
# rewritten). Negative cases use the real catalog too (missing-file paths
# are exercised via a nonexistent version).
# shellcheck shell=bash
set -u

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$SCRIPTS_DIR/.."
# shellcheck source=../lib/release_assets.sh
. "$SCRIPTS_DIR/lib/release_assets.sh"

PASS=0
FAIL=0
ok()   { echo "ok   $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL $*"; FAIL=$((FAIL + 1)); }

# ------------------------------------------------------------
# ffmpeg: exactly one artifact, no shared assets
# ------------------------------------------------------------
GOT="$(collect_release_assets ffmpeg 128263-g9f9b9548583-lgpl "$ROOT/catalog.json" "$ROOT" 2>&1)"
CASE="ffmpeg classification"
if [ "$GOT" = " artifacts/ffmpeg/128263-g9f9b9548583-lgpl/ffmpeg-128263-g9f9b9548583-lgpl-x86_64-apple-darwin.tar.gz" ]; then
    ok "$CASE (single artifact, correct path)"
else
    fail "$CASE — got: '$GOT'"
fi
case "$GOT" in
    *cacert.pem*|*yt-dlp-zipimport*) fail "$CASE — leaked shared assets into ffmpeg release" ;;
    *) ok "$CASE (no cacert.pem / yt-dlp-zipimport leakage)" ;;
esac

# ------------------------------------------------------------
# ffmpeg artifact sha256 — the release asset is THE audited artifact
# ------------------------------------------------------------
GOT="${GOT# }"
EXPECT_SHA="d64d3ead85c39004e4a075510d5b09c0a669d6be60ee95ffdee28af19a97d06e"
ART_SHA="$(shasum -a 256 "$ROOT/$GOT" | awk '{print $1}')"
if [ "$ART_SHA" = "$EXPECT_SHA" ]; then
    ok "ffmpeg artifact sha256 unchanged ($ART_SHA)"
else
    fail "ffmpeg artifact sha256 DRIFTED: $ART_SHA (expected $EXPECT_SHA)"
fi

# ------------------------------------------------------------
# python: only the python artifact
# ------------------------------------------------------------
GOT="$(collect_release_assets python 3.11.10 "$ROOT/catalog.json" "$ROOT" 2>&1)"
case "$GOT" in
    " artifacts/python/3.11.10/"*.tar.gz)
        case "$GOT" in
            *cacert.pem*|*yt-dlp-zipimport*|*ffmpeg*) fail "python classification leaked other assets: '$GOT'" ;;
            *) ok "python classification (single artifact)" ;;
        esac
        ;;
    *)
        fail "python classification — got: '$GOT'"
        ;;
esac

# ------------------------------------------------------------
# fixed-asset classes
# ------------------------------------------------------------
GOT="$(collect_release_assets shared-assets "" catalog.json "$ROOT" 2>&1)"
[ "$GOT" = " assets/cacert.pem" ] && ok "shared-assets → cacert.pem only" || fail "shared-assets — got: '$GOT'"

GOT="$(collect_release_assets media-tools "" catalog.json "$ROOT" 2>&1)"
[ "$GOT" = " assets/yt-dlp-zipimport" ] && ok "media-tools → yt-dlp-zipimport only" || fail "media-tools — got: '$GOT'"

# ------------------------------------------------------------
# negatives
# ------------------------------------------------------------
if collect_release_assets ffmpeg 9.9.9-nope catalog.json "$ROOT" >/dev/null 2>&1; then
    fail "missing version accepted (should fail)"
else
    ok "missing version rejected"
fi

if collect_release_assets nosuchclass "" catalog.json "$ROOT" >/dev/null 2>&1; then
    fail "unknown class accepted (should fail)"
else
    ok "unknown class rejected"
fi

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]

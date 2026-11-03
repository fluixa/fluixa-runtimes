#!/bin/bash
# Tests for scripts/lib/release_tag.sh — tag parsing ONLY.
# Read-only against the real catalog.json; negative cases use a temp
# fixture. No artifacts are touched.
# shellcheck shell=bash
set -u

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/release_tag.sh
. "$SCRIPTS_DIR/lib/release_tag.sh"

cd "$SCRIPTS_DIR/.."
PASS=0
FAIL=0

assert_parse() {
    # assert_parse <tag> <expected-kind> <expected-version>
    local tag="$1" want_kind="$2" want_version="$3"
    local got
    if got="$(parse_release_tag "$tag" catalog.json 2>/dev/null)"; then
        if [ "$got" = "$want_kind $want_version" ]; then
            echo "ok   parse '$tag' → $got"
            PASS=$((PASS + 1))
        else
            echo "FAIL parse '$tag' → '$got' (expected '$want_kind $want_version')"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "FAIL parse '$tag' exited non-zero (expected '$want_kind $want_version')"
        FAIL=$((FAIL + 1))
    fi
}

assert_reject() {
    # assert_reject <tag> — must exit non-zero without output kind/version.
    local tag="$1"
    if parse_release_tag "$tag" catalog.json >/dev/null 2>&1; then
        echo "FAIL reject '$tag' — parser accepted an unknown kind"
        FAIL=$((FAIL + 1))
    else
        echo "ok   reject '$tag'"
        PASS=$((PASS + 1))
    fi
}

echo "== positive cases (real catalog.json, read-only) =="
assert_parse "python-3.11.10"              "python" "3.11.10"
assert_parse "ffmpeg-128263-g9f9b9548583"  "ffmpeg" "128263-g9f9b9548583"

echo "== negative cases (real catalog) =="
assert_reject "nosuchkind-1.0"
assert_reject "ffmpeg"                # kind without '-<version>'
assert_reject "ffmpeg-"               # empty version

echo "== edge cases (temp fixture, kind prefix of another kind) =="
FIXTURE="$(mktemp -d /tmp/fluixa-release-parse.XXXXXX)"
trap 'rm -rf "$FIXTURE"' EXIT
# 'ff' is a PREFIX of 'ffmpeg' — longest-match must win.
cat > "$FIXTURE/catalog.json" <<'EOF'
{"spec_version": 1, "entries": [
  {"kind": "ff", "version": "1.0", "platform": "darwin", "arch": "x86_64",
   "size": 1, "sha256": "aa", "urls": ["https://example.invalid/ff.zip"], "entrypoints": {}},
  {"kind": "ffmpeg", "version": "2.0-rc1-x", "platform": "darwin", "arch": "x86_64",
   "size": 2, "sha256": "bb", "urls": ["https://example.invalid/ffmpeg.zip"], "entrypoints": {}}
]}
EOF
GOT="$(parse_release_tag "ffmpeg-2.0-rc1-x" "$FIXTURE/catalog.json")"
if [ "$GOT" = "ffmpeg 2.0-rc1-x" ]; then
    echo "ok   longest-prefix wins over 'ff' (→ '$GOT')"
    PASS=$((PASS + 1))
else
    echo "FAIL longest-prefix: got '$GOT'"
    FAIL=$((FAIL + 1))
fi
GOT="$(parse_release_tag "ff-1.0" "$FIXTURE/catalog.json")"
if [ "$GOT" = "ff 1.0" ]; then
    echo "ok   short kind still matches exactly (→ '$GOT')"
    PASS=$((PASS + 1))
else
    echo "FAIL short kind: got '$GOT'"
    FAIL=$((FAIL + 1))
fi

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]

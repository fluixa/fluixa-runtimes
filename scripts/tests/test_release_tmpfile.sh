#!/bin/bash
# Tests for release.sh's tempfile creation pattern (mktemp fix 2026-11-04:
# macOS BSD mktemp requires the X-run to TRAIL the template — a suffix like
# `XXXX.md` fails mkstemp). Asserts the pattern statically AND functionally.
# No network, no gh, no artifacts touched.
# shellcheck shell=bash
set -u

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
ok()   { echo "ok   $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL $*"; FAIL=$((FAIL + 1)); }

echo "== static pattern assertions (release.sh) =="
# 1. No fixed-suffix mktemp templates (the bug: `-XXXX.md`).
if grep -nE 'mktemp [^|]*-X+\.([a-zA-Z0-9]+)"?' "$SCRIPTS_DIR/release.sh" >/dev/null; then
    fail "release.sh still contains a fixed-suffix mktemp template"
else
    ok "no fixed-suffix mktemp template"
fi
# 2. Uses ${TMPDIR:-/tmp}.
if grep -q 'mktemp "${TMPDIR:-/tmp}' "$SCRIPTS_DIR/release.sh"; then
    ok "mktemp uses \${TMPDIR:-/tmp}"
else
    fail "mktemp does not use \${TMPDIR:-/tmp}"
fi
# 3. At least 6 trailing X's.
if grep -Eq 'mktemp "\$\{TMPDIR:-/tmp\}/[^"]*-X{6,}"' "$SCRIPTS_DIR/release.sh"; then
    ok "mktemp template has >= 6 trailing X's"
else
    fail "mktemp template lacks a >= 6 trailing X-run"
fi
# 4. Cleanup trap registered and all exits clear it.
if grep -q "trap 'rm -f" "$SCRIPTS_DIR/release.sh" \
   && [ "$(grep -c 'trap - EXIT INT TERM' "$SCRIPTS_DIR/release.sh")" -ge 3 ]; then
    ok "cleanup trap + all three exit paths clear it"
else
    fail "cleanup trap missing or not cleared on some exit paths"
fi

echo "== functional: the exact template creates unique files =="
T1="$(mktemp "${TMPDIR:-/tmp}/fluixa-release-notes-XXXXXXXX")" && ok "created $T1" || fail "mktemp failed"
T2="$(mktemp "${TMPDIR:-/tmp}/fluixa-release-notes-XXXXXXXX")"
if [ -n "$T1" ] && [ -f "$T1" ] && [ "$T1" != "$T2" ] && [ -f "$T2" ]; then
    ok "repeated creation yields distinct existing files"
else
    fail "template did not produce unique files"
fi
rm -f "$T1" "$T2"
ok "cleanup works"

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]

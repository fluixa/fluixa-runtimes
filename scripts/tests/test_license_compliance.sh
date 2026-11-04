#!/bin/bash
# Tests for scripts/check-license-compliance.sh — license compliance STATES.
# Runs the real script against the real repo (positive path) and against
# tiny sandbox trees (negative paths: tampered bytes, missing materials,
# open review items). shellcheck shell=bash
set -u

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$SCRIPTS_DIR/.."

PASS=0
FAIL=0
ok()   { echo "ok   $*"; PASS=$((PASS + 1)); }
fail() { echo "FAIL $*"; FAIL=$((FAIL + 1)); }

run_check() { # <root> → sets GOT/EXIT
    GOT="$(FLUIXA_LICENSE_ROOT="$1" bash "$SCRIPTS_DIR/check-license-compliance.sh" 2>&1)"
    EXIT=$?
}

# ------------------------------------------------------------
# 1. Real repo: no FAIL, no BLOCKED; review-required expected
#    (documented LEGAL_REVIEW_REQUIRED items must stay open).
# ------------------------------------------------------------
run_check "$ROOT"
CASE="real repo passes without fail/blocked"
if [ "$EXIT" -eq 0 ] && ! printf '%s' "$GOT" | grep -q "^FAIL\|^BLKD"; then
    ok "$CASE"
else
    fail "$CASE — exit=$EXIT\n$GOT"
fi
CASE="real repo reports review-required items"
if printf '%s' "$GOT" | grep -q "REVW \[ffmpeg\] LEGAL_REVIEW_REQUIRED"; then
    ok "$CASE (ffmpeg x264/x265 + patent items open)"
else
    fail "$CASE — review items must NOT be silently closed\n$GOT"
fi

# ------------------------------------------------------------
# Sandbox helpers
# ------------------------------------------------------------
mk_sandbox() { # <tag>
    local sb
    sb="$(mktemp -d "${TMPDIR:-/tmp}/lic-check-XXXXXX")"
    mkdir -p "$sb/licenses/ffmpeg"
    printf 'dummy\n' > "$sb/licenses/ffmpeg/LICENSE.txt"
    printf 'hello-asset\n' > "$sb/assets-fixture"
    cat > "$sb/catalog.json" <<'EOC'
{"spec_version": 1, "entries": []}
EOC
    cat > "$sb/licenses/manifest.json" <<EOF
{
  "spec_version": 1,
  "resources": [{
    "id": "fixture",
    "class": "media-tools",
    "version": "1.0",
    "sha256": "$(shasum -a 256 "$sb/assets-fixture" | cut -d' ' -f1)",
    "license_text": "licenses/ffmpeg/LICENSE.txt",
    "build_params": null,
    "distributed_as": "assets-fixture",
    "source_artifacts": [],
    "review_items": []
  }]
}
EOF
    echo "$sb"
}

# 2. Clean sandbox: pass, no review.
SB="$(mk_sandbox)"
run_check "$SB"
CASE="sandbox clean pass"
if [ "$EXIT" -eq 0 ] && printf '%s' "$GOT" | grep -q "0 fail, 0 blocked, 0 review-required"; then
    ok "$CASE"
else
    fail "$CASE — exit=$EXIT\n$GOT"
fi
rm -rf "$SB"

# 3. Tampered bytes → FAIL + exit 1.
SB="$(mk_sandbox)"
printf 'tampered\n' >> "$SB/assets-fixture"
run_check "$SB"
CASE="tampered artifact detected"
if [ "$EXIT" -eq 1 ] && printf '%s' "$GOT" | grep -q "sha256 MISMATCH"; then
    ok "$CASE"
else
    fail "$CASE — exit=$EXIT\n$GOT"
fi
rm -rf "$SB"

# 4. Missing license text → BLOCKED + exit 1.
SB="$(mk_sandbox)"
rm "$SB/licenses/ffmpeg/LICENSE.txt"
run_check "$SB"
CASE="missing license text blocked"
if [ "$EXIT" -eq 1 ] && printf '%s' "$GOT" | grep -q "BLKD \[fixture\] license text missing"; then
    ok "$CASE"
else
    fail "$CASE — exit=$EXIT\n$GOT"
fi
rm -rf "$SB"

# 5. Open review items → REVW, exit still 0 (review is not a gate failure).
SB="$(mk_sandbox)"
python3 - "$SB/licenses/manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p))
m["resources"][0]["review_items"] = ["patent review pending"]
json.dump(m, open(p, "w"))
PY
run_check "$SB"
CASE="review items reported without failing the gate"
if [ "$EXIT" -eq 0 ] && printf '%s' "$GOT" | grep -q "REVW \[fixture\] LEGAL_REVIEW_REQUIRED: patent review pending"; then
    ok "$CASE"
else
    fail "$CASE — exit=$EXIT\n$GOT"
fi
rm -rf "$SB"

# 6. Catalog entry missing from manifest → BLOCKED.
SB="$(mk_sandbox)"
cp "$ROOT/catalog.json" "$SB/catalog.json"
run_check "$SB"
CASE="catalog entry without manifest entry blocked"
if [ "$EXIT" -eq 1 ] && printf '%s' "$GOT" | grep -q "has NO licenses/manifest.json entry"; then
    ok "$CASE"
else
    fail "$CASE — exit=$EXIT\n$GOT"
fi
rm -rf "$SB"

echo "----------------------------------------"
echo "license-compliance tests: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]

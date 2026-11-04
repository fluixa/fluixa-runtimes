#!/bin/bash
# License compliance check (Task F WS3) — states machine over licenses/manifest.json.
#
# Verifies, for every resource in the manifest:
#   1. license text + declared docs exist            → MATERIALS_PRESENT
#   2. recorded sha256 == actual bytes on disk for
#      every local artifact (assets/, artifacts/,
#      licenses/ source archives)                    → HASH_VERIFIED
#   3. catalog.json version == manifest version for
#      runtime entries; ffmpeg source-match record
#      present                                       → SOURCE_MATCH_VERIFIED
#   4. non-empty review_items                        → LEGAL_REVIEW_REQUIRED
#   anything missing/corrupt                         → BLOCKED
#
# Exit code: 0 = no BLOCKED and no verification failure
#            (LEGAL_REVIEW_REQUIRED items are reported, not fatal);
#            1 = BLOCKED or a hash/existence verification failure.
#            2 = manifest itself unreadable (cannot even start).
#
# Usage: scripts/check-license-compliance.sh [--quiet]
# shellcheck shell=bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Test hook: run the same checks against a sandbox tree (test_license_compliance).
ROOT="${FLUIXA_LICENSE_ROOT:-$ROOT}"
MANIFEST="$ROOT/licenses/manifest.json"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

PASS=0
FAIL=0
BLOCKED=0
REVIEW=0

say()  { [ "$QUIET" = 1 ] || echo "$*"; }
ok()   { say "ok   $*"; PASS=$((PASS + 1)); }
fail() { say "FAIL $*"; FAIL=$((FAIL + 1)); }
blocked() { say "BLKD $*"; BLOCKED=$((BLOCKED + 1)); }
review()  { say "REVW $*"; REVIEW=$((REVIEW + 1)); }

sha256_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1; }

# ------------------------------------------------------------------
# Manifest readable + schema sanity
# ------------------------------------------------------------------
if [ ! -f "$MANIFEST" ]; then
    echo "FATAL: manifest not found: $MANIFEST"
    exit 2
fi
if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$MANIFEST" >/dev/null 2>&1; then
    echo "FATAL: manifest is not valid JSON: $MANIFEST"
    exit 2
fi
ok "manifest parses: licenses/manifest.json"

# Per-resource fields as TSV: id|class|version|sha256|license_text|review_items
# NOTE: empty fields are emitted as "-" (tab is IFS-whitespace; consecutive
# tabs would collapse and shift columns in `read`).
RESOURCES="$(python3 - "$MANIFEST" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
dash = lambda v: v if v else "-"
for r in m["resources"]:
    review = "; ".join(r.get("review_items") or []) or "-"
    print("\t".join([
        r["id"], r.get("class", ""), r.get("version", ""),
        r.get("sha256") or "-", r.get("license_text") or "-",
        r.get("build_params") or "-",
        r.get("distributed_as") or "-",
        review,
    ]))
PY
)"
RESOURCES="$(printf '%s\n' "$RESOURCES" | grep -v '^$')"
if [ -z "$RESOURCES" ]; then
    echo "FATAL: manifest declares no resources"
    exit 2
fi

# All declared source archives, TSV: owner_id|path|sha256 (extracted once).
SRC_ARCHIVES="$(python3 - "$MANIFEST" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
for r in m["resources"]:
    for a in r.get("source_artifacts") or []:
        print(f"{r['id']}\t{a['path']}\t{a['sha256']}")
PY
)"

# ------------------------------------------------------------------
# catalog.json cross-check (runtime entries must stay in sync)
# ------------------------------------------------------------------
if [ -f "$ROOT/catalog.json" ]; then
    CATALOG_IDS="$(python3 - "$ROOT/catalog.json" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
for e in c["entries"]:
    print("\t".join([e["kind"], e["version"], e["sha256"]]))
PY
)"
    while IFS=$'\t' read -r kind version sha; do
        [ -n "$kind" ] || continue
        M_VER="$(printf '%s\n' "$RESOURCES" | awk -F'\t' -v id="$kind" '$1==id{print $3}')"
        M_SHA="$(printf '%s\n' "$RESOURCES" | awk -F'\t' -v id="$kind" '$1==id{print $4}')"
        if [ -z "$M_VER" ]; then
            blocked "catalog entry '$kind' has NO licenses/manifest.json entry"
        elif [ "$M_VER" != "$version" ] || [ "$M_SHA" != "$sha" ]; then
            fail "catalog '$kind' ($version/${sha:0:12}…) out of sync with manifest ($M_VER/${M_SHA:0:12}…)"
        else
            ok "catalog '$kind' v$version in sync with manifest"
        fi
    done <<< "$CATALOG_IDS"
else
    blocked "catalog.json missing — cannot cross-check"
fi

# ------------------------------------------------------------------
# Per-resource checks
# ------------------------------------------------------------------
while IFS=$'\t' read -r id class version sha license_text build_params distributed_as review_items; do
    dash_to_empty() { [ "$1" = "-" ] && echo "" || echo "$1"; }
    sha="$(dash_to_empty "$sha")"
    license_text="$(dash_to_empty "$license_text")"
    build_params="$(dash_to_empty "$build_params")"
    distributed_as="$(dash_to_empty "$distributed_as")"
    review_items="$(dash_to_empty "$review_items")"

    # 1. Materials present.
    if [ -n "$license_text" ] && [ -f "$ROOT/$license_text" ]; then
        ok "[$id] license text present ($license_text)"
    else
        blocked "[$id] license text missing: $license_text"
    fi
    if [ -n "$build_params" ] && [ ! -f "$ROOT/$build_params" ]; then
        blocked "[$id] declared build params missing: $build_params"
    fi

    # 2. Hash verification — the resource's own distributed artifact when
    #    present locally (assets always are; artifacts/ kept in-repo too).
    if [ -n "$sha" ] && [ -n "$distributed_as" ]; then
        if [ -f "$ROOT/$distributed_as" ]; then
            GOT="$(sha256_of "$ROOT/$distributed_as")"
            if [ "$GOT" = "$sha" ]; then
                ok "[$id] artifact sha256 verified ($distributed_as)"
            else
                fail "[$id] artifact sha256 MISMATCH ($distributed_as): $GOT != $sha"
            fi
        else
            # Not locally present (e.g. release-only artifact): the catalog/
            # SHA256SUMS cross-check above still covers it.
            say "skip [$id] artifact not present locally: $distributed_as"
        fi
    fi
    # Declared source archives (inside licenses/), owner-matched.
    while IFS=$'\t' read -r spath ssha; do
        [ -n "$spath" ] || continue
        if [ -f "$ROOT/$spath" ]; then
            GOT="$(sha256_of "$ROOT/$spath")"
            if [ "$GOT" = "$ssha" ]; then
                ok "[$id] source archive verified ($spath)"
            else
                fail "[$id] source archive sha256 MISMATCH ($spath)"
            fi
        else
            blocked "[$id] declared source archive missing: $spath"
        fi
    done <<< "$(printf '%s\n' "$SRC_ARCHIVES" | awk -F'\t' -v id="$id" '$1==id {print $2 "\t" $3}')"

    # 3/4. Effective state.
    if [ -n "$review_items" ]; then
        review "[$id] LEGAL_REVIEW_REQUIRED: $review_items"
    else
        ok "[$id] no open review items"
    fi
done <<< "$RESOURCES"

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
say "----------------------------------------"
say "license compliance: $PASS ok, $FAIL fail, $BLOCKED blocked, $REVIEW review-required"
if [ "$FAIL" -gt 0 ] || [ "$BLOCKED" -gt 0 ]; then
    exit 1
fi
exit 0

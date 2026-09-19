#!/usr/bin/env bash
# release.sh — publish runtime artifacts as GitHub Release (draft) + Gitee mirror
# checklist. Git-tree hygiene: artifacts are Release assets, never committed.
#
# Usage:
#   scripts/release.sh <tag>        # tag = <kind>-<version>, e.g. python-3.11.10
#
# Prerequisites:
#   - gh CLI installed + authenticated (github.com)
#   - artifacts/ populated locally: python3 scripts/verify_catalog.py --fetch
#
# Gitee mirroring is manual (web UI or API) — see docs/release.md §Gitee.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:?usage: release.sh <tag>  (e.g. python-3.11.10)}"
cd "$ROOT"

echo "==> 1/4 verify catalog (release gate)"
python3 scripts/verify_catalog.py --upstream --expect "${TAG%-*}@${TAG#*-}:darwin-x86_64"

echo "==> 2/4 collect release assets for $TAG"
KIND="${TAG%-*}"; VERSION="${TAG#*-}"
ASSET_FILES=""
while IFS= read -r e; do
    KIND_V="$(printf '%s' "$e" | python3 -c 'import json,sys; e=json.load(sys.stdin); print(e["kind"], e["version"])')"
    [ "$KIND_V" = "$KIND $VERSION" ] || continue
    A="$(printf '%s' "$e" | python3 -c 'import json,sys,os; e=json.load(sys.stdin); print(os.path.basename(e["urls"][0].split("?")[0].split("#")[0]))')"
    F="artifacts/$KIND/$VERSION/$A"
    [ -f "$F" ] || { echo "ERROR: missing local artifact $F (run verify_catalog.py --fetch)" >&2; exit 1; }
    ASSET_FILES="$ASSET_FILES $F"
done <<EOF
$(python3 -c 'import json; [print(json.dumps(e)) for e in json.load(open("catalog.json"))["entries"]]')
EOF
for A in assets/*; do
    [ -f "$A" ] && ASSET_FILES="$ASSET_FILES $A"
done
echo "    assets:$ASSET_FILES"
[ -n "$ASSET_FILES" ] || { echo "ERROR: no assets for tag $TAG" >&2; exit 1; }

echo "==> 3/4 checksums"
python3 scripts/gen_catalog.py

echo "==> 4/4 GitHub draft release"
command -v gh >/dev/null 2>&1 || {
    echo "gh CLI not found — create the release manually:"
    echo "  repo: fluixa-project/fluixa-runtimes  tag: $TAG"
    echo "  assets:$ASSET_FILES"
    exit 2
}
NOTES="$(mktemp /tmp/fluixa-release-XXXX.md)"
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
    echo "Origin: python-build-standalone $TAG release (upstream SHA256SUMS cross-checked)."
} > "$NOTES"
gh release create "$TAG" --draft --title "Runtime $TAG" --notes-file "$NOTES" $ASSET_FILES
rm -f "$NOTES"
echo ""
echo "Published (draft). After review: publish the release, then mirror to Gitee:"
echo "  1. Gitee repo fluixa-project/fluixa-runtimes → 发行版 → 新建 $TAG"
echo "  2. upload the SAME files (bytes must be identical; SHA-256 enforced downstream)"
echo "  3. verify mirrors: python3 scripts/verify_catalog.py --check-urls"

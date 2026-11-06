#!/bin/bash
# Release tag parsing — shared by release.sh and its tests.
#
# A release tag is "<kind>-<version>". Kinds are read from catalog.json
# (single source of truth) and matched by the LONGEST "<kind>-" prefix, so
# versions containing hyphens survive intact:
#   python-3.11.10                    → python / 3.11.10
#   ffmpeg-128263-g9f9b9548583-lgpl   → ffmpeg / 128263-g9f9b9548583-lgpl
# Never use ${TAG%-*}/${TAG#*-} — they split on ANY hyphen and corrupt
# hyphenated versions (fixed 2026-11-03).
#
# parse_release_tag <tag> [catalog.json] — echoes "<kind> <version>",
# exit 1 when no catalog kind matches (caller must abort).

parse_release_tag() {
    local tag="$1"
    local catalog="${2:-catalog.json}"
    python3 - "$tag" "$catalog" <<'PYEOF'
import json, sys

tag, catalog = sys.argv[1], sys.argv[2]
try:
    entries = json.load(open(catalog))["entries"]
except (OSError, ValueError, KeyError) as exc:
    print(f"release-tag: catalog unreadable: {exc}", file=sys.stderr)
    sys.exit(2)

kinds = sorted({e["kind"] for e in entries}, key=len, reverse=True)
for kind in kinds:
    if tag.startswith(kind + "-") and len(tag) > len(kind) + 1:
        print(kind, tag[len(kind) + 1:])
        sys.exit(0)

print(
    f"release-tag: tag '{tag}' does not match any catalog kind "
    f"({', '.join(kinds)}) — refusing to guess",
    file=sys.stderr,
)
sys.exit(1)
PYEOF
}

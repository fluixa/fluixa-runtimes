#!/bin/bash
# Release asset classification — shared by release.sh and its tests.
#
# A Release must contain ONLY the assets of its own class:
#   python-<version>   → artifacts/python/<version>/*   (runtime artifact)
#   ffmpeg-<version>   → artifacts/ffmpeg/<version>/*   (ffmpeg+ffprobe pair)
#   shared-assets      → assets/cacert.pem              (CA bundle only)
#   media-tools        → assets/yt-dlp-zipimport        (media tool only)
#
# Rationale (2026-11-03 fix): the old `for A in assets/*` loop attached
# cacert.pem AND yt-dlp-zipimport to EVERY runtime release. They are NOT
# runtime resources: the installer consumes them via the app-bundled
# provision_assets (apps/desktop/src/runtime_provision.rs) — never from
# Release downloads — and yt-dlp-zipimport is a standalone tool resource,
# not part of the python runtime.
#
# collect_release_assets <kind> <version> <catalog> <runtimes-root> —
# echoes repo-relative asset paths (space-separated on one line), exit 1
# when a required file is missing.

collect_release_assets() {
    local kind="$1" version="$2" catalog="$3" root="$4"
    local files=""

    case "$kind" in
        python|ffmpeg)
            local entries
            entries="$(python3 -c "
import json
for e in json.load(open('$catalog'))['entries']:
    if e['kind'] == '$kind' and e['version'] == '$version':
        print(e['urls'][0].split('?')[0].split('#')[0])
")"
            if [ -z "$entries" ]; then
                echo "release-assets: no catalog entry for $kind@$version" >&2
                return 1
            fi
            local url
            while IFS= read -r url; do
                local name="artifacts/$kind/$version/$(basename "$url")"
                if [ ! -f "$root/$name" ]; then
                    echo "release-assets: missing local artifact $root/$name (run verify_catalog.py --fetch)" >&2
                    return 1
                fi
                files="$files $name"
            done <<< "$entries"
            ;;
        shared-assets)
            files=" assets/cacert.pem"
            ;;
        media-tools)
            files=" assets/yt-dlp-zipimport"
            ;;
        *)
            echo "release-assets: unknown release class '$kind'" >&2
            return 1
            ;;
    esac

    # Existence check for the fixed-asset classes too.
    local f
    for f in $files; do
        if [ ! -f "$root/$f" ]; then
            echo "release-assets: missing asset $root/$f" >&2
            return 1
        fi
    done

    echo "$files"
}

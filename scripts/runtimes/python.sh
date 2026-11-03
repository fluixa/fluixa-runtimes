#!/bin/bash
# Fluixa Runtime Builder — python module (THIN integration).
#
# The python runtime is an UPSTREAM PASSTHROUGH artifact
# (astral-sh/python-build-standalone 20241016 → cpython tar.gz) already
# published and end-to-end verified; its extras (yt-dlp-zipimport,
# cacert.pem) are layered by the main app's installer at provision time.
# Deliberately NOT re-implemented here (incremental migration rule).
#
# Modes:
#   local-verify  run scripts/verify_catalog.py (offline gate) and assert
#                 the local python artifacts match catalog + SHA256SUMS.
#   build         NOT IMPLEMENTED — python artifacts are upstream
#                 passthroughs refreshed by re-downloading the pinned
#                 upstream release; when a new python version is adopted,
#                 extend this module then.
# shellcheck shell=bash

frt_python_dispatch() {
    case "${PYTHON_MODE:-}" in
        local-verify)
            frt_info "python: running offline catalog verification (existing artifacts)..."
            (cd "$RUNTIMES_DIR" && python3 scripts/verify_catalog.py)
            ;;
        build)
            frt_error "python: build mode is not implemented — python artifacts"
            frt_error "are upstream passthroughs. Extend this module only when"
            frt_error "a new python version is deliberately adopted."
            exit 1
            ;;
        *)
            frt_error "python: unknown mode '${PYTHON_MODE:-}' (expected local-verify)."
            exit 1
            ;;
    esac
}

frt_python_dispatch

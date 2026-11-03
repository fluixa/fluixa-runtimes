#!/bin/bash
# Fluixa Runtime Builder — common helpers (logging, temp dirs, proxy curl).
# Sourced by fetch-runtime.sh and runtimes/*.sh. All identifiers prefixed
# FRT_ to avoid collisions.

FRT_LOG_PREFIX="[runtime-builder]"

frt_info()  { echo "$FRT_LOG_PREFIX [INFO] $*"; }
frt_ok()    { echo "$FRT_LOG_PREFIX [OK] $*"; }
frt_warn()  { echo "$FRT_LOG_PREFIX [WARN] $*" >&2; }
frt_error() { echo "$FRT_LOG_PREFIX [ERROR] $*" >&2; }

# Exit code conventions (fetch-tools.sh v2 heritage):
#   0 success; 1 validation/environment failure; 2 BLOCKED (upstream
#   unavailable / unsupported platform — NEVER fabricate artifacts).
frt_exit_blocked() { frt_error "$*"; exit 2; }
frt_exit_fail()    { frt_error "$*"; exit 1; }

# frt_make_workdir — create an isolated temp work dir, echo its path.
# Caller registers cleanup via `trap 'rm -rf "$WORK"' EXIT`.
frt_make_workdir() {
    mktemp -d /tmp/fluixa-runtime-builder.XXXXXX
}

# frt_curl <output> <url> [max-time] — proxy-aware download.
# Uses $FRT_PROXY (socks5h://… or http://…) when set.
frt_curl() {
    local out="$1" url="$2" maxtime="${3:-300}"
    local args=(--location --fail --show-error --connect-timeout 15
                --max-time "$maxtime" --retry 3 --retry-delay 2
                --output "$out" "$url")
    if [ -n "${FRT_PROXY:-}" ]; then
        frt_info "Using proxy: $FRT_PROXY"
        curl "${args[@]}" --proxy "$FRT_PROXY"
    else
        curl "${args[@]}"
    fi
}

# frt_curl_status <url> — HEAD probe, echoes HTTP status (000 on failure).
frt_curl_status() {
    if [ -n "${FRT_PROXY:-}" ]; then
        curl -s -o /dev/null -w "%{http_code}" --max-time 20 -I -L --proxy "$FRT_PROXY" "$1" || echo 000
    else
        curl -s -o /dev/null -w "%{http_code}" --max-time 20 -I -L "$1" || echo 000
    fi
}

# frt_require_commands <name>… — fail fast (exit 1) on missing tools.
frt_require_commands() {
    for name in "$@"; do
        if ! command -v "$name" >/dev/null 2>&1; then
            frt_exit_fail "Required command not found: $name"
        fi
    done
}

# frt_json_field <json-file> <python-expr over d> — python3 is required for
# JSON parsing (fail loudly rather than mis-parse with sed).
frt_json_field() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json,sys; d=json.load(open('$1')); print($2)"
    else
        frt_error "python3 is required for JSON parsing."
        return 1
    fi
}

#!/bin/bash
# Fluixa Runtime Builder — platform detection + per-runtime source matrix.
#
# Source matrix (each platform has an INDEPENDENT, audited source and its
# own verification info). Platforms WITHOUT an auditable, testable source
# are BLOCKED: exit 2, zero artifacts — never fabricate a binary.
#
#   ffmpeg / darwin-x86_64    evermeet.cx Info API (JSON: version + pinned
#                             URL + size + .sig; legacy get* endpoints 410)
#   ffmpeg / darwin-aarch64   BLOCKED — evermeet builds x86_64 only; native
#                             arm64 needs a source build (record buildconf +
#                             sha256) or a pinned third-party build with
#                             checksums
#   ffmpeg / windows-x86_64   PENDING — gyan.dev / BtbN GitHub builds publish
#                             SHA-256; zip packaging + Windows-specific
#                             validation not implemented yet
#   python  / darwin-x86_64   published (upstream passthrough artifact,
#                             astral-sh/python-build-standalone 20241016)

# frt_detect_platform — echo <os>-<arch> in repo conventions (darwin-x86_64,
# darwin-aarch64, windows-x86_64, linux-x86_64, linux-aarch64).
frt_detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os" in
        Darwin)
            case "$arch" in
                arm64)  echo "darwin-aarch64" ;;
                x86_64) echo "darwin-x86_64" ;;
                *)      return 1 ;;
            esac
            ;;
        Linux)
            case "$arch" in
                aarch64) echo "linux-aarch64" ;;
                x86_64)  echo "linux-x86_64" ;;
                *)       return 1 ;;
            esac
            ;;
        MINGW*|MSYS*|CYGWIN*)
            case "$arch" in
                x86_64) echo "windows-x86_64" ;;
                *)      return 1 ;;
            esac
            ;;
        *)
            return 1
            ;;
    esac
}

# frt_assert_runtime_platform <runtime-kind> <platform> — exit 2 (BLOCKED)
# when no audited source exists for the pair. Keep this matrix in sync with
# docs/ (README platform matrix + per-runtime audit docs).
frt_assert_runtime_platform() {
    local kind="$1" platform="$2"
    case "$kind:$platform" in
        ffmpeg:darwin-x86_64)
            return 0
            ;;
        ffmpeg:*)
            frt_exit_blocked "No audited ffmpeg+ffprobe source for $platform."
            ;;
        python:darwin-x86_64)
            return 0
            ;;
        python:*)
            frt_exit_blocked "No audited python source for $platform."
            ;;
        *)
            frt_exit_blocked "Unknown runtime kind: $kind"
            ;;
    esac
}

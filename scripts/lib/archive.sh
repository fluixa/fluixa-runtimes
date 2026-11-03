#!/bin/bash
# Fluixa Runtime Builder — archive extraction + binary location helpers.

# frt_extract_zip <zip> <dir> — macOS ditto-based zip extraction.
frt_extract_zip() {
    local zip="$1" dir="$2"
    mkdir -p "$dir"
    ditto -x -k "$zip" "$dir/"
}

# frt_extract_tar_gz <tar.gz> <dir>
frt_extract_tar_gz() {
    local tarball="$1" dir="$2"
    mkdir -p "$dir"
    tar -xzf "$tarball" -C "$dir"
}

# frt_locate_binary <dir> <name> — echo the binary path or fail (exit 2).
# Tries the common layouts first, then a recursive fallback (fetch-tools.sh
# v2 heritage — upstream archives vary between flat/ and bin/ layouts).
frt_locate_binary() {
    local dir="$1" name="$2"
    local source=""
    local candidate
    for candidate in "$dir/$name" "$dir/$name/$name" "$dir/bin/$name"; do
        if [ -f "$candidate" ]; then
            source="$candidate"
            break
        fi
    done
    if [ -z "$source" ]; then
        source="$(find "$dir" -type f -name "$name" -print | head -1)"
    fi
    if [ -z "$source" ]; then
        frt_error "$name binary not found after extraction:"
        find "$dir" -maxdepth 4 -type f -print >&2
        exit 2
    fi
    chmod 755 "$source"
    if [ ! -x "$source" ]; then
        frt_error "$name is not executable."
        exit 2
    fi
    echo "$source"
}

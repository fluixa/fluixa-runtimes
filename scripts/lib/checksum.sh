#!/bin/bash
# Fluixa Runtime Builder — checksum helpers.

# frt_sha256 <file> — echo the hex digest.
frt_sha256() {
    shasum -a 256 "$1" | awk '{print $1}'
}

# frt_file_size <file> — echo the byte size (macOS stat).
frt_file_size() {
    stat -f%z "$1"
}

# frt_verify_size <file> <expected-size> <label> — exact size check.
frt_verify_size() {
    local file="$1" expected="$2" label="$3"
    local actual
    actual="$(frt_file_size "$file")"
    if [ "$actual" != "$expected" ]; then
        frt_error "$label size mismatch: expected $expected, got $actual."
        return 1
    fi
    frt_ok "$label size verified ($actual bytes)."
}

# frt_verify_sha256 <file> <expected> <label> — exact digest check.
frt_verify_sha256() {
    local file="$1" expected="$2" label="$3"
    local actual
    actual="$(frt_sha256 "$file")"
    if [ "$actual" != "$expected" ]; then
        frt_error "$label sha256 mismatch:"
        frt_error "  expected: $expected"
        frt_error "  actual:   $actual"
        return 1
    fi
    frt_ok "$label sha256 verified."
}

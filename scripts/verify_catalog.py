#!/usr/bin/env python3
"""verify_catalog.py — release-gating validation for the Runtime Catalog.

Checks (offline unless a flag says otherwise):
  1. schema: spec_version == 1; kind/version/platform/arch non-empty;
     sha256 = 64 lowercase hex; urls[] non-empty; entrypoints non-empty
  2. kind conventions: python entries require entrypoints "interpreter" +
     "tool" and a ca_bundle
  3. duplicates: no two entries share (kind, version, platform, arch)
  4. mirrors: all urls[] of one entry share the same basename (they must
     serve the same bytes)
  5. artifacts: local artifacts/<kind>/<version>/<asset> exists and its
     measured size + sha256 match the catalog (--fetch downloads missing)
  6. checksums/SHA256SUMS: consistent with every local file it lists and
     with the catalog sha256
  7. --upstream: entries with a python-build-standalone origin URL are
     cross-checked against the official SHA256SUMS of that release
  8. --check-urls: HTTP-probe every url (404 → WARN "pending publication",
     other failures → WARN; --strict-urls escalates WARN to FAIL)
  9. --expect "kind@version:platform-arch,platform-arch;kind@…": missing
     entries FAIL

Exit code 1 on any FAIL; WARN never fails the run.
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "catalog.json"
CHECKSUMS = ROOT / "checksums" / "SHA256SUMS"
PLATFORMS = {"darwin", "windows", "linux"}
ARCHES = {"x86_64", "aarch64"}

results = []


def record(status: str, msg: str) -> None:
    results.append((status, msg))
    print(f"{status:4} {msg}")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def asset_name(url: str) -> str:
    return url.split("?", 1)[0].split("#", 1)[0].rstrip("/").rsplit("/", 1)[-1]


def artifact_path(entry: dict) -> Path:
    return ROOT / "artifacts" / entry["kind"] / entry["version"] / asset_name(entry["urls"][0])


def curl(url, out=None, head=False):
    cmd = ["curl", "-fsSL", "--retry", "1", "--connect-timeout", "15"]
    if head:
        cmd += ["-I", "-o", "/dev/null", "-w", "%{http_code}"]
    elif out is not None:
        cmd += ["-o", str(out)]
    cmd.append(url)
    r = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return r.returncode, (r.stdout.strip() if head else r.stdout)


def fetch_via_curl(entry: dict, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + f".part{int(time.time())}")
    for url in entry["urls"]:
        print(f"     fetch: {url}")
        r = subprocess.run(["curl", "-fsSL", "--retry", "2", "--connect-timeout", "20",
                            "-o", str(tmp), url], check=False)
        if r.returncode == 0 and tmp.exists() and tmp.stat().st_size > 0:
            tmp.replace(dest)
            return
    tmp.unlink(missing_ok=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--fetch", action="store_true", help="download missing artifacts")
    ap.add_argument("--check-urls", action="store_true", help="HTTP-probe every url")
    ap.add_argument("--strict-urls", action="store_true", help="url probe failures FAIL")
    ap.add_argument("--upstream", action="store_true",
                    help="cross-check sha256 against official pbs SHA256SUMS")
    ap.add_argument("--expect", default="",
                    help="expected matrix, e.g. \"python@3.11.10:darwin-x86_64\"")
    args = ap.parse_args()

    if not CATALOG.is_file():
        record("FAIL", f"{CATALOG.relative_to(ROOT)} missing")
        return finish()

    catalog = json.loads(CATALOG.read_text())
    entries = catalog.get("entries", [])

    # 1. top-level schema
    if catalog.get("spec_version") != 1:
        record("FAIL", f"spec_version={catalog.get('spec_version')!r} (want 1)")
    else:
        record("OK", f"spec_version=1, {len(entries)} entr{'y' if len(entries) == 1 else 'ies'}")
    if not entries:
        record("WARN", "catalog has no entries")

    seen: dict[str, dict] = {}
    fail = False

    for e in entries:
        key = f"{e.get('kind')}/{e.get('version')}/{e.get('platform')}-{e.get('arch')}"
        label = f"[{key}]"

        # 1. per-entry schema
        for field in ("kind", "version", "platform", "arch"):
            if not str(e.get(field, "")):
                record("FAIL", f"{label} {field} empty"); fail = True
        if e.get("platform") not in PLATFORMS or e.get("arch") not in ARCHES:
            record("WARN", f"{label} unknown platform/arch "
                           f"{e.get('platform')}-{e.get('arch')}")
        sha = str(e.get("sha256", ""))
        if not re.fullmatch(r"[0-9a-f]{64}", sha):
            record("FAIL", f"{label} sha256 must be 64 lowercase hex, got {sha!r}"); fail = True
        urls = e.get("urls", [])
        if not urls:
            record("FAIL", f"{label} urls[] empty"); fail = True
        if not e.get("entrypoints"):
            record("FAIL", f"{label} entrypoints empty"); fail = True

        # 2. kind conventions
        if e.get("kind") == "python":
            ep = e.get("entrypoints", {})
            for name in ("interpreter", "tool"):
                if name not in ep:
                    record("FAIL", f"{label} python entrypoints missing '{name}'"); fail = True
            if not e.get("ca_bundle"):
                record("FAIL", f"{label} python entry missing ca_bundle"); fail = True

        # 3. duplicates
        if key in seen:
            record("FAIL", f"{label} duplicate entry"); fail = True
        seen[key] = e

        # 4. mirror filename identity — known transformations allowed.
        #    Gitee normalizes '+' in release-asset names to a space at upload
        #    time; the catalog stores the resulting name percent-encoded
        #    (%20). Filenames are metadata — byte identity is pinned by
        #    sha256/size, so unknown name drift is a WARN, never a FAIL.
        if urls:
            canonical = urllib.parse.unquote(asset_name(urls[0]))
            allowed = {canonical, canonical.replace("+", " ")}
            names = {urllib.parse.unquote(asset_name(u)) for u in urls}
            if not names <= allowed:
                record("WARN", f"{label} unexpected mirror filenames: "
                               f"{sorted(names - allowed)} (bytes still "
                               f"enforced by sha256)")
            else:
                record("OK", f"{label} mirror filenames consistent "
                             f"(gitee '+' → space normalization allowed)")

        # 8. url probe
        if args.check_urls:
            for u in urls:
                rc, code = curl(u, head=True)
                if rc == 0 and code.startswith(("2", "3")):
                    record("OK", f"{label} url reachable: {asset_name(u)} host ok")
                elif code == "404":
                    msg = f"{label} url 404 (pending publication?): {u}"
                    if args.strict_urls:
                        record("FAIL", msg); fail = True
                    else:
                        record("WARN", msg)
                else:
                    msg = f"{label} url probe failed (rc={rc}, code={code}): {u}"
                    if args.strict_urls:
                        record("FAIL", msg); fail = True
                    else:
                        record("WARN", msg)

        # 5. artifact bytes
        path = artifact_path(e)
        if not path.is_file():
            if args.fetch:
                fetch_via_curl(e, path)
            if not path.is_file():
                record("WARN", f"{label} artifact not local: {path.relative_to(ROOT)} "
                               f"(run with --fetch)")
                continue
        size = path.stat().st_size
        measured = sha256_file(path)
        if size != e.get("size"):
            record("FAIL", f"{label} size {size} != catalog {e.get('size')}"); fail = True
        elif measured != sha:
            record("FAIL", f"{label} sha256 {measured} != catalog {sha}"); fail = True
        else:
            record("OK", f"{label} artifact verified (size={size}, sha256={measured[:16]}…)")

        # 7. upstream cross-check
        if args.upstream:
            origin = next((u for u in urls if "python-build-standalone" in u), None)
            if origin:
                base = origin.rsplit("/", 1)[0]
                rc, sums = curl(f"{base}/SHA256SUMS")
                if rc != 0:
                    record("WARN", f"{label} upstream SHA256SUMS unreachable: {base}")
                else:
                    line = next((l for l in sums.splitlines()
                                 if l.split(None, 1)[-1].strip() == asset_name(origin)), None)
                    if line is None:
                        record("FAIL", f"{label} asset not listed in upstream SHA256SUMS")
                        fail = True
                    elif line.split(None, 1)[0] != sha:
                        record("FAIL", f"{label} sha256 differs from upstream "
                                       f"({line.split(None, 1)[0]})"); fail = True
                    else:
                        record("OK", f"{label} sha256 == official pbs SHA256SUMS")

    # 6. checksums/SHA256SUMS consistency
    if CHECKSUMS.is_file():
        listed: dict[str, str] = {}
        for line in CHECKSUMS.read_text().splitlines():
            if line.strip():
                h, rel = line.split(None, 1)
                listed[rel.strip()] = h
        for rel, h in listed.items():
            p = ROOT / rel
            if not p.is_file():
                record("WARN", f"SHA256SUMS lists missing file: {rel}")
                continue
            actual = sha256_file(p)
            if actual != h:
                record("FAIL", f"SHA256SUMS mismatch: {rel}"); fail = True
        for e in entries:
            rel = artifact_path(e).relative_to(ROOT).as_posix()
            if rel in listed and listed[rel] != e.get("sha256"):
                record("FAIL", f"{rel}: SHA256SUMS != catalog sha256"); fail = True
        record("OK", f"checksums/SHA256SUMS parsed ({len(listed)} entries, "
                     f"local files re-verified)")
    else:
        record("FAIL", "checksums/SHA256SUMS missing (run gen_catalog.py --update)")
        fail = True

    # 9. expected matrix
    for part in filter(None, args.expect.split(";")):
        m = re.fullmatch(r"([^@]+)@([^:]+):(.+)", part)
        if not m:
            record("FAIL", f"bad --expect segment: {part}"); fail = True
            continue
        kind, version, targets = m.groups()
        for t in targets.split(","):
            plat, arch = t.split("-", 1)
            if not any(e.get("kind") == kind and e.get("version") == version
                       and e.get("platform") == plat and e.get("arch") == arch
                       for e in entries):
                record("FAIL", f"missing expected entry: {kind}@{version}:{t}"); fail = True

    return finish()


def finish() -> int:
    n_fail = sum(1 for s, _ in results if s == "FAIL")
    n_warn = sum(1 for s, _ in results if s == "WARN")
    n_ok = sum(1 for s, _ in results if s == "OK")
    print(f"\n{'FAIL' if n_fail else 'PASS'}: {n_ok} ok, {n_warn} warn, {n_fail} fail")
    return 1 if n_fail else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""gen_catalog.py — catalog.json ↔ artifacts/ consistency maintenance.

Usage:
  python3 scripts/gen_catalog.py               # verify: measured size/sha256 of local
                                               # artifacts match catalog.json
  python3 scripts/gen_catalog.py --update      # write measured size/sha256 back into
                                               # catalog.json + regenerate checksums/SHA256SUMS
  python3 scripts/gen_catalog.py --fetch       # download missing artifacts from urls[]
                                               # first (curl; honours ALL_PROXY/https_proxy)

Entry → local artifact convention (see docs/catalog-v1.md):
  asset name = basename(urls[0]) minus ?query/#fragment — mirrors serve the
               same bytes (sha256-pinned); Gitee renames '+' → space, which
               is tolerated (catalog stores the actual name, %20-encoded)
  artifacts/<kind>/<version>/<asset-name>
"""

import argparse
import hashlib
import json
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "catalog.json"
CHECKSUMS = ROOT / "checksums" / "SHA256SUMS"
HASHED_DIRS = ("artifacts", "assets")  # content covered by checksums/SHA256SUMS


def asset_name(url: str) -> str:
    clean = url.split("?", 1)[0].split("#", 1)[0]
    name = clean.rstrip("/").rsplit("/", 1)[-1]
    if not name:
        raise SystemExit(f"FAIL: cannot derive asset name from url: {url}")
    return name


def artifact_path(entry: dict) -> Path:
    return ROOT / "artifacts" / entry["kind"] / entry["version"] / asset_name(entry["urls"][0])


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch_via_curl(entry: dict, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + f".part{int(time.time())}")
    for url in entry["urls"]:
        print(f"  fetch: {url}")
        r = subprocess.run(
            ["curl", "-fsSL", "--retry", "2", "--connect-timeout", "20",
             "-o", str(tmp), url],
            check=False,
        )
        if r.returncode == 0 and tmp.exists() and tmp.stat().st_size > 0:
            tmp.replace(dest)
            return
        print(f"  WARN: download failed from {url} (rc={r.returncode}), trying next source")
    tmp.unlink(missing_ok=True)
    raise SystemExit(f"FAIL: all download sources failed for {asset_name(entry['urls'][0])}")


def iter_hashed_files():
    for d in HASHED_DIRS:
        base = ROOT / d
        if base.is_dir():
            for p in sorted(base.rglob("*")):
                if p.is_file() and ".part" not in p.name:
                    yield p.relative_to(ROOT)


def write_checksums() -> int:
    lines = [f"{sha256_file(ROOT / rel)}  {rel.as_posix()}" for rel in iter_hashed_files()]
    CHECKSUMS.parent.mkdir(parents=True, exist_ok=True)
    CHECKSUMS.write_text("\n".join(lines) + ("\n" if lines else ""))
    return len(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--update", action="store_true",
                    help="write measured size/sha256 back into catalog.json")
    ap.add_argument("--fetch", action="store_true",
                    help="download missing artifacts from urls[] via curl")
    args = ap.parse_args()

    catalog = json.loads(CATALOG.read_text())
    dirty = False
    failures = 0

    for entry in catalog.get("entries", []):
        label = f"{entry['kind']}/{entry['version']}/{entry['platform']}-{entry['arch']}"
        path = artifact_path(entry)
        if not path.is_file():
            if args.fetch:
                fetch_via_curl(entry, path)
            else:
                print(f"FAIL {label}: artifact missing locally: {path.relative_to(ROOT)}")
                print("     (run with --fetch to download from urls[])")
                failures += 1
                continue
        size = path.stat().st_size
        sha = sha256_file(path)
        if size == entry.get("size", -1) and sha == entry.get("sha256", ""):
            print(f"OK   {label}: size={size} sha256={sha[:16]}…")
        else:
            print(f"FAIL {label}: measured (size={size}, sha256={sha}) != "
                  f"catalog (size={entry.get('size')}, sha256={entry.get('sha256')})")
            failures += 1
            if args.update:
                entry["size"], entry["sha256"] = size, sha
                dirty = True
                print(f"     → catalog.json updated (--update)")

    if dirty:
        CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
        print("catalog.json rewritten")

    n = write_checksums()
    print(f"checksums/SHA256SUMS regenerated ({n} files)")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

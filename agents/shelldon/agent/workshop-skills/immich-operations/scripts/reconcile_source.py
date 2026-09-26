#!/usr/bin/env python3
"""Check whether local source files already exist in Immich.

Computes a SHA1 per file and calls POST /assets/bulk-upload-check, which is a
read-only query despite the POST method. Reports each file as ABSENT, PRESENT
or PRESENT_TRASHED, plus a filename-level hint for near-matches.

Verified response shape on v3.2.2: a byte-identical existing asset returns
{"action":"reject","reason":"duplicate","assetId":"<uuid>","isTrashed":false};
a file absent from the library returns {"action":"accept"}.

Use before any import: a checksum hit proves identical bytes, but album, date
and location metadata still need separate verification.

Usage:
    IMMICH_API_KEY=... python3 reconcile_source.py /path/to/album-dir
    IMMICH_API_KEY=... python3 reconcile_source.py --recursive --json /src
    IMMICH_API_KEY=... python3 reconcile_source.py --limit 500 /src

Exit codes: 0 success, 1 error, 2 missing key.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import ssl
import sys
import urllib.error
import urllib.request

DEFAULT_BASE = "https://immich.sieh.org/api"
TIMEOUT = 60
BATCH = 100
MEDIA_EXT = {
    ".jpg", ".jpeg", ".png", ".heic", ".heif", ".gif", ".webp", ".tif", ".tiff",
    ".dng", ".raw", ".cr2", ".cr3", ".nef", ".arw", ".orf", ".rw2", ".raf",
    ".mp4", ".mov", ".m4v", ".avi", ".mkv", ".3gp", ".insv", ".mts",
}
SKIP_NAMES = {".ds_store", "thumbs.db"}


def _sha1(path: str) -> str:
    h = hashlib.sha1()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _check_batch(base: str, key: str, items: list) -> list:
    payload = {"assets": [{"id": cid, "checksum": cs} for cid, cs in items]}
    req = urllib.request.Request(
        f"{base}/assets/bulk-upload-check",
        data=json.dumps(payload).encode("utf-8"),
        headers={"x-api-key": key, "Content-Type": "application/json",
                 "Accept": "application/json"},
        method="POST",
    )
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8")).get("results", [])


def _search_name(base: str, key: str, name: str) -> list:
    req = urllib.request.Request(
        f"{base}/search/metadata",
        data=json.dumps({"page": 1, "size": 5, "originalFileName": name,
                         "withDeleted": True}).encode("utf-8"),
        headers={"x-api-key": key, "Content-Type": "application/json",
                 "Accept": "application/json"},
        method="POST",
    )
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
        return (json.loads(resp.read().decode("utf-8")).get("assets") or {}).get("items", [])


def walk(root: str, recursive: bool) -> list:
    out: list = []
    if os.path.isfile(root):
        return [root]
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if name.lower() in SKIP_NAMES or not name.lower().endswith(tuple(MEDIA_EXT)):
                continue
            out.append(os.path.join(dirpath, name))
            if not recursive:
                continue
        if not recursive:
            break
    return sorted(out)


def main() -> int:
    ap = argparse.ArgumentParser(description="Reconcile local files against the Immich library.")
    ap.add_argument("source", help="file or directory to reconcile")
    ap.add_argument("--base", default=os.environ.get("IMMICH_SERVER", DEFAULT_BASE))
    ap.add_argument("--recursive", action="store_true", help="descend into subdirectories")
    ap.add_argument("--limit", type=int, default=500, help="max files to check (default 500)")
    ap.add_argument("--name-hint", action="store_true",
                    help="for absent files, also look for same-named assets (slower)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    key = os.environ.get("IMMICH_API_KEY", "").strip()
    if not key:
        print("IMMICH_API_KEY is not set in this environment.", file=sys.stderr)
        return 2
    if not os.path.exists(args.source):
        print(f"No such path: {args.source}", file=sys.stderr)
        return 1

    files = walk(args.source, args.recursive)[: args.limit]
    if not files:
        print(f"No media files found under {args.source}", file=sys.stderr)
        return 1

    results: list = []
    try:
        for start in range(0, len(files), BATCH):
            chunk = files[start:start + BATCH]
            digests = [(f"c{i}", _sha1(p)) for i, p in enumerate(chunk)]
            by_id = {cid: path for cid, path in zip([d[0] for d in digests], chunk)}
            for row in _check_batch(args.base, key, digests):
                path = by_id.get(row.get("id"), "")
                action = row.get("action", "")
                reason = row.get("reason", "")
                if action == "accept":
                    status = "ABSENT"
                elif action == "reject" and reason == "duplicate":
                    status = "PRESENT_TRASHED" if row.get("isTrashed") else "PRESENT"
                else:
                    status = f"{action or 'unknown'}_{reason}".upper() if reason \
                        else (action or "UNKNOWN").upper()
                results.append({
                    "path": path,
                    "filename": os.path.basename(path),
                    "status": status,
                    "assetId": row.get("assetId"),
                    "isTrashed": row.get("isTrashed"),
                })
            print(f"  checked {min(start + BATCH, len(files))}/{len(files)}", file=sys.stderr)

        if args.name_hint:
            for row in results:
                if row["status"] == "ABSENT" and not row["assetId"]:
                    hits = _search_name(args.base, key, row["filename"])
                    if hits:
                        row["nameHint"] = [
                            {"id": h.get("id"), "fileCreatedAt": h.get("fileCreatedAt"),
                             "isTrashed": h.get("isTrashed")} for h in hits
                        ]
    except urllib.error.HTTPError as exc:
        print(f"HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')[:200]}", file=sys.stderr)
        return 1
    except (urllib.error.URLError, ssl.SSLError, TimeoutError, OSError) as exc:
        print(f"Failed: {exc}", file=sys.stderr)
        return 1

    absent = [r for r in results if r["status"] == "ABSENT"]
    present = [r for r in results if r["status"] == "PRESENT"]
    trashed = [r for r in results if r["status"] == "PRESENT_TRASHED"]
    other = [r for r in results if r["status"] not in
             ("ABSENT", "PRESENT", "PRESENT_TRASHED")]

    if args.json:
        print(json.dumps({"checked": len(results), "present": len(present),
                          "presentTrashed": len(trashed), "absent": len(absent),
                          "other": len(other), "results": results}, indent=2))
        return 0

    print(f"\nchecked={len(results)} present={len(present)} "
          f"present_trashed={len(trashed)} absent={len(absent)} other={len(other)}")
    for row in other:
        print(f"  {row['status']:<24} {row['filename']}")
    for row in absent:
        hint = ""
        if row.get("nameHint"):
            hint = "  (same name exists: " + ",".join(
                f"{h['id'][:8]}{' TRASHED' if h['isTrashed'] else ''}" for h in row["nameHint"]) + ")"
        print(f"  ABSENT  {row['filename']}{hint}")
    if absent:
        print("\nOnly ABSENT files are import candidates. A checksum hit proves identical")
        print("bytes; album, date and location metadata still need separate verification.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

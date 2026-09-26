#!/usr/bin/env python3
"""Find possible duplicate assets by filename and capture time.

Read-only. A group is a candidate, not proof of identical bytes or metadata.
Trashed assets are excluded unless --with-trashed is given. Search pages are
followed to an empty page; assets.total is not a reliable library total on
the checked server version.

Exit codes: 0 no candidate groups, 3 candidates found, 1 error, 2 missing key.
"""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.request

DEFAULT_BASE = "https://immich.sieh.org/api"
TIMEOUT = 60
PAGE_SIZE = 250
MAX_PAGES = 400


def _search_page(base: str, key: str, page: int, with_deleted: bool) -> dict:
    payload: dict = {"page": page, "size": PAGE_SIZE}
    if with_deleted:
        payload["withDeleted"] = True
    req = urllib.request.Request(
        f"{base}/search/metadata",
        data=json.dumps(payload).encode("utf-8"),
        headers={"x-api-key": key, "Content-Type": "application/json",
                 "Accept": "application/json"},
        method="POST",
    )
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8"))


def collect(base: str, key: str, name: str | None, with_deleted: bool) -> tuple[list, int]:
    """Page until an empty page comes back.

    assets.total is the page size, not the library size, so it must never be
    used as a stop condition: trusting it truncates an unfiltered scan to one
    page and reports a false 'no duplicates found'.
    """
    items: list = []
    page = 1
    while page <= MAX_PAGES:
        payload_page = page
        if name:
            # filename-scoped: use the filter variant
            req_payload: dict = {"page": payload_page, "size": PAGE_SIZE,
                                 "originalFileName": name}
            if with_deleted:
                req_payload["withDeleted"] = True
            req = urllib.request.Request(
                f"{base}/search/metadata",
                data=json.dumps(req_payload).encode("utf-8"),
                headers={"x-api-key": key, "Content-Type": "application/json",
                         "Accept": "application/json"},
                method="POST",
            )
            ctx = ssl.create_default_context()
            with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
                res = json.loads(resp.read().decode("utf-8"))
        else:
            res = _search_page(base, key, payload_page, with_deleted)

        assets = res.get("assets") or {}
        batch = assets.get("items") or []
        if not batch:
            # assets.total echoes the page size; only an empty page ends paging.
            page -= 1
            break
        items.extend(batch)
        page += 1
    total = len(items)
    return items, total


def main() -> int:
    ap = argparse.ArgumentParser(description="Find duplicate candidates by filename and capture time.")
    ap.add_argument("--base", default=os.environ.get("IMMICH_SERVER", DEFAULT_BASE))
    ap.add_argument("--name", help="limit to one exact originalFileName")
    ap.add_argument("--with-trashed", action="store_true",
                    help="include trashed assets (default: live only)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    key = os.environ.get("IMMICH_API_KEY", "").strip()
    if not key:
        print("IMMICH_API_KEY is not set in this environment.", file=sys.stderr)
        return 2

    try:
        items, total = collect(args.base, key, args.name, args.with_trashed)
    except urllib.error.HTTPError as exc:
        print(f"HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')[:200]}", file=sys.stderr)
        return 1
    except (urllib.error.URLError, ssl.SSLError, TimeoutError) as exc:
        print(f"Cannot reach {args.base}: {exc}", file=sys.stderr)
        return 1

    groups: dict = {}
    for it in items:
        if it.get("isTrashed") and not args.with_trashed:
            continue
        fname = it.get("originalFileName")
        taken = it.get("fileCreatedAt")
        if not fname or not taken:
            continue
        groups.setdefault((fname, taken), []).append(it)

    dupes = {k: v for k, v in groups.items() if len(v) > 1}

    if args.json:
        print(json.dumps({
            "scanned": total,
            "candidateGroups": len(dupes),
            "groups": [
                {"originalFileName": k[0], "fileCreatedAt": k[1],
                 "count": len(v),
                 "assets": [{"id": a.get("id"), "isTrashed": a.get("isTrashed"),
                             "checksum": (a.get("checksum") or "")[:12]} for a in v]}
                for k, v in sorted(dupes.items())
            ],
        }, indent=2))
        return 3 if dupes else 0

    print(f"scanned={total} candidateGroups={len(dupes)}")
    for (fname, taken), rows in sorted(dupes.items()):
        print(f"\n{fname}  {taken}  x{len(rows)}")
        for a in rows:
            flag = " [trashed]" if a.get("isTrashed") else ""
            print(f"    id={a.get('id')}  checksum={(a.get('checksum') or '')[:12]}{flag}")
    if dupes:
        print("\nInspect each group before trashing. A checksum match proves identical")
        print("bytes only; albums, dates and locations still need checking.")
    return 3 if dupes else 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Paginated read-only Immich asset search with album and trash state.

Follow pages to the verified end; assets.total is not a reliable library total
on the checked server version. Album membership requires an asset/album query,
not the album listing alone.

Exit codes: 0 success, 1 unreachable/unauthorized, 2 missing credential.
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
TIMEOUT = 30
PAGE_SIZE = 250


def _post(base: str, path: str, key: str, payload: dict) -> dict:
    req = urllib.request.Request(
        f"{base}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "x-api-key": key,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _get(base: str, path: str, key: str):
    req = urllib.request.Request(
        f"{base}{path}",
        headers={"x-api-key": key, "Accept": "application/json"},
        method="GET",
    )
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _albums(base: str, key: str) -> dict:
    """Map assetId -> album names.

    Album listing rows do not include asset membership on the checked server
    version. Resolve membership by searching each album's assets.
    """
    raw = _get(base, "/albums?page=1&size=1000", key)
    rows = raw.get("albums", []) if isinstance(raw, dict) else raw
    mapping: dict = {}
    for album in rows or []:
        albid = album.get("id")
        name = album.get("albumName") or "?"
        if not albid:
            continue
        page = 1
        while True:
            res = _post(base, "/search/metadata", key,
                        {"albumIds": [albid], "page": page, "size": PAGE_SIZE})
            bucket = res.get("assets") or {}
            items = bucket.get("items") or []
            for it in items:
                aid = it.get("id")
                if aid:
                    mapping.setdefault(aid, []).append(name)
            # `total` is not the library count. Follow nextPage and cast its
            # string value to the numeric `page` required by the API.
            nxt = bucket.get("nextPage")
            if not items or not nxt:
                break
            page = int(nxt)
    return mapping


def search(base: str, key: str, args: argparse.Namespace):
    query: dict = {"page": 1, "size": PAGE_SIZE}
    if args.name:
        query["originalFileName"] = args.name
    if args.trashed:
        query["isTrashed"] = True
    elif args.with_trashed:
        query["withDeleted"] = True
    if args.since:
        query["takenAfter"] = args.since
    if args.before:
        query["takenBefore"] = args.before

    items: list = []
    page = 1
    while True:
        query["page"] = page
        res = _post(base, "/search/metadata", key, query)
        batch = (res.get("assets") or {}).get("items") or []
        if not batch:
            break
        items.extend(batch)
        page += 1
        if page > 200:  # hard stop; a library this large needs a narrower filter
            print("stopped at page 200; narrow the filter", file=sys.stderr)
            break
    total = len(items)

    album_map = _albums(base, key) if args.albums else {}
    return items, total, album_map


def main() -> int:
    ap = argparse.ArgumentParser(description="Paginated read-only Immich asset search.")
    ap.add_argument("--base", default=os.environ.get("IMMICH_SERVER", DEFAULT_BASE))
    ap.add_argument("--name", help="exact originalFileName")
    ap.add_argument("--since", help="ISO date/time, taken after (e.g. 2014-01-01)")
    ap.add_argument("--before", help="ISO date/time, taken before")
    ap.add_argument("--trashed", action="store_true", help="only trashed assets")
    ap.add_argument("--with-trashed", action="store_true", help="include trashed in results")
    ap.add_argument("--albums", action="store_true", help="resolve album names (extra call)")
    ap.add_argument("--limit", type=int, default=100, help="max rows to print (default 100)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    key = os.environ.get("IMMICH_API_KEY", "").strip()
    if not key:
        print("IMMICH_API_KEY is not set in this environment.", file=sys.stderr)
        return 2

    try:
        items, total, album_map = search(args.base, key, args)
    except urllib.error.HTTPError as exc:
        print(f"HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')[:200]}", file=sys.stderr)
        return 1
    except (urllib.error.URLError, ssl.SSLError, TimeoutError) as exc:
        print(f"Cannot reach {args.base}: {exc}", file=sys.stderr)
        return 1

    rows = []
    for it in items:
        rows.append({
            "id": it.get("id"),
            "originalFileName": it.get("originalFileName"),
            "fileCreatedAt": it.get("fileCreatedAt"),
            "isTrashed": it.get("isTrashed"),
            "albums": album_map.get(it.get("id"), []),
        })

    if args.json:
        print(json.dumps({"total": total, "returned": len(rows), "assets": rows}, indent=2))
        return 0

    print(f"total={total} returned={len(rows)}")
    for row in rows[: args.limit]:
        flag = " [trashed]" if row["isTrashed"] else ""
        alb = (" albums=" + ",".join(row["albums"])) if row["albums"] else " albums=<none>"
        print(f"  {row['originalFileName']}  {row['fileCreatedAt']}{flag}{alb}  id={row['id']}")
    if len(rows) > args.limit:
        print(f"  ... {len(rows) - args.limit} more (raise --limit or use --json)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

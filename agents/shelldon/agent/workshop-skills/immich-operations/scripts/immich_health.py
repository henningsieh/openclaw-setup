#!/usr/bin/env python3
"""Read-only Immich health, version, identity and key-permission report.

Reads IMMICH_API_KEY (and optionally IMMICH_ADMIN_API_KEY) from the
environment. Never prints, logs or persists a secret value.

Usage:
    IMMICH_API_KEY=... python3 immich_health.py
    IMMICH_API_KEY=... IMMICH_ADMIN_API_KEY=... python3 immich_health.py --json

Exit codes: 0 healthy, 1 unreachable/unauthorized, 2 missing credential.
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
TIMEOUT = 20


def _get(base: str, path: str, key: str) -> dict:
    req = urllib.request.Request(
        f"{base}{path}",
        headers={"x-api-key": key, "Accept": "application/json"},
        method="GET",
    )
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8"))


def probe(base: str, key: str) -> dict:
    """Collect the read-only bootstrap facts for one credential."""
    out: dict = {}
    ping = _get(base, "/server/ping", key)
    out["ping"] = ping.get("res")

    ver = _get(base, "/server/version", key)
    out["serverVersion"] = ".".join(
        str(ver.get(p)) for p in ("major", "minor", "patch") if ver.get(p) is not None
    )

    me = _get(base, "/users/me", key)
    out["account"] = {
        "email": me.get("email"),
        "isAdmin": me.get("isAdmin"),
        "status": me.get("status"),
    }

    keys = _get(base, "/api-keys/me", key)
    out["keyName"] = keys.get("name")
    out["keyPermissions"] = keys.get("permissions")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Read-only Immich health report.")
    ap.add_argument("--base", default=os.environ.get("IMMICH_SERVER", DEFAULT_BASE),
                    help="API base URL (default: $IMMICH_SERVER or %s)" % DEFAULT_BASE)
    ap.add_argument("--json", action="store_true", help="emit JSON")
    args = ap.parse_args()

    user_key = os.environ.get("IMMICH_API_KEY", "").strip()
    admin_key = os.environ.get("IMMICH_ADMIN_API_KEY", "").strip()
    if not user_key:
        print("IMMICH_API_KEY is not set in this environment.", file=sys.stderr)
        print("Load it from the native dotenv into the command environment; do not pass it as an argument.",
              file=sys.stderr)
        return 2

    try:
        report: dict = {"base": args.base, "user": probe(args.base, user_key)}
        if admin_key:
            report["admin"] = probe(args.base, admin_key)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")[:200]
        print(f"HTTP {exc.code} from {args.base}: {body}", file=sys.stderr)
        return 1
    except (urllib.error.URLError, ssl.SSLError, TimeoutError) as exc:
        print(f"Cannot reach {args.base}: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(report, indent=2))
        return 0

    print(f"origin      {report['base']}")
    print(f"ping        {report['user']['ping']}")
    print(f"server      v{report['user']['serverVersion']}")
    for role in ("user", "admin"):
        if role not in report:
            continue
        acct = report[role][ "account" ]
        who = "admin" if acct["isAdmin"] else "non-admin"
        print(f"{role:<11} {acct['email']} ({who}, {acct['status']}) key={report[role]['keyName']} "
              f"permissions={','.join(report[role]['keyPermissions'] or [])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Plan (and optionally apply) a date-anchored retention window for OpenClaw
backup archives in a destination directory.

Grandfather-father-son style: keep the newest N daily points, M weekly points and
K monthly points, where each coarser point is the newest archive in its period.

Default is a read-only plan. Deleting backups is authorized only after the owner
has reviewed that plan, so --apply is explicit and nothing is inferred from a
run's exit status.

Usage:
  retention_plan.py --dir /mnt/openclaw-backup
  retention_plan.py --dir /mnt/openclaw-backup --daily 14 --weekly 8 --monthly 6
  retention_plan.py --dir /mnt/openclaw-backup --json
  retention_plan.py --dir /mnt/openclaw-backup --apply      # after owner approval
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys

ARCHIVE_RE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})T(?P<h>\d{2})-(?P<m>\d{2})-(?P<s>\d{2})\."
    r"(?P<ms>\d+)(?P<off>[+-]\d{2}-\d{2})-openclaw-backup\.tar\.gz$"
)


def collect(directory: str) -> tuple[list[dict], list[dict]]:
    """Split the directory into parseable archives and unclassified entries."""
    archives: list[dict] = []
    unclassified: list[dict] = []
    for name in sorted(os.listdir(directory)):
        path = os.path.join(directory, name)
        if not os.path.isfile(path):
            unclassified.append({"name": name, "reason": "not a regular file"})
            continue
        m = ARCHIVE_RE.match(name)
        if not m:
            unclassified.append({"name": name, "reason": "not an OpenClaw archive name"})
            continue
        sign = -1 if m.group("off")[0] == "-" else 1
        off = dt.timedelta(
            hours=sign * int(m.group("off")[1:3]), minutes=sign * int(m.group("off")[4:6])
        )
        stamp = dt.datetime.fromisoformat(
            f"{m.group('date')}T{m.group('h')}:{m.group('m')}:{m.group('s')}+00:00"
        ) - off
        archives.append(
            {
                "name": name,
                "path": path,
                "stamp": stamp,
                "day": stamp.date(),
                "bytes": os.path.getsize(path),
            }
        )
    archives.sort(key=lambda a: a["stamp"])
    return archives, unclassified


def select(archives: list[dict], daily: int, weekly: int, monthly: int) -> dict[str, str]:
    """Return {archive name: reason} for every archive that survives.

    Each period contributes one anchor point: the newest archive of the day,
    then of the week, then of the month. A superseded same-day copy is never
    kept — the day's newest archive already restores that day — but such days
    are reported so the owner can see what went.

    Windows are anchored on the newest archive's day, not on wall-clock time, so
    re-running the planner is deterministic and a paused backup job cannot
    silently delete the whole history in one pass.
    """
    if not archives:
        return {}
    newest = archives[-1]["day"]
    newest_monday = newest - dt.timedelta(days=newest.weekday())

    reasons: dict[str, str] = {}
    seen_day: set = set()
    seen_week: set = set()
    seen_month: set = set()
    for a in reversed(archives):
        d = a["day"]
        monday = d - dt.timedelta(days=d.weekday())
        month = (d.year, d.month)
        if (newest - d).days < daily:
            seen_week.add(monday)
            seen_month.add(month)
            if d in seen_day:
                continue
            seen_day.add(d)
            reasons[a["name"]] = "daily"
            continue
        if monday not in seen_week and (newest_monday - monday).days // 7 < weekly:
            seen_week.add(monday)
            seen_month.add(month)
            reasons[a["name"]] = "weekly"
            continue
        if month not in seen_month and (newest.year - d.year) * 12 + (newest.month - d.month) < monthly:
            seen_month.add(month)
            reasons[a["name"]] = "monthly"
    return reasons


def report(archives, unclassified, reasons, args) -> dict:
    keep = [a for a in archives if a["name"] in reasons]
    drop = [a for a in archives if a["name"] not in reasons]
    days = {}
    for a in archives:
        days.setdefault(a["day"], []).append(a)
    dupes = {str(d): len(v) for d, v in sorted(days.items()) if len(v) > 1}
    out = {
        "directory": args.dir,
        "mode": "APPLY" if args.apply else "PLAN (read-only)",
        "window": {"daily": args.daily, "weekly": args.weekly, "monthly": args.monthly},
        "archives_total": len(archives),
        "keep_count": len(keep),
        "keep_gib": round(sum(a["bytes"] for a in keep) / 2**30, 2),
        "delete_count": len(drop),
        "delete_gib": round(sum(a["bytes"] for a in drop) / 2**30, 2),
        "oldest_kept": keep[0]["name"] if keep else None,
        "newest_kept": keep[-1]["name"] if keep else None,
        "newest_archive_day": str(archives[-1]["day"]) if archives else None,
        "latest_archive_age_days": (dt.date.today() - archives[-1]["day"]).days if archives else None,
        "days_with_multiple_archives": dupes,
        "unclassified_entries": unclassified,
        "delete": [{"name": a["name"], "gib": round(a["bytes"] / 2**30, 3)} for a in drop],
    }
    return out


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dir", required=True, help="backup destination directory")
    p.add_argument("--daily", type=int, default=14)
    p.add_argument("--weekly", type=int, default=8)
    p.add_argument("--monthly", type=int, default=6)
    p.add_argument("--json", action="store_true")
    p.add_argument("--apply", action="store_true", help="actually unlink the planned files")
    args = p.parse_args()

    if not os.path.isdir(args.dir):
        print(f"error: not a directory: {args.dir}", file=sys.stderr)
        return 2

    archives, unclassified = collect(args.dir)
    reasons = select(archives, args.daily, args.weekly, args.monthly)
    out = report(archives, unclassified, reasons, args)

    if args.apply:
        failed = []
        for a in archives:
            if a["name"] in reasons:
                continue
            try:
                os.unlink(a["path"])
            except OSError as e:
                failed.append({"name": a["name"], "error": str(e)})
        out["apply_failed"] = failed
        # Re-read: the plan's value is the resulting on-disk state, not the plan.
        after, _ = collect(args.dir)
        out["archives_after"] = len(after)
        out["keep_gib_after"] = round(sum(a["bytes"] for a in after) / 2**30, 2)

    if args.json:
        print(json.dumps(out, indent=2))
    else:
        w = out["window"]
        print(f"{out['mode']}  {args.dir}")
        print(f"window: {w['daily']} daily / {w['weekly']} weekly / {w['monthly']} monthly")
        print(f"archives: {out['archives_total']}  keep {out['keep_count']} ({out['keep_gib']} GiB)"
              f"  delete {out['delete_count']} ({out['delete_gib']} GiB)")
        print(f"kept range: {out['oldest_kept']} .. {out['newest_kept']}")
        print(f"newest archive: {out['newest_archive_day']} ({out['latest_archive_age_days']} days old)")
        if out["days_with_multiple_archives"]:
            print(f"days holding more than one archive: {out['days_with_multiple_archives']}")
        for e in out["unclassified_entries"]:
            print(f"unclassified (never deleted): {e['name']}  [{e['reason']}]")
        if "apply_failed" in out:
            print(f"delete failures: {out['apply_failed']}")
            print(f"after: {out['archives_after']} archives, {out['keep_gib_after']} GiB")
        elif not args.apply and out["delete_count"]:
            print("no files removed; re-run with --apply after the owner approves this plan")
    return 0


if __name__ == "__main__":
    sys.exit(main())

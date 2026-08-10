#!/opt/hoymiles-cloud/venv/bin/python
"""Hoymiles S-Miles Cloud telemetry monitor.

Reads live data from the Hoymiles S-Miles cloud API (pure JSON, no HTML
parsing) for the HMS-800-2WB plant. The HMS-800-2WB (HiFlow Pro series)
does not expose the local TCP 10081 protocol, so the cloud is the only
available data source.

Credentials: ~/.config/hoymiles/credentials.json (JSON: username,
password, plant_id) or env vars HOYMILES_USERNAME / HOYMILES_PASSWORD.

Usage:
    ~/scripts/hoymiles_cloud_monitor.py            # single poll
    ~/scripts/hoymiles_cloud_monitor.py --loop     # poll every 45 s
    ~/scripts/hoymiles_cloud_monitor.py --plant 14557760

Exit codes:
    0  data received and printed
    1  auth failure / plant not found / API error
"""

import argparse
import asyncio
import json
import os
import sys
import time
from datetime import datetime

sys.path.insert(0, "/home/henning/scripts")

import aiohttp
from hoymiles_cloud.hoymiles_api import HoymilesAPI

CONFIG_PATH = "/home/henning/.config/hoymiles/credentials.json"
DEFAULT_INTERVAL = 45  # s


def load_credentials():
    """Load credentials from config file or environment variables."""
    if os.environ.get("HOYMILES_USERNAME") and os.environ.get("HOYMILES_PASSWORD"):
        return {
            "username": os.environ["HOYMILES_USERNAME"],
            "password": os.environ["HOYMILES_PASSWORD"],
            "plant_id": os.environ.get("HOYMILES_PLANT_ID", ""),
        }
    try:
        with open(CONFIG_PATH, encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        print(f"ERROR: credentials file {CONFIG_PATH} not found")
        return None
    except json.JSONDecodeError as exc:
        print(f"ERROR: credentials file {CONFIG_PATH} is not valid JSON: {exc}")
        return None


def fmt_ts(data_ts):
    """Format the cloud data timestamp; fall back to local now."""
    if data_ts:
        try:
            return datetime.strptime(data_ts, "%Y-%m-%d %H:%M:%S").strftime(
                "%Y-%m-%d %H:%M:%S"
            )
        except ValueError:
            return str(data_ts)
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


async def poll_once(api, plant_id):
    """One poll cycle. Returns exit code."""
    try:
        if not api._token or api.is_token_expired():
            if not await api.authenticate():
                print(
                    f"ERROR: authentication failed "
                    f"({api.last_auth_attempt_summary})"
                )
                return 1

        stations = await api.get_stations()
        if not stations:
            print("ERROR: no plants/stations returned by the API")
            return 1

        if plant_id and plant_id not in stations:
            print(
                f"ERROR: plant {plant_id} not found. "
                f"Available plants: {', '.join(f'{k} ({v})' for k, v in stations.items())}"
            )
            return 1

        sid = plant_id or next(iter(stations))
        name = stations.get(sid, "?")

        rtd = await api.get_real_time_data(sid)
        if not rtd or rtd.get("is_null"):
            print(f"ERROR: no real-time data for plant {sid} ({name})")
            return 1

        power_w = float(rtd.get("real_power") or 0)
        today_wh = float(rtd.get("today_eq") or 0)
        ts_str = fmt_ts(rtd.get("data_time"))

        print(
            f"Hoymiles S-Miles Cloud — plant {sid} \"{name}\"\n"
            f"  PV/AC power:   {power_w:8.1f} W\n"
            f"  Today's yield: {today_wh / 1000.0:8.3f} kWh\n"
            f"  Last update:   {ts_str}"
        )
        return 0
    except Exception as exc:  # noqa: BLE001 - no tracebacks in normal operation
        print(f"ERROR: {exc}")
        return 1


def main():
    parser = argparse.ArgumentParser(
        description="Poll the Hoymiles S-Miles cloud API for plant telemetry."
    )
    parser.add_argument("--loop", action="store_true", help="poll continuously")
    parser.add_argument(
        "--interval",
        type=int,
        default=DEFAULT_INTERVAL,
        help=f"poll interval in seconds, clamped to 30-60 (default {DEFAULT_INTERVAL})",
    )
    parser.add_argument(
        "--plant", default=None, help="plant/station id (default: from credentials)"
    )
    args = parser.parse_args()

    creds = load_credentials()
    if creds is None:
        sys.exit(1)
    plant_id = args.plant or creds.get("plant_id") or ""

    async def run():
        async with aiohttp.ClientSession() as session:
            api = HoymilesAPI(session, creds["username"], creds["password"])
            if not args.loop:
                return await poll_once(api, plant_id)

            interval = max(30, min(args.interval, 60))
            print(f"Continuous polling every {interval}s (Ctrl+C to stop)")
            try:
                while True:
                    rc = await poll_once(api, plant_id)
                    print(f"  [{datetime.now():%H:%M:%S}] poll finished (rc={rc})")
                    await asyncio.sleep(interval)
            except KeyboardInterrupt:
                print("\nStopped.")
            return 0

    sys.exit(asyncio.run(run()))


if __name__ == "__main__":
    main()

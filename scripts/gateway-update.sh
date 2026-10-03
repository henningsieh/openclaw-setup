#!/bin/bash
# Public entry point; Python's standard library owns locking, receipts and recovery.
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec /usr/bin/python3 "$SCRIPT_DIR/gateway_update.py" "$@"

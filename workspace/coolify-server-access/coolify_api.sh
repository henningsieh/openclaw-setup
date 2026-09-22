#!/bin/bash
# Coolify API helper — source this script or run directly.
# Uses COOLIFY_API_TOKEN from the container environment (set via .env).
# No token file needed — MCP server also uses the same env var.

COOLIFY_BASE="https://coolify.sieh.org/api/v1"

coolify_call() {
  local method="$1" path="$2" data="$3"

  if [ -z "${COOLIFY_API_TOKEN}" ]; then
    echo "ERROR: COOLIFY_API_TOKEN is not set" >&2
    return 1
  fi

  if [ -z "$data" ]; then
    curl -s -w "\nHTTP:%{http_code}" \
      -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
      -H "Accept: application/json" \
      --connect-timeout 10 \
      -X "$method" "${COOLIFY_BASE}/${path}"
  else
    curl -s -w "\nHTTP:%{http_code}" \
      -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --connect-timeout 10 \
      -X "$method" -d "$data" \
      "${COOLIFY_BASE}/${path}"
  fi
}

coolify_get() { coolify_call GET "$1"; }
coolify_post() { coolify_call POST "$1" "$2"; }
coolify_patch() { coolify_call PATCH "$1" "$2"; }
coolify_delete() { coolify_call DELETE "$1"; }

# If called directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    GET) coolify_get "$2" ;;
    POST) coolify_post "$2" "$3" ;;
    PATCH) coolify_patch "$2" "$3" ;;
    DELETE) coolify_delete "$2" ;;
    *) echo "Usage: $0 GET|POST|PATCH|DELETE <endpoint> [json-data]" ;;
  esac
fi

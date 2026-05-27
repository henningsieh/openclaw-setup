#!/usr/bin/env node
/**
 * openclaw-bw-resolver.mjs — OpenClaw exec secrets provider for Vaultwarden.
 *
 * Protocol:
 *   stdin:  { "protocolVersion": 1, "provider": "vaultwarden", "ids": ["path/to/secret"] }
 *   stdout: { "protocolVersion": 1, "values": { "path/to/secret": "value" },
 *                                   "errors":  { "path/to/secret": { "message": "..." } } }
 *
 * Required env vars (injected via Docker passEnv, never from openclaw.json):
 *   BW_SERVER_URL   — Vaultwarden base URL (e.g. https://vault.example.com)
 *   BW_CLIENTID     — API client_id  (Vaultwarden → Account Settings → Security → API Key)
 *   BW_CLIENTSECRET — API client_secret (paired with client_id, same source)
 *   BW_PASSWORD     — Your Vaultwarden master password (still needed to *unlock* the vault,
 *                     even when authenticating via API key)
 *
 * Optional env var:
 *   BW_BIN          — Absolute path to the bw binary (default: /home/node/.local/bin/bw)
 *
 * Item naming convention:
 *   Create Login items in Vaultwarden whose "Name" field exactly matches the
 *   SecretRef id (e.g. "openclaw/providers/openai/apiKey"). The resolver reads
 *   the password field of the item. For Secure Notes, the full note body is returned.
 *   Use the "#notes" or "#<custom-field-name>" selector suffix to target other fields
 *   (e.g. "openclaw/providers/openai/apiKey#notes").
 */

import { spawnSync } from "node:child_process";

const BW_BIN = process.env.BW_BIN || "/home/node/.local/lib/bw-private";

/** Run bw with the given args. Returns trimmed stdout or throws on non-zero exit. */
function bwRun(args, extraEnv = {}) {
  const result = spawnSync(BW_BIN, args, {
    encoding: "utf8",
    env: { ...process.env, ...extraEnv },
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.status !== 0) {
    const msg = (result.stderr || result.stdout || "").trim();
    throw new Error(`bw ${args[0]} failed (exit ${result.status}): ${msg}`);
  }
  return (result.stdout || "").trim();
}

let stdin = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  stdin += chunk;
});
process.stdin.on("error", (err) => {
  process.stderr.write(`stdin error: ${err.message}\n`);
  process.exit(1);
});
process.stdin.on("end", () => {
  let request;
  try {
    request = JSON.parse(stdin || "{}");
  } catch (err) {
    process.stderr.write(`Failed to parse request: ${err.message}\n`);
    process.exit(1);
  }

  const { BW_SERVER_URL, BW_CLIENTID, BW_CLIENTSECRET, BW_PASSWORD } =
    process.env;
  if (!BW_SERVER_URL || !BW_CLIENTID || !BW_CLIENTSECRET || !BW_PASSWORD) {
    process.stderr.write(
      "BW resolver: missing required env vars (BW_SERVER_URL, BW_CLIENTID, BW_CLIENTSECRET, BW_PASSWORD)\n"
    );
    process.exit(1);
  }

  const ids = request.ids ?? [];
  const values = {};
  const errors = {};

  let session;
  try {
    // Check current auth status first.
    const statusJson = bwRun(["status"]);
    const { status, serverUrl } = JSON.parse(statusJson);

    // Only reconfigure the server when not yet logged in (bw rejects config
    // changes while an active session exists).
    if (status === "unauthenticated") {
      bwRun(["config", "server", BW_SERVER_URL]);
      // API key login: bw reads BW_CLIENTID and BW_CLIENTSECRET automatically from env.
      bwRun(["login", "--apikey"]);
    }

    // Unlock vault; --passwordenv tells bw to read the master password from BW_PASSWORD.
    session = bwRun(["unlock", "--passwordenv", "BW_PASSWORD", "--raw"]);
  } catch (err) {
    process.stderr.write(`BW resolver: auth/unlock failed: ${err.message}\n`);
    process.exit(1);
  }

  try {
    for (const id of ids) {
      // Support optional "#<selector>" suffix on the id to target a specific field.
      const hashIdx = id.indexOf("#");
      const itemName = hashIdx >= 0 ? id.slice(0, hashIdx) : id;
      const selector = hashIdx >= 0 ? id.slice(hashIdx + 1) : null;

      try {
        if (selector === "notes") {
          // Caller explicitly wants the secure note body.
          const itemJson = bwRun(["get", "item", itemName], {
            BW_SESSION: session,
          });
          const item = JSON.parse(itemJson);
          values[id] = item.notes ?? "";
        } else if (selector) {
          // Caller wants a named custom field.
          const itemJson = bwRun(["get", "item", itemName], {
            BW_SESSION: session,
          });
          const item = JSON.parse(itemJson);
          const field = (item.fields ?? []).find((f) => f.name === selector);
          if (field == null) {
            errors[id] = { message: `field "${selector}" not found on "${itemName}"` };
          } else {
            values[id] = field.value ?? "";
          }
        } else {
          // Default: try password field first (works for Login items), then notes.
          try {
            values[id] = bwRun(["get", "password", itemName], {
              BW_SESSION: session,
            });
          } catch {
            const itemJson = bwRun(["get", "item", itemName], {
              BW_SESSION: session,
            });
            const item = JSON.parse(itemJson);
            values[id] = item.notes ?? "";
          }
        }
      } catch (err) {
        errors[id] = { message: `not found: ${itemName}` };
      }
    }
  } finally {
    // Lock the vault regardless of errors; ignore lock failures.
    try {
      bwRun(["lock"], { BW_SESSION: session });
    } catch {}
  }

  const response = { protocolVersion: 1, values };
  if (Object.keys(errors).length) response.errors = errors;

  process.stdout.write(JSON.stringify(response) + "\n");
});

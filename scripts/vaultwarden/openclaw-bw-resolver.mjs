#!/usr/bin/env node
/**
 * openclaw-bw-resolver.mjs — OpenClaw exec secrets provider for Vaultwarden.
 *
 * Protocol:
 *   stdin:  { "protocolVersion": 1, "provider": "vaultwarden", "ids": ["path/to/secret"] }
 *   stdout: { "protocolVersion": 1, "values": { "path/to/secret": "value" },
 *                                   "errors":  { "path/to/secret": { "message": "..." } } }
 *
 * This file is now a thin SecretRef-protocol envelope. The actual bw
 * auth/unlock/fetch/lock logic lives in a single shared module compiled from
 * the vault-fetch tool plugin:
 *
 *   plugins/vault-fetch/src/bw-client.ts  →  /home/node/.openclaw-plugin-vault-fetch/dist/bw-client.js
 *
 * The same shared module is imported natively (as TypeScript) by the
 * vault_fetch tool plugin, so the resolver and the tool never drift apart.
 *
 * Required env vars (injected via Docker passEnv, never from openclaw.json):
 *   BW_SERVER_URL   — Vaultwarden base URL (e.g. https://vault.example.com)
 *   BW_CLIENTID     — API client_id  (Vaultwarden → Account Settings → Security → API Key)
 *   BW_CLIENTSECRET — API client_secret (paired with client_id, same source)
 *   BW_PASSWORD     — Your Vaultwarden master password (still needed to *unlock* the vault,
 *                     even when authenticating via API key)
 *
 * Optional env var:
 *   BW_BIN          — Absolute path to the bw binary (default: /home/node/.local/lib/bw-private)
 *
 * Item naming convention:
 *   Create Login items in Vaultwarden whose "Name" field exactly matches the
 *   SecretRef id (e.g. "openclaw/providers/openai/apiKey"). The resolver reads
 *   the password field of the item. For Secure Notes, the full note body is returned.
 *   Use the "#notes" or "#<custom-field-name>" selector suffix to target other fields
 *   (e.g. "openclaw/providers/openai/apiKey#notes").
 */

// Image-absolute path to the shared compiled module. The plugin is built at
// image build time (Dockerfile.gateway step 8) before the resolver ever runs
// (at container runtime), so this file always exists when the resolver runs.
import { unlockVault, resolveField, lockVault } from "/home/node/.openclaw-plugin-vault-fetch/dist/bw-client.js";

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
    session = unlockVault();
  } catch (err) {
    process.stderr.write(`BW resolver: auth/unlock failed: ${err.message}\n`);
    process.exit(1);
  }

  try {
    for (const id of ids) {
      try {
        values[id] = resolveField(id, session);
      } catch (err) {
        errors[id] = { message: err.message };
      }
    }
  } finally {
    lockVault(session);
  }

  const response = { protocolVersion: 1, values };
  if (Object.keys(errors).length) response.errors = errors;

  process.stdout.write(JSON.stringify(response) + "\n");
});
/**
 * OpenClaw tool plugin: vault_fetch
 *
 * Exposes a single agent-callable tool, `vault_fetch`, that retrieves a
 * credential from a self-hosted Vaultwarden vault via the Bitwarden CLI (`bw`).
 *
 * Why a tool plugin (not a shell script):
 *   - The execute() handler runs in-process inside the gateway, so it has
 *     direct access to `process.env.BW_*`. No /proc/1/environ and no
 *     exec-tool env-stripping workaround needed.
 *   - The agent invokes a typed tool name rather than shelling out to a
 *     binary on PATH, so OpenClaw projects it natively.
 *
 * The actual `bw` auth/unlock/fetch/lock logic lives in ./bw-client, which is
 * the single shared source of truth also imported (as compiled JS) by
 * scripts/vaultwarden/openclaw-bw-resolver.mjs. Tool/plugin concerns only
 * (TypeBox schemas, defineToolPlugin, execute envelope) live here.
 *
 * The agent-facing boundary stays clean: `BW_*` are stripped from the agent
 * exec-tool environment by the gateway's host-env-security policy, and the
 * agent only ever sees credential *values* returned by this tool — never the
 * master password itself.
 */

import { Type } from "typebox";
import { defineToolPlugin } from "openclaw/plugin-sdk/tool-plugin";
import { lockVault, resolveField, resolveJson, unlockVault } from "./bw-client.js";

export default defineToolPlugin({
  id: "vault-fetch",
  name: "Vault Fetch",
  description:
    "Fetch credentials from the self-hosted Vaultwarden vault. Use for logins, API keys, and other secrets needed during agent tasks. Item ids match the Vault item 'Name' field and may use a '#notes' or '#<custom-field>' selector suffix.",
  activation: {
    onStartup: true,
  },
  tools: (tool) => [
    tool({
      name: "vault_fetch",
      label: "Fetch Vault Credential",
      description:
        "Fetch a credential from the Vaultwarden vault. By default returns the item's password. Use mode='json' to get the full item object (username, password, notes, custom fields).",
      parameters: Type.Object({
        name: Type.String({
          description:
            "Vault item name (matches the 'Name' field in Vaultwarden). Append '#notes' for a Secure Note body, or '#<customFieldName>' for a custom field.",
        }),
        mode: Type.Optional(
          Type.Union(
            [Type.Literal("password"), Type.Literal("json")],
            { description: "Return shape: 'password' (default) or 'json' (full item)." },
          ),
        ),
      }),
      async execute({ name, mode }) {
        const wantJson = mode === "json";

        let session: string;
        try {
          session = unlockVault();
        } catch (err) {
          return {
            error: true,
            message:
              err instanceof Error ? err.message : "vault_fetch: unlock failed",
          };
        }

        try {
          if (wantJson) {
            const item = resolveJson(name, session);
            if (item == null) {
              return { error: true, message: `not found: ${name}` };
            }
            return { name, item };
          }
          const value = resolveField(name, session);
          if (value === "" || value == null) {
            return { error: true, message: `not found or empty: ${name}` };
          }
          return value;
        } catch (err) {
          return {
            error: true,
            message:
              err instanceof Error ? err.message : "vault_fetch: lookup failed",
          };
        } finally {
          lockVault(session);
        }
      },
    }),
  ],
});
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
 * The `bw` binary is invoked as a subprocess from within the gateway process,
 * so it inherits `BW_*` automatically. The agent-facing boundary stays clean:
 * `BW_*` are stripped from the agent exec-tool environment by the gateway's
 * host-env-security policy, and the agent only ever sees credential *values*
 * returned by this tool — never the master password itself.
 */

import { spawnSync, type SpawnSyncOptions } from "node:child_process";
import { Type } from "typebox";
import { defineToolPlugin } from "openclaw/plugin-sdk/tool-plugin";

const BW_BIN = process.env.BW_BIN || "/home/node/.local/lib/bw-private";

/** Run bw with the given args; returns trimmed stdout, or throws on failure. */
function bwRun(args: string[], extraEnv: Record<string, string> = {}): string {
  const opts: SpawnSyncOptions = {
    encoding: "utf8",
    env: { ...process.env, ...extraEnv },
    stdio: ["ignore", "pipe", "pipe"],
  };
  const result = spawnSync(BW_BIN, args, opts);
  const stderr = String(result.stderr ?? "").trim();
  const stdout = String(result.stdout ?? "").trim();
  if (result.status !== 0) {
    const msg = stderr || stdout || "(no output)";
    throw new Error(`bw ${args.join(" ")} failed (exit ${result.status}): ${msg}`);
  }
  return stdout;
}

/** Ensure bw is logged in and the vault is unlocked; returns a session token. */
function unlockVault(): string {
  void (process.env.BW_SERVER_URL); // type guard for presence check below
  const { BW_SERVER_URL, BW_CLIENTID, BW_CLIENTSECRET, BW_PASSWORD } =
    process.env;
  if (!BW_SERVER_URL || !BW_CLIENTID || !BW_CLIENTSECRET || !BW_PASSWORD) {
    throw new Error(
      "vault_fetch: missing BW_SERVER_URL/BW_CLIENTID/BW_CLIENTSECRET/BW_PASSWORD in gateway process env",
    );
  }

  const statusJson = bwRun(["status"]);
  let status: string | undefined;
  try {
    ({ status } = JSON.parse(statusJson));
  } catch {
    // ignore: status stays undefined and we retry below
  }
  if (status === "unauthenticated") {
    bwRun(["config", "server", BW_SERVER_URL]);
    bwRun(["login", "--apikey"]);
  }
  return bwRun(["unlock", "--passwordenv", "BW_PASSWORD", "--raw"]);
}

interface ParsedId {
  itemName: string;
  selector: string | null;
}

function parseId(id: string): ParsedId {
  const hashIdx = id.indexOf("#");
  if (hashIdx >= 0) {
    return { itemName: id.slice(0, hashIdx), selector: id.slice(hashIdx + 1) };
  }
  return { itemName: id, selector: null };
}

/** Fetch a single password-field value, notes body, or custom field. */
function resolveField(itemId: string, session: string): string {
  const { itemName, selector } = parseId(itemId);

  if (selector === "notes") {
    const item = JSON.parse(bwRun(["get", "item", itemName], { BW_SESSION: session }));
    return (item.notes as string | undefined) ?? "";
  }

  if (selector) {
    const item = JSON.parse(bwRun(["get", "item", itemName], { BW_SESSION: session }));
    const field = (item.fields ?? []).find(
      (f: { name?: string }) => f.name === selector,
    );
    if (!field) {
      throw new Error(`field "${selector}" not found on "${itemName}"`);
    }
    return (field.value as string | undefined) ?? "";
  }

  // Default: try password field first (Login items), fall back to notes body.
  try {
    return bwRun(["get", "password", itemName], { BW_SESSION: session });
  } catch {
    const item = JSON.parse(bwRun(["get", "item", itemName], { BW_SESSION: session }));
    return (item.notes as string | undefined) ?? "";
  }
}

/** Fetch the full vault item JSON (login, password, notes, custom fields, …). */
function resolveJson(itemId: string, session: string): unknown {
  const { itemName } = parseId(itemId);
  let items: unknown[] = [];
  try {
    items = JSON.parse(bwRun(["list", "items", "--search", itemName], { BW_SESSION: session })) as unknown[];
  } catch {
    items = [];
  }
  // Prefer an exact name match; otherwise return the first search hit.
  const exact = items.find(
    (it) => (it as { name?: string }).name === itemName,
  );
  return exact ?? items[0] ?? null;
}

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
          try {
            bwRun(["lock"], { BW_SESSION: session });
          } catch {
            // ignore lock failures
          }
        }
      },
    }),
  ],
});
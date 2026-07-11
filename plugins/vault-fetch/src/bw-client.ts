/**
 * bw-client.ts — shared Vaultwarden/Bitwarden CLI logic.
 *
 * Single source of truth for authenticating against a Vaultwarden server
 * via the `bw` CLI and resolving credential ids into values. Imported by:
 *
 *   - the `vault_fetch` tool plugin  (this package, src/index.ts)
 *   - the openclaw-bw-resolver.mjs    (scripts/vaultwarden/, which imports the
 *     compiled /home/node/.openclaw-plugin-vault-fetch/dist/bw-client.js
 *     at runtime inside the container)
 *
 * To keep the resolver's import footprint minimal, this module MUST NOT pull
 * in `typebox`, the OpenClaw plugin SDK, or any other heavy dependency — it
 * only uses node:child_process and process.env. Tool/plugin concerns
 * (TypeBox schemas, defineToolPlugin, execute handlers) live in index.ts.
 */

import { spawnSync, type SpawnSyncOptions } from "node:child_process";

/** Path to the private `bw` binary (intentionally not on the agent exec PATH). */
const BW_BIN = process.env.BW_BIN || "/home/node/.local/lib/bw-private";

/** Run bw with the given args; returns trimmed stdout, or throws on failure. */
export function bwRun(args: string[], extraEnv: Record<string, string> = {}): string {
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
export function unlockVault(): string {
  const { BW_SERVER_URL, BW_CLIENTID, BW_CLIENTSECRET, BW_PASSWORD } = process.env;
  if (!BW_SERVER_URL || !BW_CLIENTID || !BW_CLIENTSECRET || !BW_PASSWORD) {
    throw new Error(
      "bw-client: missing BW_SERVER_URL/BW_CLIENTID/BW_CLIENTSECRET/BW_PASSWORD in gateway process env",
    );
  }

  let status: string | undefined;
  try {
    ({ status } = JSON.parse(bwRun(["status"])));
  } catch {
    // ignore: status stays undefined and we retry below
  }
  if (status === "unauthenticated") {
    bwRun(["config", "server", BW_SERVER_URL]);
    bwRun(["login", "--apikey"]);
  }
  return bwRun(["unlock", "--passwordenv", "BW_PASSWORD", "--raw"]);
}

/** Lock the vault; ignores lock failures (best-effort cleanup). */
export function lockVault(session: string): void {
  try {
    bwRun(["lock"], { BW_SESSION: session });
  } catch {
    // ignore lock failures
  }
}

export interface ParsedId {
  itemName: string;
  selector: string | null;
}

/** Split an id of the form "itemName" or "itemName#selector" into its parts. */
export function parseId(id: string): ParsedId {
  const hashIdx = id.indexOf("#");
  if (hashIdx >= 0) {
    return { itemName: id.slice(0, hashIdx), selector: id.slice(hashIdx + 1) };
  }
  return { itemName: id, selector: null };
}

/**
 * Fetch a single credential value for an id:
 *   - no selector  → password field (Login items), falling back to notes body
 *   - "#notes"     → Secure Note body
 *   - "#<field>"   → named custom field
 */
export function resolveField(itemId: string, session: string): string {
  const { itemName, selector } = parseId(itemId);

  if (selector === "notes") {
    const item = JSON.parse(bwRun(["get", "item", itemName], { BW_SESSION: session }));
    return (item.notes as string | undefined) ?? "";
  }

  if (selector) {
    const item = JSON.parse(bwRun(["get", "item", itemName], { BW_SESSION: session }));
    const field = (item.fields ?? []).find((f: { name?: string }) => f.name === selector);
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

/**
 * Fetch the full vault item JSON for an id (login, password, notes, custom
 * fields, …). Searches by item name; prefers an exact name match, otherwise
 * returns the first search hit. Returns null if nothing matches.
 */
export function resolveJson(itemId: string, session: string): unknown {
  const { itemName } = parseId(itemId);
  let items: unknown[] = [];
  try {
    items = JSON.parse(
      bwRun(["list", "items", "--search", itemName], { BW_SESSION: session }),
    ) as unknown[];
  } catch {
    items = [];
  }
  const exact = items.find((it) => (it as { name?: string }).name === itemName);
  return exact ?? items[0] ?? null;
}
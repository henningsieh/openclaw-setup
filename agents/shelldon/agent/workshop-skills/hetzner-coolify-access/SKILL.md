---
name: "hetzner-coolify-access"
description: "Access or manage Hetzner servers/DNS or the Coolify host — native hcloud, SSH, REST, and MCP paths."
---

# Hetzner & Coolify Access

1. **Know where the machine credentials live.** `HCLOUD_TOKEN` and `COOLIFY_API_TOKEN` are
   process-environment values in the global dotenv `~/.openclaw/.env` — not Vault Items. Before
   blaming a CLI, confirm a plain exec sees them (`printenv HCLOUD_TOKEN | wc -c`). Finish when
   both are present, or you have run step 2.

2. **When a plain exec reports them missing, the dotenv was written after gateway startup.**
   Exec inherits the gateway process environment, which holds only values loaded when the gateway
   started. Restart the gateway to load `~/.openclaw/.env`; for a single command, source it first
   (`set -a; . ~/.openclaw/.env; set +a`). Diagnose this with step 1's `printenv`, never with
   `/proc/<pid>/environ`: that file shows the startup environment only, so a value the gateway
   loaded at runtime is absent there even while exec and the gateway both use it normally — a false
   negative that looks like a broken credential. Finish when a plain exec reads both tokens, or you
   know a restart is required.

3. **Quote values when writing the dotenv.** The Coolify token contains `|`; unquoted, shell
   sourcing runs the trailing segment as a command. Write `KEY="value"` and confirm with
   `set -a; . ~/.openclaw/.env; set +a; echo ${#HCLOUD_TOKEN} ${#COOLIFY_API_TOKEN}` (non-zero
   lengths, no error). Finish when sourcing is silent.

4. **Keep the dotenv and key material out of git.** The repo `.gitignore` does not cover `.env` or
   key directories by default. Add ignore entries and confirm each path with
   `git check-ignore -v --no-index <path>`. Finish when every secret path matches an ignore rule.

5. **Hetzner: use `hcloud`.** If it is not on PATH, install the checksum-verified release into
   `~/.local/bin`:
   ```bash
   ver=<latest>; cd /tmp
   curl -sLO "https://github.com/hetznercloud/cli/releases/download/v$ver/hcloud-linux-amd64.tar.gz"
   curl -sLO "https://github.com/hetznercloud/cli/releases/download/v$ver/checksums.txt"
   grep hcloud-linux-amd64.tar.gz checksums.txt | sha256sum -c -
   tar xzf hcloud-linux-amd64.tar.gz hcloud && install -m 0755 hcloud ~/.local/bin/hcloud
   ```
   Then `hcloud server list`, `hcloud zone list`, `hcloud server describe <id|name>`. Finish when a
   read-only `hcloud server list` returns the expected servers.

6. **Coolify: pick the path that fits the task, then read `references/coolify-access.md`.** SSH for
   the host and containers, the REST helper script for API mutations, or the MCP server for
   structured inventory. Finish when the chosen path returns live data.

7. **Use only native paths.** The pages `hetzner-hcloud-cli-administration` and `coolify-server`
   describe the native install and are current — use them and this skill directly. Finish when every
   command you run uses a native path.

Verification: after any required restart, a plain exec with no manual sourcing reads both tokens;
`hcloud server list` returns both servers; `ssh -i <coolify key> root@10.0.0.3 hostname` returns the
Coolify host; the Coolify REST or MCP path answers HTTP 200.

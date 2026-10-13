---
name: "hetzner-coolify-access"
description: "Access or manage Hetzner servers/DNS or the Coolify host — native hcloud, SSH, REST, and MCP paths, plus CLI auth in the operator's login shell."
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

   **The operator's login shell does not load the dotenv, so CLI auth looks broken there.**
   Verified symptom: a plain interactive shell reports `hcloud context list` / `hcloud context
   active` empty and `hcloud` prints `Warning: HCLOUD_TOKEN is set.` only once the token is
   sourced — the gateway has the token, the human shell does not. Same root as step 2, but for
   the *login* shell: `~/.openclaw/.env` is loaded by the gateway, never by `.bashrc`. Fix it
   once with a guarded block at the end of `~/.bashrc` (back it up first):
   ```bash
   if [ -f "$HOME/.openclaw/.env" ]; then set -a; . "$HOME/.openclaw/.env"; set +a; fi
   ```
   Verify in a **fresh interactive login shell** (`bash -lic …`), not `bash -lc …`: a
   non-interactive login shell skips `.bashrc`, so it reads empty and is a false negative.
   Keep the quotes in the dotenv — they protect `|` and other shell metacharacters; never
   de-quote the file to "fix" a shell. Finish when a fresh interactive shell reads both
   non-zero lengths and `hcloud server list` returns the servers without manual sourcing.

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

6. **Hetzner DNS: manage RRSets, never assume the name is free.** A `CNAME` cannot
   coexist with `A`/`AAAA` on the same name — creating `A`/`AAAA` over an existing
   `CNAME` fails, so inspect first:
   ```bash
   hcloud zone rrset list <zone> -o json
   hcloud zone rrset describe <zone> <name> CNAME
   hcloud zone rrset describe <zone> <name> A
   hcloud zone rrset describe <zone> <name> AAAA
   ```
   When replacing a `CNAME` with direct records, delete first, then create with
   the zone's TTL convention (`60` for `sieh.org`):
   ```bash
   hcloud zone rrset delete <zone> <name> CNAME
   hcloud zone rrset create --name <name> --type A --record <ipv4> --ttl 60 <zone>
   hcloud zone rrset create --name <name> --type AAAA --record <ipv6> --ttl 60 <zone>
   ```
   Verify against the API *and* all three authoritative nameservers with a retry:
   `hcloud zone rrset describe` for each type, then
   `dig @helium.ns.hetzner.de`, `@hydrogen.ns.hetzner.com`,
   `@oxygen.ns.hetzner.com` for both `A` and `AAAA`. A fresh `AAAA` can return
   `NODATA` for ~10 s after a successful create before all three serve it —
   wait and re-query before calling it missing. Finish when API and all three NS
   agree on both types.

7. **Coolify: pick the path that fits the task, then read `references/coolify-access.md`.** SSH for
   the host and containers, the REST helper script for API mutations, or the MCP server for
   structured inventory. Finish when the chosen path returns live data.

8. **Use only native paths.** The pages `hetzner-hcloud-cli-administration` and `coolify-server`
   describe the native install and are current — use them and this skill directly. Finish when every
   command you run uses a native path.

9. **Prove docker access before concluding anything is absent.** A `docker ps
   | grep <name>` that prints nothing may be hiding `permission denied` on
   stderr — observed false "no such container" that way. Check the exit
   code and stderr unfiltered first; `sudo -n -l` lists the granted commands
   (here: `docker ps` allowed, `docker exec` not). Finish when access or its
   denial is established from an unfiltered call, never from an empty grep.

10. **Prefer the OpenClaw-managed MCP path; it is implicit and needs no client setup.**
    `mcp.servers.<name>` in `openclaw.json` loads the server on the gateway and exposes its tools
    directly — no `~/.pi/agent/mcp.json`, no separate MCP client. Confirm it live with a read tool
    (e.g. the server's `list_servers`) rather than assuming. When inspecting, **`openclaw mcp show
    <name>` echoes the resolved token value** (the config itself holds a `${VAR}` SecretRef and is
    secret-free; the operator subcommand is what leaks). Use `openclaw mcp list` for names-only, and
    keep `mcp show` output out of any shared transcript. Finish when a live read tool answers and no
    command output you saved contains a token value.

Verification: after any required restart, a plain exec with no manual sourcing reads both tokens;
`hcloud server list` returns both servers; `ssh -i <coolify key> root@10.0.0.3 hostname` returns the
Coolify host; the Coolify REST or MCP path answers HTTP 200.

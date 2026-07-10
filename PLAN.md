# Professionalization Plan

This plan captures improvements identified during a thorough audit of the
`openclaw-setup` repository against OpenClaw best practices, Docker hygiene,
and long-term maintainability.

**Status legend:** `⬜ not started` `🔄 in progress` `✅ done`

---

## A — Complete the native SecretRef migration  ★★★

**Problem:** `secrets.providers.vaultwarden` exec provider exists in the live
config but is unused — provider API keys and channel tokens are still plaintext
in `.env` and `auth-profiles.json`. The parallel `vault-fetch` bridge is a
bespoke workaround that duplicates what the native system already supports.

**Checklist:**

- [ ] A1. Set `secrets.defaults.exec: "vaultwarden"` so every new SecretRef
      resolves via Vaultwarden by default.
- [ ] A2. Migrate each provider API key in `auth-profiles.json` / `openclaw.json`
      to `{source:"exec", provider:"vaultwarden", id:"openclaw/providers/<name>/apiKey"}`.
      Providers: `google`, `openrouter`, `nvidia`, `opencode`, `opencode-go`.
- [ ] A3. Migrate channel tokens (`telegram.botToken`, `discord.token`) to
      `{source:"exec", provider:"vaultwarden", id:"channels/telegram/botToken"}` etc.
- [ ] A4. Migrate `gateway.auth.password` and other supported credential
      surfaces (MCP server env vars via `plugins.entries.acpx.config.mcpServers`).
- [ ] A5. Run the migration gate: `openclaw secrets audit --check` →
      `openclaw secrets configure --apply` → re-audit. Treat "no plaintext residue"
      as the done-state.
- [ ] A6. Remove migrated secrets from `.env` (provider keys, channel tokens).
- [ ] A7. Demote `vault-fetch` from "core secrets architecture" to "ad-hoc
      convenience for agent shell usage".
- [ ] A8. Update `scripts/vaultwarden/README.md` and `AGENTS.md` to reflect the
      native SecretRef path, not the bridge, as the primary integration.

---

## B — Restore tini as PID 1  ★★★  ✅

**Problem:** `Dockerfile.gateway` sets `ENTRYPOINT ["/usr/local/bin/openclaw-entrypoint.sh"]`,
overriding the base image's tini entrypoint. The long-lived gateway therefore
ran without zombie reaping or clean signal handling.

- [x] B1. Add `init: true` to the `openclaw-gateway` service in
      `docker-compose.yml` (Docker's built-in init wrapper, tini-equivalent).
- [x] B2. Also add `init: true` to `openclaw-cli` for consistency.
- [x] B3. Tested `docker compose down --timeout 10` — container stopped
      instantly, no zombie/hang. Re-started and healthy.

**Verification:** `docker inspect` shows `HostConfig.Init: true` on the
running gateway; `docker compose --profile cli config` confirms `init: true`
on both services.

---

## C — Make the sed patch fail-closed (or eliminate it)  ★★

**Problem:** The `sed` patch against `/app/dist/host-env-security-<hash>.js`
breaks silently on every base-image upgrade because the filename contains a
content hash. After §A, the *need* for the patch may be smaller, but it must
not silently vanish.

- [ ] C1. Investigate whether OpenClaw has a config-native exec-env blocklist
      (`agents.defaults.exec.denyEnv` or similar). Search the schema via
      `openclaw config schema | jq '.. | objects | select(has("exec"))'`.
      If yes, delete the `sed` patch and use config.
- [ ] C2. If no native knob: make the patch fail-closed by adding `grep -q`
      assertions after `sed` that verify both inserted markers exist,
      exiting 1 if the patch wasn't applied. This turns a silent skip into a
      build error.
- [ ] C3. After §A is complete, verify whether `BW_*` are still inherited by
      agent exec and whether the patch is still needed.

---

## D — Fix documentation drift  ★★

**Problem:** `README.md` and both SVGs describe the old "seed" model, which was
removed in the last commit. AGENTS.md is up-to-date but human-facing docs are
not.

- [ ] D1. Rewrite the Skills section of `README.md` to describe the runtime
      `scripts/install-skills.sh` model (reference AGENTS.md for the authoritative
      build-step list).
- [ ] D2. Regenerate or remove `assets/openclaw_build_flow.svg` and
      `assets/openclaw_skills_loading.svg` (or annotate them as "historical").
- [ ] D3. Refresh the "Image size breakdown" table via `docker history`.
- [ ] D4. Fix "What this repo adds" table to remove step 8 / seed references.
- [ ] D5. Replace references to `STAGED_SKILLS_DIR` (no longer exists).

---

## E — Depersonalize the entrypoint  ★★

**Problem:** `scripts/openclaw-init.sh` hardcodes personal PIM identity and
couples CardDAV / CalDAV to a shared presumed password.

- [ ] E1. Add `.env` / `.env.example` entries:
      `QCARD_SERVER_URL`, `QCARD_USERNAME`, `QCARD_RESOLVER_ID`,
      `CALDAV_SERVER_URL`, `CALDAV_USERNAME`, `CALDAV_RESOLVER_ID`.
- [ ] E2. Gate the qcard block on `QCARD_SERVER_URL` being set (not just BW_*
      being available), making it opt-in and reusable.
- [ ] E3. Gate the CalDAV block on `CALDAV_RESOLVER_ID` being set, not on
      `QCARD_PASSWORD` — use an independent resolver fetch.
- [ ] E4. Consider extracting PIM bootstrap into `scripts/pim-bootstrap.sh`
      and calling it from the entrypoint, keeping the entrypoint focused on
      OpenClaw concerns.

---

## F — Fix reproducibility gaps  ★★

**Problem:** `clawhub@latest` is unpinned; `hcloud` hardcodes `amd64`; Go module
cache is left behind.

- [ ] F1. Pin `CLAWHUB_CLI_VERSION` to an exact version (not `latest`).
- [ ] F2. Make hcloud arch-aware: use
      `hcloud-linux-$(dpkg --print-architecture).tar.gz`.
- [ ] F3. Add `&& rm -rf /home/node/go/pkg/mod` to the qcard `go install` step
      (reclaims ~100 MB).
- [ ] F4. Consider digest-pinning `OPENCLAW_BASE_IMAGE` (e.g. `@sha256:...`)
      for stricter reproducibility.

---

## G — Dockerfile / Compose hygiene  ★

- [ ] G1. Renumber build steps in `Dockerfile.gateway` (two "Step 3", two
      "Step 4"). Update the step table in AGENTS.md.
- [ ] G2. Remove `NEXTCLOUD_DOCUMENTS_DIR` from `x-common-build.args` — it is
      a runtime mount, not a build arg.
- [ ] G3. Remove the HEALTHCHECK from `Dockerfile.gateway` (compose overrides
      it; the base image already has one; the hardcoded `18789` port is
      misleading).
- [ ] G4. Either remove the Dockerfile `CMD` (compose `command:` overrides it
      unconditionally) or add a comment explaining it's a fallback.

---

## H — Resolve XDG_CONFIG_HOME collision  ★

**Problem:** `AGENTS.md` says `XDG_CONFIG_HOME=/home/node/.openclaw` but
`.env`/`.env.example` says `/home/node/.config`. The entrypoint writes PIM
config to `~/.config/` (container layer, wiped on rebuild).

- [ ] H1. Decide whether PIM config (qcard, vdirsyncer, khal) should persist
      across rebuilds. If yes, point `XDG_CONFIG_HOME` to a subdir of the
      mounted volume. If no, document that these are re-fetched on every start.
- [ ] H2. Make `AGENTS.md` and `.env.example` agree on the value.

---

## I — Add readiness probe & compose-native skill install  ★

- [ ] I1. Change compose healthcheck to also probe `/readyz` (readiness).
- [ ] I2. Optionally convert `scripts/install-skills.sh` into a one-shot
      compose service with `depends_on: { condition: service_healthy }` so
      `docker compose --profile skills up` is the single command.

---

## J — Add CI and automated version bumps  ★

- [ ] J1. Add a `.github/workflows/build.yml` that builds the image on push/PR,
      starts the gateway, and `curl /healthz`.
- [ ] J2. Add Renovate (or Dependabot) for: `OPENCLAW_VERSION`, `GO_VERSION`,
      `QCARD_VERSION`, `CLAWHUB_CLI_VERSION`, `BROWSER_USE_CLI_VERSION`, and all
      `CLAWHUB_*_SKILL_VERSION` pins.
- [ ] J3. Add the `sed`-patch assertion (§C2) to the workflow so a base-upgrade
      hash rename is caught in CI.

---

## K — Security hardening (lower priority)  ★

- [ ] K1. Once `--bind lan` + port publishing is confirmed working, add
      `cap_drop: [NET_RAW, NET_ADMIN]` and `security_opt: [no-new-privileges:true]`
      to the gateway service (matching the CLI).
- [ ] K2. Consider `read_only: true` with `tmpfs` mounts for `/tmp` and cache
      directories.
- [ ] K3. Audit whether `GATEWAY_AUTH_PASSWORD` is actually used (gateway auth
      mode is `token`, not `password`). Wire it as a SecretRef or remove it.

---

## L — Minor cleanups  ★

- [ ] L1. Add `--no-input` to `install-skills.sh` (AGENTS.md documents it but
      the script omits it).
- [ ] L2. Remove trailing whitespace from `.env` (`GATEWAY_AUTH_PASSWORD` line).
- [ ] L3. Clear old backup files from the live volume
      (`openclaw.json.bak.*`, `.backup-hb-fix*`, `.bak-slowfix`, `.bak-gh-purge`).
      Consider a backup-retention hook that keeps at most `last-good` + one.
- [ ] L4. Verify `.env` and `.env.example` key sets stay identical (they are
      now; add to CI as a diff check).

---

## Order of execution

| Pass | Items | Rationale |
|------|-------|-----------|
| **1** | B1-B2 | One-line fix, immediate correctness win for a long-lived container. |
| **2** | A1-A8 | The headline professionalization. Finishing the native SecretRef path shrinks the blast radius of `C`, `H`, and `L2` in one go. |
| **3** | C1-C3 | After `A`, the patch may be reducible or eliminable entirely. If still needed, make it fail-closed. |
| **4** | E1-E4, F1-F4, G1-G4 | Entrypoint de-personalization, pinning, Dockerfile hygiene — bundle into one PR. |
| **5** | D1-D5 | README/SVG rewrite to match post-migration reality. |
| **6** | I1-I2, J1-J3 | Readiness probe + CI → compounds by catching future drift automatically. |
| **7** | H1-H2, K1-K3, L1-L4 | Polish and hardening. |

---

_Generated 2026-07-10 after a full repository audit against OpenClaw docs,
Docker best practices, and the repo's own stated golden rules._

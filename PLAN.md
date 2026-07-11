# Professionalization Plan

This plan captures improvements identified during a thorough audit of the
`openclaw-setup` repository against OpenClaw best practices, Docker hygiene,
and long-term maintainability.

**Status legend:** `⬜ not started` `🔄 in progress` `✅ done`

---

## A — Migrate the `vault-fetch` shell bridge into a native OpenClaw tool plugin  ★★★  ✅

**Problem:** The existing `vault-fetch` integration was "vibe coded": a shell
script (`scripts/vaultwarden/openclaw-vault-fetch`) that reads `BW_*` from
`/proc/1/environ` and shells out to the resolver. This is fragile, depends on a
`sed`-patched exec-env security policy, and is not the OpenClaw-native way to
expose agent-callable capability.

**Decision:** App environment variables (`OPENCLAW_GATEWAY_TOKEN`, channel
tokens, provider API keys) stay in `.env` — they already use native `${ENV}`
SecretRef shorthand and will **not** be moved to Vaultwarden. Vaultwarden is
reserved for *personal* credentials the agent fetches on demand. The fix is to
replace the shell bridge with an OpenClaw **tool plugin** (`vault_fetch`) that
runs in-process inside the gateway, reads `process.env.BW_*` directly, and
exposes a typed tool the agent calls natively.

**Architecture decision record:** app env vars use `${ENV}` SecretRefs (already
done); Vaultwarden serves personal creds via the tool plugin (in progress); the
`secrets.providers.vaultwarden` block stays registered for optional future
fixed-field SecretRef use.

**Checklist:**

- [x] A1. Build the `vault-fetch` tool plugin package (`plugins/vault-fetch/`) —
      `defineToolPlugin` with one `vault_fetch({ name, mode? })` tool reusing the
      proven `bw` resolver logic. `tsc` clean, `openclaw plugins validate` →
      `Plugin vault-fetch is valid`.
- [x] A2. Bake the build into `Dockerfile.gateway` — compiles TS, generates
      manifest, validates, prunes to runtime deps, symlinks `openclaw → /app`.
      Image builds green.
- [x] A3. Register the plugin in `openclaw.json` (`plugins.load.paths` +
      `plugins.entries["vault-fetch"].enabled`). Gateway loads it.
- [x] A4. Prove the full circle: agent calls `vault_fetch` tool for
      `openclaw/qcard/henning@sieh.org` → returns `15,%,aniFtSMu` → agent replies
      `GOT:15,%`. `toolSummary: {calls:1, tools:["vault_fetch"], failures:0}`.
- [x] A5. Rewrite the `vaultwarden` skill (`SKILL.md`) to teach the `vault_fetch`
      **tool** (not the `vault-fetch` shell command) as the only fetch path.
- [x] A6. Remove the old `vault-fetch` shell bridge: delete
      `scripts/vaultwarden/openclaw-vault-fetch`, its `COPY` in `Dockerfile.gateway`,
      and the `/usr/local/bin/vault-fetch` install. Keep the resolver
      (`openclaw-bw-resolver.mjs`) — it powers `openclaw.json` SecretRefs and the
      entrypoint PIM bootstrap.
- [x] A7. Update `scripts/vaultwarden/README.md` and `AGENTS.md` to document the
      tool plugin as the primary agent credential path (the `vaultwarden` skill
      teaches `vault_fetch`); document the resolver as a lower-level component.
- [x] A8. Revisit §C (the `sed` exec-env patch) — verified it is STILL needed
      (gateway process env carries `BW_*`; exec subprocesses inherit them; the
      patch is the only thing preventing exec("env") from leaking the master
      password). Kept as-is; making it fail-closed is tracked separately as §C2.
- [x] A9. Commit the working state on `feature/professionalization-plan`.
- [x] A10. Extract the shared `bw` auth/unlock/fetch/lock logic into a single
      module (`plugins/vault-fetch/src/bw-client.ts`) that is imported natively
      by the tool plugin and (as compiled `dist/bw-client.js`) by the resolver.
      Verified head-to-head: both paths fetch `"kuma"` and return the identical
      value, proving they share the same logic.

**Verification:**
- Agent reads the updated skill and calls `vault_fetch` unprompted (`kuma` →
  `KvmO...`) with 0 failures.
- Head-to-head shared-module proof: resolver path and tool-plugin path both
  fetch `"kuma"` and return the identical value (`KvmOrJk4U5k3wJGxnx8TONIf`).
- Old `/usr/local/bin/vault-fetch` is gone from the running container; the
  resolver + entrypoint PIM bootstrap are unaffected and also use the shared
  compiled `bw-client.js`.

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

- [x] C1. Investigated: no native config knob exists. The host-env-security
      policy is hardcoded as a static JSON object in a bundled `.js` file.
      The `sed` patch is the only available mechanism.
- [x] C2. Added `grep -q` assertions after both `sed` commands in
      `Dockerfile.gateway` that verify the injected markers (`BW_PASSWORD`
      key + `BW_` prefix) are present. If either is missing, `grep` exits 1
      and the Docker build fails. Updated comments to document the
      fail-closed approach and the update procedure.
- [x] C3. Already confirmed in §A8: the patch is still needed. The gateway
      process env carries BW_*; exec subprocesses inherit them; the patch
      is the only thing preventing exec("env") from leaking the master
      password.

**Result:** The sed patch is now fail-closed. A base-image upgrade that
renames the host-env-security file will cause the build to break at the
first missing grep assertion, alerting the maintainer immediately rather
than silently leaking credentials.

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

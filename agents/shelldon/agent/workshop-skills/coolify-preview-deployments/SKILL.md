---
name: coolify-preview-deployments
description: "Wire a GitHub PR to a Coolify preview deployment: enable previews, provision a dedicated preview database, swap preview envs, trigger and prove the preview URL."
---

# Coolify PR Preview Deployment

Use when a pull request needs a live preview on team Coolify: an app with
existing `is_preview` envs but previews never deployed, or a fresh preview
database per PR. Access paths (REST helper, SSH key, MCP) live in
`hetzner-coolify-access` — read that skill first and use only native paths.

1. **Inventory before touching anything.** `GET applications/{appUuid}`:
   record `git_branch`, `fqdn`, `preview_url_template` (`{{pr_id}}.{{domain}}`
   yields e.g. `261.cost-tracker.<apps-host>`), and
   `settings.is_preview_deployments_enabled`. `GET .../envs` lists key names
   with an `is_preview` flag — a prepared app already carries a full preview
   set including `DATABASE_URL`. `GET databases` confirms the preview
   postgres exists and is healthy. Finish when you know the flag state, the
   expected preview URL, and which database the preview envs point at.

2. **Enable previews with one PATCH.** `PATCH applications/{appUuid}`
   `{"is_preview_deployments_enabled": true}` (HTTP 200 returns only the
   uuid). Re-read the app and require the flag `True`; never assume the
   write landed. Enabling alone touches no running deployment. Finish when
   the readback confirms it.

3. **Provision a dedicated preview database, never reuse a shared one.**
   The preview postgres is internal-only (`is_public: false`, Docker-DNS
   names unresolvable outside). Work from the Coolify host over SSH:
   find the container with `docker ps --filter "name={dbUuid}"`, then
   `docker exec {cid} psql -U postgres -c 'CREATE DATABASE "{name}"'`
   (lowercase + underscores, e.g. `cost_tracker_pr261`). Migrate and seed
   through an SSH tunnel — but tunnel to the container **IP**
   (`docker inspect {cid}` → `NetworkSettings.Networks.*.IPAddress`,
   e.g. `10.0.1.7`), never to the Docker-DNS name, which the host cannot
   resolve. Finish when migrate + second-migrate-no-op + seed all succeed
   through the tunnel.

4. **Swap the preview `DATABASE_URL` with DELETE + POST, re-reading the
   UUID first.** Coolify versions env UUIDs on every write, so a UUID read
   minutes ago is stale — re-list, then `DELETE
   applications/{appUuid}/envs/{currentUuid}` and `POST
   applications/{appUuid}/envs` with the new value plus the old flags
   (`is_preview`, `is_buildtime`, `is_runtime` as the replaced entry had
   them). `PATCH .../envs/{uuid}` and singular `.../env` both 404 — do not
   retry them. Verify by parsing host/dbname components only. Finish when
   exactly one preview `DATABASE_URL` exists and names the dedicated
   database.

5. **Never print URL values, anywhere.** Parse `host`/`port`/`dbname` from
   the API JSON and print only those components. Build replacement URLs in
   `0600` temp files sourced and deleted in the same task
   (`psql`/`drizzle-kit` take them from env, never from an echoed command
   line). Do not let a probe write junk envs either: a bare `POST .../envs`
   with only a key creates a real entry (observed), so delete test entries
   by their current UUID immediately and re-list to confirm zero residue.
   Finish when no secret value reached stdout, chat, logs, or the repo.

6. **Register the PR with POST — pushes alone register nothing.** Pushing to
   the PR branch, and even closing + reopening the PR, produced no preview
   record and no deployment (`.../previews` stayed `[]`; every deploy attempt
   kept answering `No query results for model
   [App\Models\ApplicationPreview]`). Do not churn the PR timeline retrying
   this, and do not present a push as per-commit-redeploy proof: automatic
   redeploy on commit remains OPEN (blocked on webhook delivery) — every
   verified deployment here came from an explicit call. The deploy call
   (`POST deploy {"uuid","pull_request_id","force"}` or the `coolify__deploy`
   MCP tool) succeeds only if Coolify already holds an `ApplicationPreview`
   record for the PR — before that it fails (surfaced by MCP as a bare
   internal error). Create the record directly: `POST
   applications/{appUuid}/previews {"pull_request_id": N}` returns HTTP 201
   with the preview record (domains per `preview_url_template`) AND queues a
   deployment in one step — verified working. If webhooks are definitively
   dead, the owner-side check is the GitHub App's repository coverage (repo
   Settings → GitHub Apps). Finish when the POST response hands back a
   `deployment_uuid` for the PR (note it — later status checks need it).

   **Gate every triggered build on host disk.** The 38G Coolify host runs
   hot (observed 95–96%, ~2G free; `docker system df` showed all images,
   containers and volumes active with 0B reclaimable). Before triggering,
   `df -h /` over SSH: above 97%, abort the deploy and report instead of
   building. Never `prune --volumes` or `system prune -a` — volumes hold
   live databases. Safe wins only: stale manual tarballs with explicit
   owner approval (observed 171M June backup removed; journal vacuum freed
   0B, skip when so). Prefer fewer batched builds over many small ones —
   each railpack build temporarily eats GBs.

7. **Prove the URL, and read the right log line for the branch.** `curl`
   the preview URL and require HTTP 200 — a queued/failed deployment is not proof
   (`get_deployment` with `include_log_summary` names the cause; build logs
   stay redacted). A build whose log ends mid-step with no error (observed:
   silent stop during the TypeScript compile) is resource exhaustion until
   proven otherwise — check `free -m` and `dmesg | grep -i oom` on the host
   before re-reading config; a green disk check does not rule out OOM on a
   small host. Which branch actually builds is answered ONLY by the
   early line `Checking out tag pull/N/head` — the `repo:tracked-branch`
   label next to it, and the deployment record's `commit` field, both name the
   import base, not the built ref; never cancel a healthy build over the label
   (observed false abort). Two preview-specific build hazards, both verified:
    - **Delete the build-time migrate; a skip-if-unset guard is not enough.**
      Preview envs ARE injected at build (`is_buildtime: true` on every preview
      env, confirmed by readback) — so the variable is set, the guard never
      triggers, and the internal Docker-DNS database hostname does not resolve
      inside BuildKit build containers: the migrate step fails fast on
      connection (seconds after "applying migrations", no SQL error printed).
      Observed: a build carrying the skip-if-unset guard failed identically;
      the build after deleting the `prebuild` migrate line finished (owner-
      confirmed working deployment). Keep the runtime `start:prepare` hook,
      which runs on the Coolify network where the DB resolves — do not weaken it.
    - **Point preview `NEXT_PUBLIC_BASE_URL` at the preview domain BEFORE the
      proving build.** `NEXT_PUBLIC_*` values bake in at build time, and the
      prepared preview entry named the production URL — a green build would
      then serve prod links. Swap it via DELETE + POST (same UUID discipline
      as step 4) to `https://<pr>.<app-domain>` with the previous flags, then
      trigger one more build: an earlier green build does not cover the
      corrected value.
   Kill background processes by stored PID (`$!` at creation), never
   by pattern-matching the command line — a `pkill -f` pattern containing
   the port or command also matches the killing shell itself (observed SIGTERM
   self-kill with both an SSH tunnel and a local `http.server`). Delete the temp URL files. Finish when the tunnel is gone,
   temp files are gone, and the preview URL returns 200 on a build containing
   the migrate removal; re-verify after any later env correction
   (auto-redeploy stays open per step 6). HTTP 200 alone never proves
   freshness — a stale build serves 200 too (observed: old commit answering
   while the fix was still queued). After every proving build, grep the
   served HTML for change-specific markers and require them before calling
   the preview good.

   Diagnose a stuck build before stacking retriggers. A deployment that
   reads `in_progress` while the host is idle (no build CPU in `ps aux`,
   `updated_at` stale 30+ min) is a zombie, not a slow build: cancel it
   (`POST deployments/{uuid}/cancel`, require `cancelled`) and trigger
   exactly one fresh build — never queue another on top. An OOM kill has
   a fixed signature in the railpack log (`cannot allocate memory`,
   `exited (137)`, `Killed`, usually mid TypeScript compile on a small
   host): that is host RAM, not code — `free -m` first, rebuild only with
   headroom. The `logs` field of `GET deployments/{uuid}` is a JSON
   *string* holding the entry array — parse twice; branch truth is the
   `refs/pull/N/head` line, never the record's `commit` field. Poll
   status with single-shot checks; repeated process polls can SIGTERM
   the waiter itself — for long builds run a background loop appending
   to a log file and read the file instead.

Verification: previews enabled on readback; dedicated database migrated,
seeded, and named by the preview env; preview URL returns 200; no secret
value in any output; tunnel and temp files removed.

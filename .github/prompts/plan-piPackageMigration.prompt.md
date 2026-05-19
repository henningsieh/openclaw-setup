Phase 1 — Clone the official OpenClaw source
1. Clone the upstream repository into a local scratch directory.
   - `cd /root`
   - `git clone https://github.com/openclaw/openclaw.git /root/openclaw-src`
   - `cd /root/openclaw-src`
   - `git fetch --tags`
   - `git checkout 2026.5.12`
2. Confirm the pinned commit and current package state.
   - `git rev-parse HEAD`
   - `grep '"@mariozechner/pi' package.json`
   - Verify that OpenClaw currently depends on `@mariozechner/pi-ai@0.73.1`, `@mariozechner/pi-agent-core@0.73.1`, `@mariozechner/pi-coding-agent@0.73.1`, and `@mariozechner/pi-tui@0.73.1`.

Phase 2 — Research the upstream package API changes
1. Compare the old and new exported subpaths for each affected package.
   - `npm view @mariozechner/pi-ai@0.73.1 exports --json`
   - `npm view @earendil-works/pi-ai@0.74.0 exports --json`
   - Repeat for `pi-agent-core`, `pi-coding-agent`, and `pi-tui`.
2. Identify source import sites that reference the old packages.
   - `git grep -rn "@mariozechner/pi-" -- '*.ts' '*.js' '*.mjs' '*.cjs'`
3. Record any broken entrypoints or renamed path mappings.
   - For example, old exports such as `./oauth` and `./google` may no longer exist.
   - The new package often uses `./anthropic` or other renamed subpaths.
4. Confirm whether `pnpm.packageExtensions` contains the old package names.
   - `grep -n 'mariozechner/pi' package.json`

Phase 3 — Apply the migration changes
1. Update `package.json` dependency keys and versions.
   - Rename `@mariozechner/pi-ai` → `@earendil-works/pi-ai`
   - Rename `@mariozechner/pi-agent-core` → `@earendil-works/pi-agent-core`
   - Rename `@mariozechner/pi-coding-agent` → `@earendil-works/pi-coding-agent`
   - Rename `@mariozechner/pi-tui` → `@earendil-works/pi-tui`
   - Bump each package to `0.74.0`.
   - Rename `pnpm.packageExtensions` entry from `@mariozechner/pi-coding-agent` to `@earendil-works/pi-coding-agent` if present.
2. Fix source imports to use the new package names and exported subpaths.
   - Update all `import`/`require` references from `@mariozechner/pi-*` to `@earendil-works/pi-*`.
   - Change any old subpath imports to the new supported subpaths based on the exports map.
   - Typical affected paths include auth providers, coding agent integrations, and runtime helpers.
3. Run dependency install and validate the project.
   - `pnpm install --frozen-lockfile`
   - If install fails, inspect the exact export or subpath errors and adjust imports.
4. Run a targeted build or lint to confirm source consistency.
   - `pnpm exec tsc --noEmit` or the repository's canonical build command for the gateway package.

Phase 4 — Build the patched OpenClaw base image
1. Build a local base image from the patched source.
   - `cd /root/openclaw-src`
   - `docker build --no-cache -t openclaw-patched:2026.5.12 .`
2. Verify the image build succeeds and contains the updated packages.
   - Use `docker history openclaw-patched:2026.5.12` if needed.

Phase 5 — Rebuild the local gateway image
1. Set `OPENCLAW_BASE_IMAGE=openclaw-patched` in `/root/openclaw/.env`.
2. Rebuild the gateway image.
   - `cd /root/openclaw`
   - `docker compose build --no-cache openclaw-gateway`
3. Restart the local gateway.
   - `docker compose up -d openclaw-gateway`
4. Verify runtime health.
   - `curl -sf http://localhost:18789/healthz`
   - Confirm the gateway starts without Node package export errors.

Verification checklist
- `package.json` no longer contains `@mariozechner/pi-*` dependencies.
- All source imports now use `@earendil-works/pi-*` and valid exported paths.
- `pnpm install` completes successfully.
- The patched base image builds cleanly.
- The gateway rebuilds and starts successfully.
- The health endpoint returns `{"ok":true,"status":"live"}`.

Notes
- The migration is not a drop-in rename: the new `@earendil-works/pi-*` packages may expose different subpath exports.
- This plan follows the existing local patched image workflow documented in `README.md`.
- If upstream OpenClaw releases a newer official image with the fix, switch `OPENCLAW_BASE_IMAGE` to that image instead of keeping a local patch.

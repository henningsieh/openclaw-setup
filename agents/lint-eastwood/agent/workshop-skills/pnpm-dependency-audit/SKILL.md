---
name: pnpm-dependency-audit
description: "Auditing and applying pnpm dependency updates on a release branch: release-age gate, catalog/overrides, frozen install, prod integration/e2e."
---

# pnpm dependency audit

Use when asked which packages in a pnpm workspace can be updated, or to apply selected updates and verify them against production, especially on a release branch. The audit itself does not change the checkout or install anything.

## 1. Pin the branch head without switching

```bash
git fetch origin <branch>:<branch>
git rev-parse --short <branch>
git rev-parse --short origin/<branch>
git log -1 --format='%h %ci %s' <branch>
```

Check that both SHAs match. If the branch is currently checked out, Git may refuse the ref update; use `origin/<branch>` as the inspection base instead of forcing the local branch. Cite the head SHA and date in the answer.

## 2. Read the release tree in a detached worktree

```bash
git worktree add --detach /tmp/<repo>-release-inspect origin/<branch>
```

Run every registry check in that worktree. This keeps the active branch and working tree untouched. Confirm the worktree head with `git -C /tmp/<repo>-release-inspect log -1 --format='%h %s'`.

## 3. Inventory outdated direct dependencies

```bash
cd /tmp/<repo>-release-inspect
pnpm outdated -r --format json > /tmp/outdated.json
echo "exit=$?"
```

Exit code `1` means outdated packages were found, not that the command failed. `{}` means none under the current release-age gate. `pnpm outdated` reports direct dependencies only; do not present it as a full transitive audit.

## 4. Reveal releases hidden by the release-age gate

pnpm applies `minimumReleaseAge` (24 hours by default) to `outdated` and `update`, so versions published today are omitted from the default result.

```bash
pnpm --config.minimumReleaseAge=0 outdated -r --format json > /tmp/outdated-all.json
```

Compare both files by package name and latest version:

```bash
python3 - <<'PY'
import json
now = json.load(open('/tmp/outdated.json'))
all_ = json.load(open('/tmp/outdated-all.json'))
for key in sorted(set(now) | set(all_)):
    a, b = now.get(key, {}), all_.get(key, {})
    if a.get('latest') != b.get('latest'):
        print(key, a.get('current'), 'now:', a.get('latest'), 'latest:', b.get('latest'))
PY
```

Report the default set separately from the "new but still gated" set. Do not edit `pnpm-workspace.yaml` to disable the gate for an audit; use the CLI override. Cross-check a suspicious package with `npm view <pkg> version` and `npm view <pkg> time --json`; a publish timestamp within 24 hours confirms the gate.

## 5. Map each update to its declaration

```bash
grep -rn --include=package.json -F '"<pkg>"' apps packages package.json
```

Catalog entries live in `pnpm-workspace.yaml`; direct ranges and `overrides` live in manifests. `pnpm outdated` can list the same package twice as dependency and devDependency; merge by package name. A version pinned in `overrides` will not move with `pnpm update`; bump it manually when applying updates.

## 6. Classify and check constraints

Compute the semver delta and call out every major separately. Check peers and engines before calling an update safe:

```bash
npm view <pkg>@<latest> peerDependencies --json
npm view <pkg>@<latest> engines --json
```

A major that passes peer checks still needs its own update and test run. Do not claim compatibility from the version number alone.

When the requester asks to apply the selected updates, continue with sections 7–9; use `lint-warning-remediation/references/dependency-and-ui-library-updates.md` only for related UI-library checks.

## 7. Apply the selected updates

Work on the release checkout itself when the requester wants the branch changed; do not apply in the detached audit worktree. Confirm `git status --short` is clean first.

```bash
git switch <branch>
pnpm --config.minimumReleaseAge=0 update -r --latest <pkg> <pkg> ...
```

`pnpm update --latest` rewrites catalog entries in `pnpm-workspace.yaml` and direct ranges in manifests. It does not move a package pinned in `overrides`; bump each matching override by hand, then resolve the new graph:

```bash
pnpm --config.minimumReleaseAge=0 install
```

Check the manifest diff before continuing: catalog-only packages belong in `pnpm-workspace.yaml`, package-specific packages in their owning manifest, and no unrequested package may move.

## 8. Keep default installs green

The updated lockfile contains versions published inside the 24-hour gate. A plain `pnpm install --frozen-lockfile` fails with `ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION` even though the update succeeded.

Add exact `minimumReleaseAgeExclude` entries in `pnpm-workspace.yaml` for every rejected `package@version`, including transitive packages such as `@next/env`, `@next/swc-*`, `@tanstack/query-*`, and `@vitest/*`. Do not set `minimumReleaseAge: 0`; that disables the policy for everything.

```bash
pnpm install --frozen-lockfile
```

Repeat until the command reports `Lockfile passes supply-chain policies`. The failure output can truncate its list; after adding the visible entries, run again and inspect the remaining `package@version` pairs. Confirm the diff contains only the intended exclusions.

## 9. Build and verify against production

Use this order for dependency changes: unit tests first, then a production build, then integration and E2E against the running production apps. Do not use a dev server for the final runs.

```bash
pnpm run type-check
pnpm run format && pnpm run lint
pnpm test:unit
pnpm run build
GREENDEX_LOCAL_TEST_SERVER=1 pnpm run start
```

Run `start` in a background process and log it. `GREENDEX_LOCAL_TEST_SERVER=1` raises the local auth rate limit for E2E; set it when starting, not when running the tests. `start:prepare` may run migrations and kill existing listeners.

Verify the production listeners before testing:

```bash
ss -ltnp | grep -E ':(3000|3001|3002|4000)\b'
curl -sS http://localhost:3000/api/rpc/health
curl -sS -o /tmp/calc-session.txt -w '%{http_code}\n' http://localhost:3000/api/auth/get-session
```

Require `environment: "production"` in the health response and `200` plus `null` from each app's session endpoint. Then run:

```bash
pnpm test:integration
pnpm test:e2e
```

The test runner reuses the running servers and never starts, builds, or stops them. Report the suite timings and test counts. Leave the production servers running unless the requester asks to stop them; give the ports and offer to stop them.

## 10. Report

- Lead with the branch and head SHA/date.
- For an audit, state that the checkout was not switched.
- Split available updates into "available now" and "published today / gated".
- Use bullets and no tables; group patch/minor separately from major.
- Give current → latest for each package and name the dependent packages.
- For an apply, list the updated packages, the override bump, the exact exclusions added, and the commit.
- State which verification ran and which did not; never imply a build or suite passed when it was not run.
- Save the full matrix to `reports/YYYY-MM-DD-<branch>-outdated.md`.
- For German requests, write German, address the requester with "du", and keep the same bullet-first density.

## 11. Clean up

```bash
git worktree remove /tmp/<repo>-release-inspect --force
git worktree prune
git worktree list
```

Confirm the temporary path is gone. Do not remove a worktree with uncommitted changes unless you created it for this audit. Do not delete or stop production servers that the requester asked to keep running.

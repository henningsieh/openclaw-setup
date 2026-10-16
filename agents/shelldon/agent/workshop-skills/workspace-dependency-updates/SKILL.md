---
name: workspace-dependency-updates
description: "Update pnpm workspace dependencies: enforce app scope, sync the lockfile, install and test with prerequisite-aware checks, then present the diff."
---

# Workspace Dependency Updates

Use when changing package versions in a pnpm monorepo. For agent-skill adoption or Drizzle ORM migrations, use pnpm-agent-skills-adoption instead; for a Coolify preview build, use coolify-preview-deployments.

1. **Establish the repo and Git boundary.** Read the repo AGENTS.md and the scoped workspace instructions; check the current branch, worktree, remote tips and target base. Preserve unrelated edits. If the branch is behind the requested base, report the commits and merge only when authorized. Finish when the exact branch/base and existing changes are known.

2. **Inventory versions and ownership before editing.** Use pnpm outdated -r for candidates, then inspect each package's direct imports, workspace manifest and pnpm-workspace.yaml catalog/overrides. Separate app-owned dependencies from catalog-shared dependencies and Calculator-only packages. An app-only request means update only packages owned by that app: changing a shared catalog changes every importer, including out-of-scope apps. Do not widen the scope silently; ask before a shared-catalog bump when the request is app-only. Preserve deliberate pins/overrides and explain their reach. Finish when every candidate has an owner and impact scope.

3. **Apply through pnpm and let pnpm write the lockfile.** Use the repository's workspace-targeted pnpm --filter <workspace> add <package>@<version> flow for app-owned packages. For shared catalog entries, update the catalog only when workspace-wide impact is authorized, then run pnpm to resolve the lockfile. Never edit pnpm-lock.yaml by hand. Keep catalog and required exact override pins consistent. Inspect the final manifest and lockfile diff, including pnpm policy metadata such as minimumReleaseAgeExclude, which pnpm may rewrite when resolving newly eligible versions. --lockfile-only is not a substitute for a real install before tests. Finish with pnpm install --frozen-lockfile passing after the full install.

4. **Check disk before installing.** Run df -h . and confirm enough space for the install/build; if space is tight, stop and report rather than deleting unrelated caches or artifacts. Finish when the available space is recorded and sufficient.

5. **Verify the resolved install, types and scoped tests.** Run pnpm --filter <workspace> list --depth 0, its documented type-check, and the affected unit tests. Read the test docs before a full suite: this repo's Cost Tracker OpenAPI tests require a running local server at the configured base URL and a migrated disposable/dev database; never point them at production. External-storage tests require the configured Garage/S3 endpoint. Distinguish an assertion/code regression from a missing server or an invalid external-service response; verify the dependency/service path and rerun the failing test in isolation before attributing cause. A failing prerequisite is not green, and do not report the suite as passing. For rotating/shared-state failures in a database-backed suite, follow step 10 of pnpm-agent-skills-adoption rather than duplicating its triage procedure. Finish with exact typecheck/test counts and any environmental blocker.

6. **Keep long checks owned and communicate real status.** Retain the process/session handle for long installs or suites, collect its exit status and final summary, and send concise progress updates while it runs. If a process disappears, inspect its log and process state before calling it cancelled or complete. Never promise a later result without an active wait/watch path. Finish only with a collected result or a concrete blocker.

7. **Show the diff before publishing.** Summarize direct manifest changes, shared-catalog blast radius, lockfile effects and test results. If the user asks to see the diff before commit, leave the changes uncommitted and stop for review; do not commit or push unless explicitly requested. Finish when the diff and its scope are visible and Git state is accurately reported.

Verification: install succeeds with frozen lockfile; resolved versions match the authorized scope; typecheck and scoped tests have collected results; external test prerequisites are stated and not misreported as green; no unrelated workspace dependency was bumped; and commit/push follows the user's explicit instruction.

## Playwright Version Guards in Experimental Code

When updating Playwright in a shared catalog, be aware of version guards in experimental test fixtures:

- The Cost Tracker's `apps/cost-tracker/src/__tests__/e2e/fixtures/artifact-privacy.ts` contains a version guard in `installExperimentalArtifactPrivacy()` that throws if `require('@playwright/test/package.json').version !== '1.63.0'`.
- This guard **only affects experimental hooks** (`installExperimentalArtifactPrivacy`, `experimentalTest`, `experimentalStepPrivacyProbe`, etc.) — the default `test` export and normal test runs are unaffected.
- The experimental hooks are dormant by default (not used by journey specs). The guard prevents accidental activation on untested Playwright versions.
- When updating Playwright in the catalog, update the version check in `artifact-privacy.ts` if the experimental hooks are meant to stay compatible, or document that the experiment is pinned to a specific version.

## Shared Catalog Updates Affect All Apps

- Playwright is used by **both** Cost Tracker (58 E2E tests) and Calculator (multiple E2E suites) — not just one app.
- Updating Playwright in the shared catalog (`pnpm-workspace.yaml` catalog) updates it for **all** apps simultaneously.
- Run typecheck and unit tests for **all affected apps** after a shared catalog bump, not just the requesting app.
- Calculator's E2E suite also uses Playwright (multiple test files import from `@playwright/test` and `@next/playwright`).
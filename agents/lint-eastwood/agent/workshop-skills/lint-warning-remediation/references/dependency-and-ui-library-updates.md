# Dependency and UI-library updates

Use when the user asks to try package or component-library updates before or alongside lint fixes.

## 1. Inventory the workspace

- Read `pnpm-workspace.yaml` for `catalog`, `overrides`, and release-age policy.
- Read every workspace `package.json` that uses `catalog:` or pins a direct version.
- Run:

```bash
pnpm outdated -r --format json > /tmp/pnpm-outdated.json
pnpm --config.minimumReleaseAge=0 outdated -r --format json > /tmp/pnpm-outdated-all.json
```

pnpm applies `minimumReleaseAge` to the first command, so versions published within the gate (24 hours by default) are omitted. Group both results by current/latest and dependency type; report gated releases separately instead of treating them as unavailable. When every available update is patch or minor, a full update is low risk; stop and ask before crossing a major.

## 2. Update and reconcile

```bash
pnpm update -r -L --yes
```

- `pnpm update` rewrites catalog entries and direct ranges, but it does not move versions pinned in the `overrides` block. Bump those manually, then run `pnpm install`.
- Verify:

```bash
pnpm outdated -r --format json
pnpm --config.minimumReleaseAge=0 outdated -r --format json
```

The gated result must be `{}`. If a package remains there, inspect whether an override or a workspace protocol holds it. The default result can be empty while recently published versions still exist; check both before calling the workspace fully updated.

## 3. Re-run lint and type-check before editing app code

Run the read-only lint baseline again. Package updates rarely clear app-level React Compiler or accessibility warnings. Check `ignorePatterns` first: when the UI library directory (for example `apps/*/src/components/ui/**`) is excluded, updating those components cannot change the lint result.

## 4. Preview UI-library component updates

For shadcn:

```bash
apps/<app>/node_modules/.bin/shadcn --version
apps/<app>/node_modules/.bin/shadcn info
apps/<app>/node_modules/.bin/shadcn add <installed-component-list> --diff > /tmp/shadcn-diff.txt
```

Resolve the CLI from the workspace package that declares `shadcn`; the target app may not have its own binary.

- Pass the installed component names from `shadcn info`, not `--all`, so the preview covers the project's files.
- Inspect the diff for changed import conventions, new dependencies, and removed local variants.
- Do not run `add --overwrite` when the diff removes custom variants or changes imports the app does not provide. Apply selected components or defer to a dedicated migration.
- After a CLI bump, re-run the same diff; the CLI version can change templates without changing the component API.

## 5. Adapt policy tests to linter output changes

A linter bump can change diagnostic formatting and break repository policy tests that match one-line output. Run the policy tests directly:

```bash
pnpm exec vitest run scripts/*lint*.test.ts
```

When a test asserts `file:line: severity rule`, split the output into diagnostic blocks and assert the file and rule appear in the same block:

```ts
const diagnostics = output.split(/\n\s*\n/);
expect(
  diagnostics.some(
    (diagnostic) =>
      diagnostic.includes(`${file}:${line}:${column}`) &&
      diagnostic.includes("rule-name"),
  ),
).toBe(true);
```

Keep the assertion tied to both the location and the rule; do not replace it with two independent `toContain` checks.

## 6. Verify and separate commits

- Run `pnpm run type-check`, the affected app's full test suite, and the workspace unit suite; the app suite can include integration and env-entrypoint tests that the unit orchestrator excludes.
- Commit the dependency and shadcn CLI bump separately from the lint fixes so the code changes remain reviewable.

## 7. Report

State which packages moved, whether `pnpm outdated` is empty, the lint count before and after, whether UI components were updated or deferred, and every policy test adapted.

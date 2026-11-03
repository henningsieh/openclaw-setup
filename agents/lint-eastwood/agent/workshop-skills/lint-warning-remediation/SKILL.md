---
name: lint-warning-remediation
description: "Fixing oxlint and React Compiler warnings in a JS/TS repo: optional dependency/UI-library update, baseline, grouped plan, probes, zero-warning verification."
---

# Lint warning remediation

Use when asked to fix lint warnings, clean up lint output, or reduce warnings in a JS/TS or React repo. Work one app or package at a time and preserve the existing lint configuration.

## 1. Inspect the lint setup before running anything

Read the package scripts and the linter config. Note whether the package lint script contains `--fix`, `--fix-suggestions`, or `--fix-dangerously`.

```bash
grep -n '"lint"' package.json apps/*/package.json
sed -n '1,240p' .oxlintrc.json
```

Never run a lint script containing `--fix-dangerously` for the baseline; it rewrites files before there is a plan. Use a read-only invocation instead.

## Dependency and UI-library updates (only when requested)

Check the lint `ignorePatterns` before updating UI components: component-library files are often excluded, so their updates cannot clear app-level warnings. For the pnpm catalog/overrides procedure, shadcn diff workflow, and linter-output policy-test fix, read `references/dependency-and-ui-library-updates.md`.

## 2. Branch from the requested base

```bash
git fetch origin --quiet
git checkout <base> --quiet
git merge --ff-only origin/<base> --quiet
git checkout -b fix/<topic> --quiet
git log --oneline -1
```

Check that the base is the latest remote commit, not a stale local branch. Re-fetch and rebase onto the latest base before pushing or opening a PR; after the rebase, run `pnpm install --frozen-lockfile` and repeat the verification because the base may have moved.

## 3. Capture a read-only baseline

Run from the package directory. Resolve the workspace binary explicitly, or use `pnpm exec` when the binary is not in the workspace root:

```bash
cd apps/<app>
../../node_modules/.bin/oxlint --format=json > /tmp/lint-baseline.json
echo "exit=$?"
```

Confirm the warning and error counts before editing. Treat the exit code as the baseline, not as success: oxlint exits 0 with warnings.

## 4. Group warnings by rule

Grouping by rule exposes one fix that clears several files. Run a small Node pass over the JSON:

```bash
node -e '
const j=JSON.parse(require("fs").readFileSync("/tmp/lint-baseline.json","utf8"));
const d=(j.diagnostics||[]).filter(x=>x.severity==="warning"||x.severity==="error");
const by={}; for(const x of d){const k=x.code||x.severity;(by[k]??=[]).push(x);}
for(const [k,v] of Object.entries(by).sort((a,b)=>b[1].length-a[1].length)){
  console.log(k+" ("+v.length+")");
  for(const x of v) console.log("  "+(x.filename||x.file)+":"+(x.labels?.[0]?.span?.line??x.line));
}'
```

## 5. Write the plan before editing

When the user asks for analysis or a plan first, write a report to the workspace and summarize it in chat. Include per rule: root cause, exact fix, risk, and verification. Include a suppression budget that names every intended per-line suppression and its justification. Do not lower rule severities in shared config to make warnings disappear.

## 6. Probe candidate patterns before touching production files

React Compiler rules reject some idiomatic-looking code. Test the exact pattern in a temporary file inside the lint scope, lint only that file, then remove it:

```bash
cat > src/__lint_probe__.tsx <<'EOF'
"use client";
import { useState } from "react";
export function Probe() {
  const [now] = useState(() => Date.now());
  return <div>{now}</div>;
}
EOF
../../node_modules/.bin/oxlint src/__lint_probe__.tsx --format=default
gio trash src/__lint_probe__.tsx
```

Verified probe results to reuse:

- `react/purity`: lazy `useState` initializers are accepted for `Date.now()`, `new Date()`, and `Math.random()` calls; `useMemo(() => Date.now(), [])` and `useRef(Date.now())` are flagged.
- `react/static-components`: a module-level cache or factory around `motion.create(tag)` is still flagged; only a static component or a documented per-line suppression clears dynamic tags.
- `jsx-a11y`: `role="combobox"` on a button triggers `prefer-tag-over-role`; adding `aria-haspopup` and `aria-expanded` does not replace the role. Removing the role clears the warning but changes the accessible contract, and E2E suites often select `[role="combobox"]`. Before accepting a role removal, run the owning E2E suite; for a select-only combobox whose tests rely on the role, restore the role and add a per-line `oxlint-disable-next-line jsx-a11y/prefer-tag-over-role` with a comment explaining why the button is the combobox.

Delete the probe file before editing real code.

## 7. Apply fixes in low-to-high risk order

Prefer structural fixes over suppressions:

- External stores and mount flags: use `useSyncExternalStore` with a no-op subscribe; a mount flag can use an existing `useHydrated` hook built the same way.
- Non-rendered instances: keep sockets, timers, and observers in `useRef` rather than state.
- Derived values: compute from source state with `useMemo` instead of copying into state from an effect.
- Impure defaults: move `new Date()`, `Date.now()`, and random generation into a lazy `useState` initializer when the value is only needed after mount.
- Reset-on-prop-change: extract the body into a child component and key it by the props that should restart it, so initial state comes from props on mount.
- Ref reads in render: remove ref-current reads from JSX and let a layout effect or event handler write the DOM styles.
- Form libraries: replace render-time `watch()` calls with the library's subscription hook such as `useWatch`.
- Accessibility: use a real element (`<img>`, `<select>`, `<input>`) when the rule suggests one; otherwise use a disclosure button with `aria-haspopup` and `aria-controls`. If the control is a select-only combobox and tests or assistive semantics depend on `role="combobox"`, keep the role and suppress `prefer-tag-over-role` locally instead of changing the selector contract.

## 8. Verify

```bash
../../node_modules/.bin/oxlint --format=default
pnpm --filter <pkg> run type-check
pnpm --filter <pkg> exec vitest run <targeted test files>
git diff --stat
```

Check: zero warnings and zero errors in the read-only run, type-check passes, targeted tests pass, and the diff contains no unrelated files. Run the owning E2E suite when a lint fix changes an ARIA role, accessible name, or selector; unit and type checks do not catch selector-contract regressions. Run the affected app's full Vitest suite, not only the workspace unit suite: the orchestrator may run a narrower file set, while the app suite includes integration and env-entrypoint tests that catch base changes. After rebasing onto a base that changes env manifests, update the app's env-entrypoint expectation before rerunning. If the package lint script uses auto-fix, run it once and confirm the read-only run is still clean and the diff is limited to intended fixes.

## 9. Report

State the branch and base commit, warning count before and after, the rules fixed, any suppressions with justification, what was verified, and what remains. Push or open a PR only when the user asked for it. When the user asks for PR evidence, open the PR against the intended base and add a comment with the head SHA, base SHA, exact commands, and observed results using `gh pr comment <number> --body-file <file>`.

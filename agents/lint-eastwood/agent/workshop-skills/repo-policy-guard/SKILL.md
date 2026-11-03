---
name: repo-policy-guard
description: Adding a repo policy guard for forbidden code patterns such as hardcoded UI copy or test copy assertions: scope, warn-only script, lint wiring, verification.
---

# Repository policy guard

Build a check that reports forbidden code patterns without turning the repository red on day one.

## Steps

1. Read the existing lint wiring before writing code: `grep -n '"lint"' package.json`, then read the app-level `lint` script and every existing `scripts/check-*.ts` guard. Run `pnpm exec oxlint --rules | grep -i <term>` or the equivalent for the repo's linter to confirm no native rule already covers the policy.
2. Read the glob patterns and search terms of an existing guard before assuming it covers the new policy; a test-only guard does not inspect UI source. Create a separate guard when scopes or failure modes differ.
3. Define the target scope and exclusions explicitly: app source glob, generated output, UI primitives, tests, stories. Put the same scope in the script header so the next reader can verify it.
4. Verify the parser API before choosing it: `node -e "const ts=require('typescript'); console.log(typeof ts.createSourceFile)"`. If no AST helper is exposed, add a standalone parser with `pnpm add -D @babel/parser -w` and verify `node -e "console.log(typeof require('@babel/parser').parse)"`. Parse TSX with `parse(source, { sourceType: "module", plugins: ["jsx","typescript"], errorRecovery: true, attachComment: true })`.
5. Implement the detector as a walk over the AST, not regex: flag `JSXText` containing letters; flag string or template literals in visible attributes (`title`, `label`, `placeholder`, `alt`, `aria-label`, `description`, `emptyMessage`, `helperText`); flag literal children in `JSXExpressionContainer`. Allow `t()` calls and dynamic expressions. Skip technical attributes (`className`, `id`, `data-*`, `role`, `href`, `src`), punctuation, numbers, and HTML entities. When walking Babel nodes, skip metadata keys (`loc`, `start`, `end`, `range`, `extra`, comments, tokens, errors) so traversal does not revisit locations or comments.
6. Report `file:line:column`, a compact excerpt, and a total count. Support `--strict` or `--max-warnings` to fail CI later, but keep the default warn-only. Support an inline allow directive such as `// i18n-allow-next-line: reason` for reviewed exceptions.
7. Run once to record the current count, then wire the guard into the normal `pnpm lint` chain in warn-only mode unless the user asks to gate immediately. Do not add a baseline or ratchet unless the user asks; the user wants every warning visible until the count reaches zero.
8. Add a `--staged` mode to the same script and call it from `.husky/pre-commit` as `pnpm run <guard> -- --staged`; keep the full `pnpm lint` invocation on that same script. Read staged paths with `git diff --cached --name-only -z --diff-filter=ACMR`, filter them through the same scope and exclusions, and print a no-staged-files message. Verify with a temporary staged probe: stage a scoped file with a violation, run staged mode, see one warning, then unstage and remove it. Do not reimplement the detector in the hook.
9. Verify the script in this order: default run exits 0 with warnings; `--strict` exits 1 when violations exist; the repo's type-check includes the script; `oxfmt --check` passes; staged mode reports one warning for a staged probe and no files otherwise; fixtures cover valid, invalid, and allow-comment cases. Run the repo linter on the guard and any extracted helper before committing; parent-relative imports and prefer-const failures otherwise surface only in the pre-commit hook.
10. Compare counts across branches without checkout: `tmp=$(mktemp -d); git archive <branch> | tar -x -C "$tmp"; ln -s "$PWD/node_modules" "$tmp/node_modules"; mkdir -p "$tmp/scripts"; cp <script> "$tmp/scripts/"; cd "$tmp" && "$OLDPWD/node_modules/.bin/tsx" scripts/<script>`. Report count, text/attribute split, and top files per branch.
11. State the detector's limits in the final report: variables assigned to copy, call-site strings, and dataflow are not covered unless a second pass is added.

## Rules

- Keep the first version warn-only in the lint chain; a guard that fails on legacy copy is ignored. Switch to `--strict` only when the count reaches zero.
- Report counts per branch and split by detected kind; the user uses the number to size the work packages.
- Put repository-specific commands and paths in the repo's docs or AGENTS.md, not in this skill.

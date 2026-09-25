---
name: conventional-commit-enforcement
description: "Configure or repair Git commit-message validation: align Commitlint with Conventional Commits 1.0.0, distinguish spec rules from team policy, connect a commit-msg hook, and verify without rewriting history."
---

# Conventional Commit Enforcement

Use when a repository wants commit messages checked against
https://www.conventionalcommits.org/en/v1.0.0/. This is a **commit-msg** task, not a
pre-commit formatting/typecheck task. Do not put Commitlint in `pre-commit`.

1. **Inspect before adding tooling.** Read repository instructions, `git status`, the staged and
   unstaged diffs, root manifests/lockfiles, `core.hooksPath`, existing hooks, and recent commit
   subjects. Preserve unrelated index/worktree changes. Do not lint or rewrite historical commits
   unless the user separately requests adoption of the convention.

2. **Choose the narrowest package boundary.** Use the existing root package manager and manifest.
   If the repository has no root Node tooling, create a private, tooling-only root manifest rather
   than coupling commit validation to one nested application. Pin exact compatible versions and
   commit the lockfile. Husky is optional; Git can run a native `commit-msg` hook directly.

3. **Choose spec enforcement or team policy before configuring rules.** For literal
   Conventional Commits 1.0.0 behavior, read `references/spec-aligned.md` and use its minimal
   parser/rules. For a stricter team convention, extend `@commitlint/config-conventional`, inspect
   the resolved preset version, and state its extra restrictions (allowed type enum, lowercase
   types, line limits, and no terminal period). Never describe that preset as the specification
   itself. Commitlint can check syntax mechanically; it cannot decide whether a type is truly a
   noun, whether a scope is meaningful, or whether `feat` versus `fix` is semantically correct.

4. **Connect enforcement.** Install Husky and add `prepare: "husky"`, ignore `/.husky/_`, and add
   an executable `.husky/commit-msg` that runs the detected package manager's local Commitlint
   against `"$1"`. Or set `core.hooksPath` and add a native hook. A config file without a hook or CI
   job is not enforcement. For pull requests, optionally run the same Commitlint from the merge
   base to `HEAD` in CI.

5. **Verify the rule set, then the hook without polluting history.** Pipe or pass representative
   messages to Commitlint: valid feature, fix, arbitrary type, optional scope, `!` breaking marker,
   `BREAKING CHANGE:`/`BREAKING-CHANGE:` footers, body/footer spacing, case variants, and allowed
   long/period-ended descriptions. Confirm intended invalid headers, empty subjects/scopes, and
   missing body/footer separators fail. Then execute the hook against temporary message files and
   inspect `core.hooksPath`; use a disposable clone if a real `git commit` integration test is
   needed. Never create a throwaway test commit on the working branch.

6. **Report enforcement scope.** Name the config, dependency/hook mechanism, accepted message
   shape, historical scope, and how a local hook can still be bypassed. If CI is absent, say that
   enforcement is local only.

Verification: the installed versions and hook path are read back; representative valid messages
pass and intended invalid messages fail; the hook itself returns those outcomes; generated Husky
internals are ignored; unrelated Git state is unchanged; no history rewrite or automatic lint of old
commits occurred.

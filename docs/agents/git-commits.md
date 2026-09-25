# Git commit messages

New commits in this repository follow [Conventional Commits 1.0.0][spec]. The
Commitlint configuration is deliberately aligned to the specification rather
than to the stricter Angular-style `@commitlint/config-conventional` preset.

## Required shape

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Examples:

```text
docs: clarify gateway recovery procedure
feat(git): validate commit messages locally
fix(parser): accept an omitted scope
```

Rules mechanically enforced by the `commit-msg` hook:

- The header has a non-empty type and description.
- A body, when present, starts after one blank line.
- Footers, when present, start after one blank line.
- Commitlint's Conventional Commits parser recognizes the required header,
  `!` breaking-change marker, `BREAKING CHANGE:` footer, and synonymous
  `BREAKING-CHANGE:` footer.

The specification deliberately does **not** restrict the type vocabulary,
require lowercase types, impose a line length, or forbid a period at the end
of the description. Other noun types and mixed-case types are valid. Review is
still needed to ensure that a type is meaningful and that `feat` versus `fix`
accurately describes the change.

## Local enforcement

Install the pinned tooling and activate the hook:

```sh
pnpm install --frozen-lockfile
```

Husky's `prepare` script configures Git's local `core.hooksPath` to `.husky/_`.
Its generated `commit-msg` wrapper calls:

```sh
pnpm exec commitlint --edit <commit-message-file>
```

Validate a message manually with:

```sh
printf '%s\n' 'docs: clarify recovery steps' | pnpm lint:commit
```

The local hook can still be bypassed with `git commit --no-verify`. This setup
does not lint or rewrite historical commits. Merge, revert, and version-tag
commits are handled by Commitlint's default ignore rules; their semantics are
outside the parseable Conventional Commits structure.

[spec]: https://www.conventionalcommits.org/en/v1.0.0/#specification

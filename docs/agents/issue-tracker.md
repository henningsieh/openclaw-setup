# Issue tracker: GitHub

Issues and specs for this repository live in GitHub Issues at
`henningsieh/openclaw-setup`. Use the `gh` CLI for all operations.

## Conventions

- Create: `gh issue create --title "..." --body "..."`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open --json number,title,body,labels,comments`
- Comment: `gh issue comment <number> --body "..."`
- Apply/remove labels: `gh issue edit <number> --add-label "..."` /
  `--remove-label "..."`
- Close: `gh issue close <number> --comment "..."`

Infer the repository from the GitHub remote; `gh` does this automatically inside
the clone.

## Pull requests as a triage surface

**PRs as a request surface: no.**

External pull requests are not included in the triage queue unless this flag is
changed to `yes`.

## When a skill says “publish to the issue tracker”

Create a GitHub issue.

## When a skill says “fetch the relevant ticket”

Run `gh issue view <number> --comments`.

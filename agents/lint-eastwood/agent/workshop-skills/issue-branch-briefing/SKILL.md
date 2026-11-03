---
name: issue-branch-briefing
description: Explaining a GitHub issue or spec with sub-issues against a release branch: read both without checkout, prove open vs started, answer in plain domain terms.
---

# Issue–branch briefing

Explain what an issue asks for and what the named branch actually contains, in the requester's language and density.

## Steps

1. Confirm the repository and the branch tip before reading anything: run `git fetch --all --prune`, `git branch -a --list '*<branch>*'`, and `git log -1 --format='%h %ad %s' --date=iso origin/<branch>`. The branch may exist only on the remote and local `main` may be stale, so cite the exact head SHA and date in the answer.
2. Read the issue as structured data: `gh issue view <n> --json number,title,state,body,labels,comments`. `gh issue view` rejects unknown fields and has no `stateReason`; use `gh api repos/<owner>/<repo>/issues/<n>` when you need `state_reason`. Extract every path named in the body, because the issue usually points at the backlog or design document that defines the open scope.
3. Treat a spec or umbrella issue as a container, not an implementation ticket: read its children with `gh api repos/<owner>/<repo>/issues/<n>/sub_issues --jq '.[] | {number,title,state}'` and take the blocking order from the parent body. A progress count such as `0/4` means zero of four children are closed; it does not mean no work started.
4. Map each child to actual work: run `gh pr list --state all --json number,title,state,headRefName,baseRefName,mergedAt,url`, `git ls-remote --heads origin`, and `git log --all --oneline --grep='#<n>'`. An open PR leaves its issue open even when the branch is complete; only a merged PR closes a child. Before claiming that no branch or PR exists, cite the command that searched all branches and PRs.
5. Read branch content without switching branches or creating a worktree: `git show origin/<branch>:<path>`, `git grep -n '<symbol>' origin/<branch> -- <paths>`, and `git ls-tree -r --name-only origin/<branch> | grep <pattern>`. These keep the checkout clean and still show the exact revision being discussed.
6. Separate implemented from open. Check each open checklist item or deferred section against the branch: find the factory, catalog, or guard it names, then state plainly what exists at the head and what does not. A green earlier wave does not close a later open item.
7. Verify counts against a pinned snapshot or matrix test, not an ad-hoc source grep: a loose pattern such as `grep -c '^  [a-zA-Z].*: {'` also counts non-entry keys and overcounts. Prefer the snapshot's `"status":` lines or run the focused matrix test.
8. Answer in the requested language and density. Lead with a one-line verdict (bug, refactor, cleanup, or missing feature), then 5–7 short blocks with bold lead-ins. Define each domain term in one clause, give one concrete contrast between two current states, list what stays unchanged, and close with one mnemonic line.
9. Ground every non-obvious claim with the branch head plus `path:line` or the command output that showed it. Mark inference as inference.

## Rules

- Keep the briefing read-only: do not checkout, pull, or edit the branch, because a read-only question must not change the workspace.
- For German requests, write German and address the requester with “du”; keep only established domain terms in English (Claim, Partnership, Participation).
- Target under roughly 250 words unless the requester asks for depth: short lines, bullets, no tables, and no paragraph longer than three lines.
- When the issue is about error semantics, state the split explicitly: the server contract keeps a language-neutral `code`/`reason` plus a safe English fallback, and the UI maps `reason` to the active locale with that fallback. Do not localize the error payload, because tests snapshot it and consumers must select on `reason`, not prose.
- Point at the presentation seam by path when recommending localization (for example the module that converts a transport error into display text) and name `getTranslations` for server components and `useTranslations` for client components.
- Never copy issue prose into the answer; restate the behavior in domain terms so the requester can check understanding rather than reread the ticket.
- Check merge ancestry before calling a branch noteworthy: run `git merge-base --is-ancestor <branch> <target>` and omit branches already merged into the target from status lists.
- Do not present a missing parent branch as a gap: a spec or umbrella issue has no implementation branch; only its children do.

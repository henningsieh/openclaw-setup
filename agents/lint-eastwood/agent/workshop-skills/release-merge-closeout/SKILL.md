---
name: release-merge-closeout
description: After a release/integration merge: prove ancestry, map commits/PRs to labeled issues, verify fixes in the final tree, report closable vs open.
---

# Release Merge Closeout

Use when an integration, audit, or feature branch has been merged into a release branch and the requester asks which issues or tickets can be closed, or whether a labeled issue is delivered.

1. Fetch and pin the refs (`git fetch origin --prune`; `git rev-parse origin/<release>`; `git show -s --format='%H %ci %s' origin/<release>`), because the release can move while you analyze. Confirm the named merge is an ancestor: `git merge-base --is-ancestor <merge> origin/<release>` and print the result; a branch that points at the same commit is not proof of ancestry.
2. List candidates by the exact label (`gh issue list --label <label> --state all --limit 100 --json number,title,state,closedAt,url`), because the label defines the review set and mixed open/closed states change the answer.
3. Map commits and PRs to tickets: `git log --reverse --format='%h %ci %s%n%b' <old-release>..<new-release>`, then extract refs with `grep -oE '#[0-9]{2,4}'`. Resolve every ref before treating it as an issue: `gh pr view <n> --json number,state,baseRefName,mergeCommit`; otherwise `gh issue view <n> --json number,title,state,body,labels,comments`. PR and issue numbers share one namespace, so never assume a `#` is an issue.
4. Verify each claimed fix in the final release tree, not in the commit message: `git cat-file -e origin/<release>:<path>`, `git show origin/<release>:<path> | sed -n '<range>p'`, and `git grep -n '<marker>' origin/<release> -- <paths>`. Check a behavior marker such as a transaction, magic-byte sniff, quota constant, vendored route, or metadata count, not only a filename.
5. For every open labeled issue, test its exact acceptance condition against the final tree and cite the evidence as `path:line` or an empty search result. A commit that mentions the issue is not delivery; an untouched app or package proves non-delivery.
6. Separate the result into already closed and now verified, open and untouched, open but partially delivered, and follow-ups whose premise changed. For partial delivery, name the completed half and the remaining half, and keep the issue open.
7. Check for auto-close claims: `git log <old>..<new> --format='%h %s%n%b' | grep -inE 'clos(e|es|ed)|fix(es|ed)? #'`. Direct pushes without close keywords do not change issue state, so a closed issue was closed manually.
8. Report in the requester's language, direct and bulleted: verdict first, then per-issue evidence, then optional close-out comments. Do not close or comment on issues unless asked; when asked for one status comment, post only that comment and link it.

## Rules

- Treat `CLOSED` as a claim to verify, not delivery: closure comments saying `pending merge` or `overrides the merge gate` mean the fix still needed the release merge.
- Verify post-merge follow-up commits separately; they can change an issue's premise without satisfying its acceptance criteria.
- Never infer delivery from a merge commit's file list alone, because conflict resolution can drop or rewrite the branch's changes.

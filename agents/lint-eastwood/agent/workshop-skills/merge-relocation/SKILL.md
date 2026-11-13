---
name: merge-relocation
description: Moving merges that landed on the wrong branch: verify branch stacking, simulate conflicts, back up tips, land the delta, rewind the wrong branch.
---

# Merge Relocation

Use when asked to move a merge or a branch's commits from one target branch to another and remove the wrong merge commit without a revert.

1. Fetch and pin the refs (`git fetch --all --prune`; `git rev-parse origin/<target>` and `origin/<wrong>`), because both sides can move while you plan.
2. Read each wrong merge's parents (`git show --no-patch --format='%H%nparents: %P%n%s' <merge>`), because the second parent is the branch tip that was merged and the first is the base it landed on.
3. Test for stacking before merging (`git merge-base <target> <branch>`; `git log --oneline <target>..<branch>`; `git rev-list --count`). If the log shows commits outside the requested topic, the branch was cut from the wrong base and a tip merge drags that whole base into the target; report the count and the choice between a tip merge, cherry-picking only the topic commits, and merging the base branch itself into the target when that base is a release candidate. Read the base branch's own commits and open issues before offering the third option, because it lands all of its work; after that merge, rewinding the wrong branch does not remove those commits from the target.
4. Simulate each merge in a detached worktree (`git worktree add --detach /tmp/<sim> <target>`; `git merge --no-ff --no-commit <branch>`; `git diff --name-only --diff-filter=U`), because the conflict file list is the real cost signal; abort (`git merge --abort`) and remove the worktree before changing anything real.
5. Save the current remote tips as local backup refs (`git update-ref refs/backup/<name> <sha>`), because rewinding the wrong branch makes its old merge commits unreachable.
6. Land the chosen delta on the target, run the repo's verification, and push the target; then rewind the wrong branch to the parent before its first wrong merge (`git reset --hard <first-parent>`), and force-push with lease (`git push --force-with-lease origin <wrong>`). Never add a revert commit when the requester asked for undo; force-with-lease performs the rewrite and refuses if someone pushed meanwhile.
7. Report old and new tips for both branches plus the verification commands and results.

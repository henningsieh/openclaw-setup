---
name: relocate-wrong-merge
description: Commits or a merge landed in the wrong integration branch and must move: verify base topology, test in a throwaway worktree, then force-reset the wrong branch.
---

# Relocate a wrong merge

Use when a branch was merged into the wrong integration branch and its commits must live in another branch. Remove the wrong merge by rewriting the wrong branch, never by adding a revert commit, when the owner says undo.

## 1. Prove the objects exist

```sh
git -C <repo> fetch --all --prune
git -C <repo> cat-file -t <merge-sha>
```

`rev-parse --verify` can echo a SHA that is not in the object database; `cat-file -t` must print `commit`.

## 2. Read each merge's parents

```sh
git -C <repo> log -1 --format='%H%n%P%n%s' <merge-sha>
```

Record the first parent: it is the branch state before the merge. The second parent is the branch tip that was merged. For consecutive wrong merges, the first parent of the earliest one is the reset target.

## 3. Check the branch base before moving it

```sh
git -C <repo> merge-base <target-branch> <source-branch>
git -C <repo> rev-list --count <target-branch>..<source-branch>
git -C <repo> diff --stat <target-branch>...<source-branch>
```

If the merge base sits on a different integration branch, a literal merge drags that branch's unrelated commits into the target. Report the commit count and file diff to the owner and let them choose a literal merge or a cherry-pick before changing history.

## 4. Test the move in a throwaway worktree

```sh
git -C <repo> worktree add --detach /tmp/relocate-test <target-branch>
git -C /tmp/relocate-test switch -c tmp/relocate-test
git -C /tmp/relocate-test merge --no-ff --no-commit <source-branch>
# or, for only the intended commits:
git -C /tmp/relocate-test cherry-pick -x <commit>...
```

Inspect conflicts and the staged diff. Abort with `git merge --abort` or `git cherry-pick --abort`, then clean up with `git worktree remove --force /tmp/relocate-test`. Never test the move on the real branches.

## 5. Apply and verify

Merge when the source branch is ahead only by the intended commits. Cherry-pick or rebase the intended commits when the base is wrong. Verify before pushing:

```sh
git -C <repo> diff --stat <target-branch>..HEAD
git -C <repo> log --oneline --graph -10
```

Run the affected test suite, then `git push origin <target-branch>`.

## 6. Rewrite the wrong branch

Reset to the first parent of the earliest wrong merge. If legitimate commits sit above the wrong merge, rebase them onto that parent instead of discarding them.

```sh
git -C <repo> switch <wrong-branch>
git -C <repo> reset --hard <first-parent-of-earliest-wrong-merge>
git -C <repo> log --oneline -5
git -C <repo> push --force-with-lease origin <wrong-branch>
```

Before the force-push, check consumers: `git branch -a --contains <wrong-merge-sha>` and `gh pr list --state all --head <wrong-branch>`. A force-push rewrites history for every clone and open PR, so state the rewritten range and confirm once when the owner has not already ordered it.

## 7. Prove the result

```sh
git -C <repo> rev-parse <wrong-branch> origin/<wrong-branch>
git -C <repo> log --all --oneline --grep='<wrong-merge-subject>'
```

The local and remote heads must match, and the wrong merge subject must no longer appear. Report the target branch's new head, the wrong branch's new head, and the test result.

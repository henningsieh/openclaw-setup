---
name: worktree-cleanup
description: Removing local git worktrees or old checkout/evidence dirs on request: recoverable trash removal, worktree prune, verified final state.
---

# Worktree cleanup

## Steps
1. Inventory before touching anything: run `git -C <repo> worktree list` and `ls -d /home/shelldon/_dev/*`. Registered worktrees need a prune later; plain evidence dirs do not.
2. Inspect each target with `git -C <path> status --porcelain` (or `ls -A` for plain dirs). Untracked files are the only content git cannot restore, so name them in the report.
3. Remove recoverably with `gio trash <path>` per target. The `trash`/`trash-put` binaries are absent, and `gio trash` moves the directory to `~/.local/share/Trash/files/<basename>`. Do not use `git worktree remove --force`: it deletes untracked files permanently.
4. Prune the registration: `git -C <repo> worktree prune`, then confirm with `git worktree list`.
5. Remove parent dirs only when empty: `rmdir <parent>`; it fails harmlessly if anything remains.
6. Report each trash path, then update the workspace `AGENTS.md` Project Notes to the new worktree state so later sessions stop citing dead paths.

## Checks
- `git worktree list` shows only surviving checkouts.
- `ls ~/.local/share/Trash/files` contains each removed basename.
- `ls -A <parent>` is empty or the parent is gone.

## Preferences
- Delete only the paths the requester named; never widen to sibling dirs.
- Reply in German bullets: removed paths, their trash locations, and remaining worktrees.

---
name: shared-branch-push
description: Branching from or pushing a shared branch, publishing someone else's tip: verify refs and authorship first, then report the new remote tip.
---

# Shared-Branch Push

Use when asked to push a branch, especially one you did not create or whose tip commit you did not write. Also use before creating a working branch from a shared base.

1. Fetch first (`git fetch origin <base>`), then confirm the local ref equals the remote tip (`git rev-parse <base>` against `git rev-parse origin/<base>`); never cut a branch from a stale tracking ref, because the shared checkout moves under you and everything built on top starts outdated.
2. Verify the worktree is clean (`git status --short` shows nothing) and show tip authorship with `git log -1 --format=fuller <tip>`, because a push publishes whatever the tip is, not what you assume is on it.
3. Compare against the remote (`git rev-list --left-right --count HEAD...origin/<branch>`; check `git branch -r` whether the remote branch exists), and state ahead/behind plus whether the push creates the remote branch, because publishing a new remote branch surprises owners who never asked for one.
4. Push the explicit ref (`git push origin <branch>`) only when a push was requested; a plain branch-creation request stops after step 3 with the branch name, base tip, and a local-only note, because an unprompted remote branch is a publish the owner did not ask for. After an actual push, report the new remote tip hash and what it contains, because the requester decides from that report whether the publish was correct.
5. If authorship is challenged, answer with the author/committer lines and the `git reflog` entries showing only your local moves, because assertions do not settle provenance disputes.
6. Offer leave-as-is, delete-remote (`git push origin --delete <branch>`), or repoint (force-push, destructive: only on explicit approval) when the published tip is not what was wanted, because each remediation has a different blast radius.

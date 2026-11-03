---
name: shared-branch-push
description: Pushing a branch on request, publishing someone else's tip: verify tip authorship and ahead/behind first, then report the new remote tip.
---

# Shared-Branch Push

Use when asked to push a branch, especially one you did not create or whose tip commit you did not write.

1. Verify the worktree is clean (`git status --short` shows nothing) and show tip authorship with `git log -1 --format=fuller <tip>`, because a push publishes whatever the tip is, not what you assume is on it.
2. Fetch, then compare against the remote (`git rev-list --left-right --count HEAD...origin/<branch>`; check `git branch -r` whether the remote branch exists), and state ahead/behind plus whether the push creates the remote branch, because publishing a new remote branch surprises owners who never asked for one.
3. Push the explicit ref (`git push origin <branch>`), then report the new remote tip hash and what it contains, because the requester decides from that report whether the publish was correct.
4. If authorship is challenged, answer with the author/committer lines and the `git reflog` entries showing only your local moves, because assertions do not settle provenance disputes.
5. Offer leave-as-is, delete-remote (`git push origin --delete <branch>`), or repoint (force-push, destructive: only on explicit approval) when the published tip is not what was wanted, because each remediation has a different blast radius.

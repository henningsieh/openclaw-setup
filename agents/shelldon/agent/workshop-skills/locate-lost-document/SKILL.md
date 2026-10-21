---
name: "locate-lost-document"
description: "Owner names an old or missing doc: find the live copy across disk, git history, backups and chat archives, and prove which version is canonical."
---

# Locate A Lost Document

1. **Search by content anchors, not only by the remembered filename.** The owner's remembered
   name is often a nickname, a working title, or the topic rather than the file on disk, so grep
   the distinctive phrases from their request (title line, agent id, project path, error text) in
   parallel with a name search, then read the hits to decide which artifact they mean. Do not ask
   the owner for the exact filename while a content search can still resolve it; finding the
   candidate and naming the alternatives is faster and produces a usable answer. Finish when one
   path is the clear match and the competing candidates are known.

2. **Sweep every local store in one pass before reporting anything.** Name-level and content-level
   hits come from different places, so run them together:
   ```bash
   find /home/<user> -iname "*<term>*" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/codex-home/*"
   grep -ril "<anchor>" <roots> --include="*.md" --include="*.txt"
   ls ~/.openclaw/media/inbound/pasted-text-*   # chat pastes land here
   ls ~/.local/share/Trash/files
   ls /mnt/                                    # backup mounts: openclaw-backup, nextcloud, storagebox
   ls ~/.openclaw/workspace*/                  # per-agent workspaces
   ```
   Check: each root either yields a candidate or is recorded as checked-and-empty in the answer.

3. **Prove the git history before calling a document gone.** A missing file is often present under
   a different name, on another branch, or only in history:
   ```bash
   git log --all --pretty=format: --name-only | sort -u | grep -i "<term>"   # every path ever tracked
   git log --all --diff-filter=D --name-only --pretty=format:"%h %ad %s" --date=short
   git log --all --oneline -S"<term>" --pickaxe-all -- .                     # term in any committed content
   ```
   A pickaxe hit with no matching filename means the term lived inside a file with a different
   name, so follow the commit to that path. For text that was never committed under the expected
   name, scan historical blobs — see `references/exhaustive-sweep.md`. Check: either a path is
   identified, or the answer states that both the path index and the content index came back empty.

4. **Read a rename as the successor, not a deletion.** Trace the path:
   ```bash
   git log --all --follow --name-status --format='%h %ad %s' --date=short -- <path>
   ```
   `R100 <old> <new>` means the document still exists under `<new>`; `D` means it was deleted. When
   every entry is `A`, the file was created once and never edited, so the live copy is the original
   commit content — confirm with `git show <first-commit>:<path> | diff - <path>`. Check: the live
   file matches the commit that introduced it.

5. **Mine the dream session corpus when the text was only ever pasted in chat.** A document the
   owner pasted into a session was often never written to a file; past turns survive on disk under
   `<workspace>/memory/.dreams/session-corpus/YYYY-MM-DD.txt`, one file per day, with lines of the
   form `[<agent>/sessions/<agent>/<sessionId>#L<n>] User: <text>` split mid-sentence. Grep the
   corpus for a distinctive phrase, count the fragments, and reassemble them by their `#L<n>`
   marker. Session search does not cover this corpus, so grep it directly. Check: the fragment
   count is stated and the fragments for one message are ordered by line marker.

6. **Read pruned past sessions through the sanctioned tools, not raw transcript files.** Compressed
   or rotated session files under `agents/<id>/sessions/` are frequently gone, so use
   `sessions_search` for visible sessions and `sessions_history` with the returned `sessionKey`
   and `messageId` for the excerpt, and treat the dream corpus as the archive for anything older.
   Check: every claim about a past session cites a retrieved excerpt rather than a guess.

7. **Report candidates with receipts, the sweep scope, and the differences.** Give the live path
   plus the commit that introduced it, list the checked-and-empty locations, and state explicitly
   how the canonical copy differs from any original paste (renamed ids, edited sections). When the
   original only survives as fragments, offer to reassemble it into a file instead of leaving the
   answer as a promise. Check: the owner can act on the answer without asking a follow-up question.

Verification: the named path exists and is the best match; the git path index, the git content
index, and the local sweep were each actually run; a rename is reported as a successor rather than
a loss; a claimed original paste is either retrieved or described as fragments with its count; the
answer lists what was searched and what was empty.

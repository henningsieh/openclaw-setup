# Exhaustive sweep: every place a lost document can survive

Use when the fast checks in SKILL.md step 2 and 3 come back empty and the owner is certain the
document existed. Work the list in order; each entry names the check that shows it was covered.

## 1. Git: full path index (every path ever tracked)

```bash
git log --all --pretty=format: --name-only | sort -u | grep -i "<term>"
```
Empty means no tracked path ever carried the name — the document may still exist under a
different filename, so continue with the content index.

## 2. Git: full content index (term inside any committed blob)

```bash
git log --all --oneline -S"<term>" --pickaxe-all -- .
```
`--pickaxe-all` widens the diff to all files in the commit, so a term introduced in a commit that
also touched unrelated files still matches. A hit gives the commit; read the file list of that
commit to find the path:

```bash
git show --stat <commit>
```

## 3. Git: blob-level scan (term in a file that was never committed under the expected name)

```bash
git rev-list --all --objects | awk '{print $1}' | sort -u | while read o; do
  [ "$(git cat-file -t "$o" 2>/dev/null)" = blob ] && git cat-file -p "$o" 2>/dev/null | grep -qi "<term>" && echo "BLOB $o"
done
```
Prints the blob id, not a path. Resolve it with `git log --all --find-object=<blob>` to get the
commit and path that carried it. This is the slowest check; run it only when 1 and 2 are empty.

## 4. Git: deleted-file history

```bash
git log --all --diff-filter=D --name-only --pretty=format:"%h %ad %s" --date=short
```
A deleted document is normally still readable from the commit before its deletion:
`git show <commit>^:<path> > /tmp/recovered.md`.

## 5. Dream session corpus (chat text that was never written to a file)

```bash
ls <workspace>/memory/.dreams/session-corpus/          # one file per day
grep -n -i "<anchor>" <workspace>/memory/.dreams/session-corpus/*.txt
```
Lines look like `[<agent>/sessions/<agent>/<sessionId>#L<n>] User: <text>` and are split
mid-sentence. Reassemble one message by sorting the matched lines on the `#L<n>` marker:

```bash
grep "<anchor>" <corpus>/*.txt | sed -E 's/.*#L([0-9]+)\].*/\1\t&/' | sort -n -k1,1 | cut -f2-
```
A session id found in the corpus can also be looked up with `sessions_search` /`sessions_history`
for a cleaner excerpt.

## 6. Inbound media (pasted text and file uploads)

```bash
ls ~/.openclaw/media/inbound/                          # pasted-text-*, selection-comment-*, message-*
grep -rli "<anchor>" ~/.openclaw/media/inbound/
```
Long pastes that the owner sent as a message are stored here as text files, sometimes the only
complete copy of the original.

## 7. Trash and mounted backups

```bash
ls ~/.local/share/Trash/files
ls /mnt/                                               # openclaw-backup, nextcloud, storagebox, volume-*
find /mnt/<mount> -iname "*<term>*" 2>/dev/null
```
Backup mounts can hold archives; search inside them only after the plain find returns nothing.

## 8. Per-agent workspaces and other agent stores

```bash
ls ~/.openclaw/workspace*/
ls ~/.openclaw/agents/*/agent/workshop-skills/
```

## 9. Live state databases

Read past sessions with `sessions_search` and `sessions_history` instead of opening the gateway's
state databases directly — direct inspection of the state directory is refused by the runtime, so
a copy outside it is still not a working route. Session search and the corpus grep in step 5
together cover the same ground.

## 10. Reported scope

The answer must state which of these ten checks ran and which were empty. "Not found" without the
scope reads as a guess; the scope turns it into a checked result.

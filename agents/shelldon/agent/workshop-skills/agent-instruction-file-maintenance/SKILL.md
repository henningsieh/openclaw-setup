---
name: agent-instruction-file-maintenance
description: "SOUL/IDENTITY/AGENTS overlap or a persona edit risks deleting character content: dedupe with proof, restore verbatim, keep a dated evolution log."
---

# Agent instruction file maintenance

Use when bootstrap files overlap, consolidation is requested, a persona file was edited and content went missing, or SOUL.md has to actually evolve.

1. **Map ownership before editing.** Read `IDENTITY.md`, `SOUL.md`, `AGENTS.md`, and `USER.md` in the workspace and write down which file owns what: IDENTITY is the identity card plus operating principles, SOUL is learned lessons, boundaries, and the evolution log, AGENTS is workspace conventions and maintenance loops, USER is durable preferences. Each rule may live in exactly one file.

2. **Establish whether the file was ever customized.** Diff it against the shipped template before describing its history:

```bash
cd ~/.openclaw/workspace
diff /home/shelldon/.npm-global/lib/node_modules/openclaw/docs/reference/templates/SOUL.md SOUL.md
```

An identical file is still factory settings, so the "evolve this file" instruction has never been executed. Report that as the finding instead of claiming the file was maintained.

3. **Prove a block is duplicated before removing it.** Search the survivor for the distinctive sentences, not for the topic:

```bash
cd ~/.openclaw/workspace
grep -nE "Receipts are for grocery stores|Great question|one clarifying question that unblocks" SOUL.md
```

No hits means the block is the only copy, so deleting it is data loss. A short bullet such as "act first" does not preserve a named principle that carries sub-rules.

4. **Move content verbatim; never paraphrase.** Copy the exact block into the target file and delete it from the source in the same edit. When merging, keep the more specific wording — a shorter restatement is a deletion with better manners.

5. **Restore lost content from Git and prove it byte-identical.** For a whole-file restore:

```bash
cd ~/.openclaw
git checkout HEAD~1 -- workspace/IDENTITY.md
git diff --quiet HEAD~1 -- workspace/IDENTITY.md && echo IDENTICAL
```

For a single block, extract it with `git show HEAD~1:<path>` and splice it back with a Python script, then run the same `git diff --quiet` check. Require the exit-status proof; a visual read is not verification.

6. **Verify the split with counts.** The same principle header must appear in exactly one file:

```bash
grep -cE "Agents are executing First|Verify Before Asserting|Push Back When It Matters" IDENTITY.md SOUL.md
```

One file returns the full count and the other returns 0. Nonzero in both is duplication; zero in both is loss.

7. **Make evolution mechanical and announced.** SOUL.md keeps a `## Evolution Log` where every substantive change appends one dated line with what changed and why, and a scheduled monthly review reads it against the last 30 days of `memory/` and appends only genuine lessons. An untouched log is a failure, not stability. Tell the owner what changed and why in the same turn; persona edits are never silent.

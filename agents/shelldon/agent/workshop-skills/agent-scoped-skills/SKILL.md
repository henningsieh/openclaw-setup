---
name: agent-scoped-skills
description: "Install skills for exactly one OpenClaw agent on a multi-agent host, or fix 'the other agent sees these skills too': shared roots, per-agent allowlist, correct visibility fields."
---

# Agent-Scoped Skill Install

Use when asked to make a skill set available to one named agent only, or when skills appear for an agent that should not see them.

1. **Check the shared roots first — install location alone never scopes a skill.** List `~/.agents/skills`. Anything there (source `agents-skills-personal`; the Skills CLI's `npx skills add -g` writes here) is visible to **every** agent using the default state, no matter which workspace fresh copies land in. Leaving the shared copies intact is correct when other harnesses (Codex, Copilot, Pi) consume them; then scoping must be done per-agent in step 3, not by deleting shared files (ask the operator before removing any). Finish when you know which roots hold the skill set and which consumers need them.

2. **Install into the target agent's workspace.** `openclaw skills install <dir> --agent <id> --force` writes `<workspace>/skills/<slug>/`; workspace copies win by precedence over same-named personal ones. For a bulk install from a cloned repo, skills may sit nested (e.g. `skills/engineering/<name>` — resolve the real path with `find <repo> -name SKILL.md`); copying each directory containing a `SKILL.md` into `<workspace>/skills/` is equivalent for local-path installs (they carry no update-tracking anyway) and the skills watcher registers them on the next turn. Finish when the directories exist; do not treat install output as visibility proof.

3. **Exclude the other agents with a final-set allowlist.** `agents.entries.<other>.skills` is the *complete* visible set — it replaces defaults, never merges — so first enumerate what that agent keeps today: `openclaw skills list --agent <other> --json`, take all names except the ones to exclude. Write a JSON5 patch with just that key, validate with `openclaw config patch --file <patch> --dry-run`, then apply. Do not add an allowlist to the target agent for this purpose (an explicit list would freeze its catalog). Finish when the patch is applied (it takes effect without a gateway restart).

4. **Verify after a short delay, on the right fields.** Re-run `openclaw skills list --agent <other> --json` a few seconds later and require `modelVisible: false` **and** `commandVisible: false` for every excluded skill. The first readback can be a stale snapshot showing them still command-visible; wait and re-check before concluding the allowlist failed. Do not judge by `eligible` or `blockedByAllowlist` — both stay unchanged (`true` / `false`) even when the block is effective, and rows remain listed. For the target agent, confirm the skills resolve from workspace source (`openclaw-workspace`). Some skills ship `disable-model-invocation: true` and are slash-command-only by design; check frontmatter before calling a low `modelVisible` count a bug.

Verification: each excluded skill shows `modelVisible: false, commandVisible: false` for every other agent; the target agent lists the skills with workspace source; the retained allowlist still contains that agent's other skills (spot-check a few by name against the pre-change list).

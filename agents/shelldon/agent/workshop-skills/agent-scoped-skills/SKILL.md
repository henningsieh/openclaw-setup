---
name: agent-scoped-skills
description: "Scope a skill to one OpenClaw agent: grant one more via symlink without a second copy, install per-agent, or exclude an agent with an allowlist."
---

# Agent-Scoped Skill Install

Use when asked to make a skill set available to one named agent only, or when skills appear for an agent that should not see them.

1. **Check the shared roots first — install location alone never scopes a skill.** List `~/.agents/skills`. Anything there (source `agents-skills-personal`; the Skills CLI's `npx skills add -g` writes here) is visible to **every** agent using the default state, no matter which workspace fresh copies land in. Without `-g` the CLI auto-detects scope instead (`-y` skips the prompt): run from a project dir it installs project-local, otherwise into the current workspace's `.agents/skills/` (observed: `~/.openclaw/workspace/.agents/skills/`) — workspace-wide, not repo, and no `skills-lock.json` change. After any CLI install, `ls` the landed dir and, when workspace-wide was intended, confirm the repo is untouched (`git status` clean of skill files). Leaving the shared copies intact is correct when other harnesses (Codex, Copilot, Pi) consume them; then scoping must be done per-agent in step 3, not by deleting shared files (ask the operator before removing any). Finish when you know which roots hold the skill set and which consumers need them.

2. **Put the skill in the target's workspace — one copy or one symlink, never duplicate it.** `openclaw skills install <dir> --agent <id> --force` writes `<workspace>/skills/<slug>/`; workspace copies win by precedence over same-named personal ones. To share ONE already-existing skill with another agent without copying it, symlink instead: `ln -sfn <source-skill-dir> <workspace>/skills/<slug>`. A symlink that resolves outside the workspace root is skipped as a containment boundary unless you also declare the source as trusted: `skills.load.allowSymlinkTargets: ["<source-parent-dir>"]`. For a bulk install from a cloned repo, skills may sit nested (resolve the real path with `find <repo> -name SKILL.md`). Finish when exactly one entry (real or symlinked) exists per slug; do not treat install output as visibility proof.

   **To hand over a whole directory of skills, declare it as an extra root instead of copying or
   symlinking each entry.** A sibling agent's `<workspace>/skills/` directory is invisible to
   another agent until it is registered: `openclaw config set skills.load.extraDirs '["<abs path>"]'
   --strict-json`. This adds the directory for every agent on the instance, so pair it with a
   per-agent `skills` allowlist (step 3) when the handover must stay scoped. Verify with
   `openclaw skills list --agent <id>` — the skills must show `ready`; the agent also lists skills
   that its own allowlist excludes, so read the specific names rather than the count.

3. **Set the allowlists — enumerate, then patch; never guess the set.** `agents.entries.<id>.skills` is that agent's *complete* visible set — it replaces defaults and never merges. Read each affected agent's current list first (`openclaw skills list --agent <id> --json`). To *exclude* a skill, write the full remaining set for that agent. To *grant* one (e.g. the shared skill from step 2), append it to the target's existing list — omitting it hides the skill no matter where its file lives, so a target that already has an explicit list must be extended. Do not create a new allowlist for an otherwise-unrestricted agent just to scope one skill; that freezes its whole catalog. Validate with `openclaw config patch --file <patch> --dry-run`, then apply. Finish when the patch is applied (it takes effect without a gateway restart).

4. **Verify after a short delay, on the right fields.** Re-run `openclaw skills list --agent <other> --json` a few seconds later and require `modelVisible: false` **and** `commandVisible: false` for every excluded skill. The first readback can be a stale snapshot showing them still command-visible; wait and re-check before concluding the allowlist failed. Do not judge by `eligible` or `blockedByAllowlist` — both stay unchanged (`true` / `false`) even when the block is effective, and rows remain listed. For the target agent, confirm the skills resolve from workspace source (`openclaw-workspace`). Some skills ship `disable-model-invocation: true` and are slash-command-only by design; check frontmatter before calling a low `modelVisible` count a bug.

Verification: each excluded skill shows `modelVisible: false, commandVisible: false` for every other agent; the target agent lists the skills with workspace source; the retained allowlist still contains that agent's other skills (spot-check a few by name against the pre-change list).

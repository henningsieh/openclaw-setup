---
name: agent-skills-install
description: Installing third-party Agent Skills from GitHub, adding skills to an agent workspace, dry-checking the catalog: scoped install plus file verification.
---

# Agent Skills Install

Install one named skill from a Git repo into the current agent workspace, project-scoped unless the user asks for global.

## Steps

1. Run from the target workspace directory; the install is project-scoped there. Stay project-scoped unless the user explicitly asks for `-g`, because global installs leak across agents.
2. Dry-check the catalog first: `npx skills add <repo> --skill <name> -l`. It lists only and installs nothing, so confirm the exact skill name exists before installing.
3. Install scoped: `npx skills add <repo> --skill <name> --agent '*' -y`. Prefer exact `--skill` names over `--skill '*'`, because bulk installs pull dozens of unrelated skills.
4. Verify registration: `npx skills list --json` must show the skill with `"scope": "project"`, and `skills-lock.json` must list its pinned source and hash.
5. Verify files on disk with `ls -la` (plain `ls -R` hides dot-dirs): expect real copies under `.agents/skills/<name>/` and `agent/skills/<name>/` plus symlinks under `.claude/skills/`. This duplicated layout is the CLI's normal output, not an error.
6. Read the installed `SKILL.md` by direct path and follow its own Usage section before acting, because the file on disk is the authority on how the skill runs.

## Standing preferences

- Report the installed path, scope, and source for each skill; keep the reply to what changed and how it was verified.

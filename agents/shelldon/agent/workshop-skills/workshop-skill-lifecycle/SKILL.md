---
name: "workshop-skill-lifecycle"
description: "Change a Workshop-owned skill: stage a proposal, apply it with owner approval, and recover when the target changes mid-flight."
---

# Workshop Skill Lifecycle

A Workshop-owned skill changes only through a staged proposal. The operator
edits every other skill directly, so never hand-edit a Workshop skill's
`SKILL.md` — stage a full-body proposal instead.

1. **Put supporting files in place first, then stage.** The proposal records a
   hash of the target skill directory. Adding or editing anything under it —
   including only `scripts/` or `references/` — makes a later `apply` fail with
   `Target skill changed after proposal creation; proposal marked stale`. Finish
   when the target directory is untouched since the proposal was staged.

2. **Stage the complete body.** `action=create|update` with `skill_name`, a
   `description` of at most 160 bytes, and the full `proposal_content` — the
   finished text, never a plan or diff. Staging neither publishes nor activates
   the skill. Keep the returned proposal id. Finish when an id exists.

3. **Apply only on explicit owner approval**, passing the id from step 2 and a
   reason. A clean scan is a precondition, not approval.

4. **On `stale`, read the live `SKILL.md` before restaging.** The target may
   already carry the intended change, or a superset written concurrently, in
   which case applying is unnecessary and would overwrite better content. Check
   the live body, confirm every path it names exists, and execute each script
   once; restage only if the goal is genuinely unmet. Establish *what* differs
   from mtime and content — do not attribute a differing file to a particular
   writer without evidence.

5. **Remove superseded proposals.** `reject` accepts only a `pending` proposal
   and errors on `stale`. Once a proposal is stale or replaced, delete its
   directory under the Workshop `proposals/` root. Keep the applied one.

6. **Stop re-encoding a rejected array payload.** When a tool wrapper rejects a
   schema-valid array argument twice — including a minimal one-element probe —
   it is a wrapper limitation, not a malformed payload. Deliver the file with
   normal file tools, keep exactly one copy at the path the skill body names,
   and verify that path resolves. Do not spend further turns re-encoding the
   same array.

Verification: the live body is the intended content; every path it names
resolves; each shipped script runs once; no stale or superseded proposal
remains; no Workshop skill was hand-edited.

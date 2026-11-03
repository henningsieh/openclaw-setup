---
name: spec-issue-publishing
description: Turning a discussed design into a repo spec with native sub-issues: existing main-ticket tracks, blocking order, tracker rules, seams.
---

# Spec issue publishing

Publish a synthesized design as one parent spec issue with child implementation issues, using the repository's own tracker rules.

## Steps

1. Find the tracker rules before publishing: search the repo for `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md` and read them when present. Use their exact commands and label strings; do not ask the user to set up a tracker that the repo already documents.
2. Read the owning glossary and every intersecting ADR, then inspect the current implementation at the target branch. Use the glossary's terms in titles, bodies, and acceptance criteria.
3. Read the installed `to-spec` skill's template when available, and synthesize the conversation without interviewing. Keep implementation decisions at module and contract level, not file paths or snippets.
4. State the test seams in chat before creating issues: name the highest existing seam, any new seam, and the behavior each test observes. Let the requester confirm or correct the seams before publication.
5. Create the parent spec first with the repo's ready-for-agent label: `gh issue create --title "<spec title>" --body-file <body> --label ready-for-agent`.
6. Create each new child issue next, in dependency order, with the same label. Link every existing issue that is a track in the overall specification as a peer child too, using its own database id. Check `gh issue create --help` for a native `--parent` flag; when it is absent, link children through the sub-issues endpoint: create the child, read its database id with `gh api repos/<owner>/<repo>/issues/<child> --jq .id`, then `gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<db-id>`.
7. Verify the hierarchy with `gh api repos/<owner>/<repo>/issues/<parent>/sub_issues --jq '.[] | {number,title,state}'` and every blocking edge with `gh api repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by`, then report the parent and child URLs with one line per issue.
8. Keep each child independently actionable: one vertical slice, explicit acceptance criteria, and its dependency on siblings. Do not copy the whole spec into every child.

## Rules

- Write issue bodies in the repository's issue language, usually English, even when the discussion was in another language; keep domain terms canonical.
- Put the spec's problem, solution, user stories, implementation decisions, testing decisions, and out-of-scope list in the parent; children carry only their slice and acceptance criteria.
- Apply only the triage label the repo maps to ready-for-agent; do not invent extra labels.
- Check `gh label list` before creating issues and create a missing label only on explicit request, using the requester's color and description; keep product or app qualifiers out of titles when a label already carries that dimension, because the filter, not the title, does the grouping.
- When the repo exposes native sub-issues and dependencies, use them instead of task-list comments or `Part of #` prose.
- When an existing issue is a track in the overall specification, link it as a native peer sub-issue and carry its scope through the parent's problem, solution, implementation, and testing sections. A prose mention or linking comment is insufficient because the overall specification is incomplete without that track.
- Encode cross-track order with native `blocked_by` edges: name the root tracks, the convergence point, and the final guard in the parent's blocking-order section. A root track does not wait; a downstream track waits for every track it consumes.
- When the spec merely constrains an adjacent existing issue, record the relationship in prose and repeat the relevant rule in the child that enforces it; do not make it a peer track.
- Report issue URLs and the relationship to existing issues after creation; do not paste full bodies back into chat.

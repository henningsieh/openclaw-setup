---
name: agent-identity-migration
description: "Rename an OpenClaw agent technically, distinguish its ID from display identity, preserve routing/model/session state, and remove stale duplicate entries safely."
---

# OpenClaw Agent Identity Migration

Use when an agent must change its technical ID, not merely its displayed name, or when an old agent entry/path remains after a rename.

1. **Classify the requested name first.** `openclaw agents set-identity` changes only the display identity (`identity.name`, emoji, theme, avatar); it does not change the technical ID, which is the key under `agents.entries` and the `agentId` in bindings. Confirm the distinction with `openclaw agents list --bindings` before editing anything.

2. **Inventory the complete ownership set.** Read `openclaw.json` and record the old/new IDs, `workspace`, `agentDir`, all bindings, per-agent model/auth/memory/skill settings, and any session keys. Search active config and live documentation for the old ID. Do not change model routes, fallbacks, provider auth, or session history as part of a naming task.

3. **Check the supported CLI before improvising.** Run `openclaw agents --help`; this release has `add`, `bind`, `delete`, `list`, `set-identity`, and `unbind`, but no `rename`. `set-identity` is therefore not a technical rename. If no supported migration command exists, use a replacement-agent migration plan and require an explicit backup/rollback point before touching state stores.

4. **Keep workspace bootstrap files readable.** Do not symlink `AGENTS.md`, `SOUL.md`, `IDENTITY.md`, or `USER.md` across workspaces: OpenClaw's workspace loader rejects symlinked bootstrap files (`symlink path component not allowed`). Use a local copy or a supported shared-reference mechanism, and verify with a real agent turn.

5. **Migrate in a reversible order.** Preserve the existing workspace and agent store first; create a dated backup outside the active store, then move/copy to the new paths. Update the config entry and every binding to the new ID, validate JSON, and run `openclaw agents list --bindings`. Keep the old entry until the new agent is healthy and routing is proven. Never delete the old entry before that check.

6. **Validate database ownership before claiming success.** Agent SQLite stores carry an internal owner marker and session keys. A moved database can be rejected as belonging to the old ID, while a newly created store may appear healthy but lose the old transcript history. Check the store's owner metadata, session count, and transcript count; do not silently rewrite owner metadata or discard the old store. If history preservation is required and no supported migration exists, stop with the exact blocker and retain the backup.

7. **Verify both behavior and cleanup.** Require: exactly the intended agent IDs in `agents.entries`; no stale binding; new and old paths match the intended layout; the configured model route is unchanged; the target agent is not degraded; a fresh-session proof turn succeeds; and a real bound-channel round trip succeeds. Only then remove the obsolete entry/path with `openclaw agents delete --force` or another supported cleanup path, and re-run the same checks.

Verification: `openclaw agents list --bindings` shows exactly the intended agents, the old ID has no active config/binding/path references, model/auth settings are unchanged, the target store's ownership and transcript counts are accounted for, and both a fresh direct probe and the real channel path work.

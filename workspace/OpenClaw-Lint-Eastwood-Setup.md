# Handover: OpenClaw Lint Eastwood Agent Setup

**Status:** Implemented and verified (2026-10-21). Isolated agent, model +
credential, Discord round-trip in `#lint-eastwood`, existing routes intact.

**Goal:** stand up a new, isolated OpenClaw coding-buddy agent
(`lint-eastwood`) with its own workspace, seeded with the greendex
TypeScript/Next.js context below, reachable through one dedicated Discord
channel — without touching the existing agents or their channels.

## Result

| Element | Value |
|---|---|
| Agent ID | `lint-eastwood` |
| Display | 🤠🔍 Lint Eastwood – “Go ahead, make my day… and fix that semicolon.” |
| Workspace | `~/.openclaw/workspace-lint-eastwood` (tracked in this repo) |
| Model | `opencode-go/muse-spark-1.3-contributor` + `thinkingDefault: high` (`:high` is not a valid model-ref suffix) |
| Credential | `opencode-go:default` in the agent's own store (`models auth paste-token --provider opencode-go --profile-id opencode-go:default --agent lint-eastwood`) |
| Discord channel | `#lint-eastwood`, ID `1562506964578082890` (created via API, bot has ADMIN) |
| Binding | exactly one peer binding `discord/default` → `channel:1562506964578082890` (no `guildId`: channel-message events carry `guildId=none`) |
| Guild policy | `allowlist`, bot ID `1489545158717477034` in every channel `users`, no `requireMention` (same as `#grow-log`), `allowBots: "mentions"` |
| Tools | `profile: coding` + `alsoAllow: message, discord, group:messaging` |
| Skills | 24-entry allowlist; coding skills via `skills.load.extraDirs: ["~/.openclaw/workspace/skills"]` |
| Heartbeat | none (reactive only); no `HEARTBEAT.md`; no cron jobs |
| `MEMORY.md` | absent by design (shared channel context never loads it; decisions live under `AGENTS.md ## Project Notes`) |

## Fixes found during setup

1. `guildId` in the peer binding never matches channel-message events
   (`guildId=none`); Kalle-Kief's peer-only binding is the working pattern.
2. `bindings` is not hot-reloadable (`kind: "none"` in the reload plan) —
   the runtime picked the binding up on file revision without restart.
3. New agent stores start without provider credentials: the Web-UI showed
   `No provider credential is configured for this model`. Fixed with
   `models auth paste-token` into the agent store (same shape as Kalle-Kief).
4. Bot-authored messages never create inbound turns (adapter self-filter;
   docs `messaging.md`: own inbound events are ignored). Round-trip needs a
   human message.

## Verify

```bash
openclaw agents list --bindings   # lint-eastwood: 1 peer binding; others unchanged
openclaw doctor                   # clean (only historical opencode-go metadata note)
openclaw channels status --probe  # discord connected
openclaw message read --channel discord --target channel:1562506964578082890 --limit 5
```

In `#lint-eastwood`: write as Henning, expect a Lint Eastwood reply with
`muse-spark-1.3-contributor`.

## Rollback

1. Restore config: `cp openclaw.json.bak.20261021-184057.lint-eastwood openclaw.json`
2. `openclaw agents delete lint-eastwood --force`
3. Remove the binding + channel entry (config patch), delete the Discord
   channel, remove `workspace-lint-eastwood/`.

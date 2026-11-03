---
name: sibling-agent-help
description: Need a sibling agent's access, key, or workspace fact; ask it and confirm the answer arrived.
---

# Sibling agent help

Ask another agent on this gateway for something you cannot reach yourself, then prove it answered before acting on the reply.

## Steps

1. Find the target session key with `sessions_list` (pattern `agent:<id>:discord:channel:<channel>` for channel agents, `agent:<id>:main` for mains). Reuse a known key without re-listing.
2. Send one message with `sessions_send` (`sessionKey` + `message`): state what you need, the exact output shape, and that the answer goes back to your session. Record the returned `runId`.
3. Confirm with `sessions_history` (`sessionKey`, small `limit`): look for the sibling's tool calls or text carrying your `runId`. Queued or accepted delivery is not an answer; say pending and wait instead of claiming completion.
4. Apply the answer, then record durable access facts (key paths, host addresses, never secrets or tokens) in the workspace `AGENTS.md` project notes so the next run starts with access instead of asking again.

## Rules

- Never report a sibling's answer until its history shows activity under your `runId`, because accepted delivery alone proves nothing was done.

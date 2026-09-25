---
name: "channel-feedback-reactions"
description: "Reactions missing on a chat channel, no read receipt, or status emojis stuck at 👀: find the gate that suppresses them and verify the fix."
---

# Channel Feedback Reactions

1. **Separate the two symptoms before diagnosing.** An acknowledgement (a 👀-style reaction on the
   inbound message) and the status lifecycle (queued → thinking → tool → done/error) are one feature
   with two layers: "only 👀 appears" and "nothing appears" have different causes. Finish when you
   know which layer is missing.

2. **Name the gate.** Both layers pass the same decision in the Discord plugin:
   `resolveAckReaction(cfg, agentId, {channel, accountId})` yields the emoji (falling back to the
   default `👀`), and `shouldSendAckReaction({scope, isDirect, isGroup, isMentionableGroup,
   canDetectMention, effectiveWasMentioned, shouldBypassMention})` decides whether any reaction
   happens at all. The scope resolves as
   `channels.<channel>.ackReactionScope ?? messages.ackReactionScope ?? "group-mentions"`, and
   `group-mentions` allows a group message only when it was mentioned — so a guild channel with
   `requireMention: false` gets nothing. The status lifecycle reuses that same answer and adds its own
   conditions (`messages.statusReactions.enabled !== false`, plus suppression for tool-only-reply
   sources unless status reactions are explicitly enabled), so no ack ⇒ no lifecycle either. Finish
   when you can name the gate that produces the observed symptom.

3. **Read the instance's authored values.** `openclaw config get messages.ackReactionScope`,
   `openclaw config get channels.<channel>.ackReaction`, `… .ackReactionScope`, and
   `openclaw config get messages.statusReactions`. An unset path means the runtime default applies —
   that is still a real setting, not an absence. Finish when you know whether suppression is authored
   or inherited.

4. **Fix the narrowest scope.** Set the override on the affected channel only
   (`channels.<channel>.ackReaction`, `channels.<channel>.ackReactionScope`) rather than widening
   `messages.*` for every channel. Finish when `openclaw config validate` passes.

5. **Expect a deferred reload.** `openclaw channels status` reports that a channel config reload is
   deferred while active work finishes, and stopping/starting the channel does not publish
   unpublished config. Finish when that warning clears on its own after the active turn ends — do not
   restart the channel or the gateway to force it.

6. **Prove capability and the automatic path separately.** First drive the `message` tool's `react`
   action with add **and** remove for each emoji and require `ok: true` — that proves the API and
   permissions, not the controller. Then send a real message on the channel and observe the reactions
   arrive unprompted, because only that proves the gate now opens. Finish when a real inbound message
   shows the ack and the lifecycle.

A timed-out typing indicator (e.g. `discord typing start timed out after 5000ms`) alongside a
degraded gateway event loop is a separate, transient symptom — never the cause of missing reactions.
Symptoms appearing after a release do not make the release the cause; check config first.

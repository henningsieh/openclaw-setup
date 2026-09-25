---
name: "heartbeat-schedule-setup"
description: "Set up or debug an agent heartbeat (scheduled digest, health check, delivery channel): correct config shape, per-agent scoping, active-hours tick arithmetic, and skip-reason triage."
---

# Heartbeat Schedule Setup

Heartbeat is a system-owned automation job: cadence ticks come from the Automations scheduler (`openclaw cron list --all` shows `Heartbeat (<agent>)`), but all semantics — active-hours gating, delivery routing, prompt, NO_REPLY contract — live in `agents.*.heartbeat` config. Edit config, never the job row.

1. **Scope the block to one agent on multi-agent hosts.** `agents.defaults.heartbeat` applies to EVERY agent; with two agents both would deliver to the same channel. Pattern that verified-clean: set `agents.defaults.heartbeat` to `{"every":"0m"}` (disables recurring cadence for agents without a per-agent block) and put the full block under `agents.entries.<id>.heartbeat`. After the change, `openclaw cron list --all | grep -i heartbeat` must show exactly one `Heartbeat (<agent>)` row — a stale sibling row disappearing is the scoping proof.

2. **Use the right delivery fields.** `target` accepts only a channel id (e.g. `discord`), `owner`, `last`, or `none` — never combine channel+recipient there. The recipient (a Discord channel id like `1489...786`, a Telegram chat id) goes in `to`. The channel must already exist in the channel's allowlist config. Finish when `openclaw config get agents.entries.<id>.heartbeat` reads back `target` and `to` separately.

3. **Active hours are a gate on fixed ticks, not a start time.** `every: "30m"` ticks fire at a fixed epoch-anchored phase (observed: :26 and :56 past each hour) and the anchor is not user-tunable. `activeHours: {start:"06:30", end:"07:00"}` skips ticks outside the window (`cron runs` shows `status: skipped, error: "heartbeat skipped: quiet-hours"`), so the actual run lands on the FIRST tick inside the window — 06:56, never 06:30. To shift the digest time, move `start` to just before the desired tick (e.g. `06:25` → runs 06:26), or tell the user exact-time delivery needs a cron-expression automation job instead. Ticks every 30m inside a 30-minute window still give exactly one daily run. Finish when the expected tick time is understood and stated to the user.

4. **The prompt is sent verbatim, so pin the output format.** Heartbeat runs have no chat context; a vague prompt yields rambling or empty-looking digests. Write an explicit numbered contract: exact steps (which commands to run), and the literal reply shape (line count, prefixes, language, "nothing else"). `isolatedSession: true` runs each heartbeat in a fresh session (cheap, no history) but makes a missing/weak prompt produce confused replies like "I don't see a current task". Set `model` per heartbeat for cost control.

5. **Never force-run the heartbeat job as a test.** `automations run <heartbeat-job> --force` during a live conversation gets deferred (`system heartbeat last` → `reason: requests-in-flight`) and, when it did execute in an isolated session, it ran WITHOUT the morning prompt — posting confused junk to the delivery channel and ending `error: heartbeat failed: agent-tool-failure`. Test by waiting for the scheduled tick, or wake via `openclaw system event --mode now` with explicit text. 

6. **Verify with the right surfaces.** `openclaw cron get <jobId>` — job id from `cron list --all` — shows schedule, `state.lastRunStatus`, `consecutiveSkipped`; `openclaw cron runs <jobId>` lists per-tick finished entries with skip reasons; `openclaw system heartbeat last` shows the latest run's `status` (`sent`/`skipped`), `reason`, delivery `to`, and a content `preview`. A run is proven only when `status: ok` / `sent` appears AND the user sees the message; `skipped: quiet-hours` entries are correct gating, not failures.

Related facts: heartbeat config changes apply without gateway restart ("Change will apply without restarting the gateway"); rows appear/disappear on config reload. `every: "0m"` disables cadence only — event wakes still run.

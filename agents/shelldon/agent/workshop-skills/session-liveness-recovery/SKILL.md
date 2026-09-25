---
name: "session-liveness-recovery"
description: "A chat channel or session stopped replying, or responses hang: prove which layer is stuck, isolate the wedged lane, and name the exact remedy."
---

# Session Liveness Recovery

1. **Read recency per layer before theorising.** `openclaw channels status` prints an `in:` and an
   `out:` age per channel; `openclaw status` adds session rows. A channel that is `connected` with a
   fresh `in:` but a stale `out:` is not the fault — the inbound side is consuming and nothing is
   being produced. Finish when you can name whether the channel, the lane, or the model route is the
   suspect.

2. **Read the dispatch error, not just the symptom.** Grep the gateway log file (its path is printed
   by `openclaw gateway status`) for the affected `sessionKey`, and read the one
   `message processed: ... outcome=error` line per attempt. The observed wedge signature is
   `attempt disposed before transcript write`, repeated at every redelivery of the same message.
   Finish when you have the exact error string and the affected session key.

3. **Counter-test the session store with a direct turn.** Run
   `openclaw agent --agent <id> --session-key <key> --message '<probe>'`. A normal reply proves the
   session row, transcript, model route, and provider credentials are all healthy, which confines the
   failure to inbound dispatch admission — not the channel token, the model, or the store. Finish when
   the direct turn answers.

4. **Look for an update stuck in ingress retry.** The log shows
   `spooled update <updateId> failed; keeping for retry: <reason>`. Finish when you know whether one
   message is cycling in retry. Note that `openclaw channels dead-letters list --channel <name>
   --account default` stays empty while an update is still dying retryably; it lists only terminal
   failures, so read the log line rather than the dead-letter list to see a live retry loop.

5. **Attribute the wedge to a disposed attempt — test the nearest event, never assume it.** Grep
   the log around the *first* failure for the events that dispose an in-flight attempt:
   `admission closed: restart-signal fence`, `received SIGUSR1; restarting`, and the plugin lifecycle
   reload (`applying plugin lifecycle`, `<plugin> was reloaded or disabled`). The attempt lifecycle
   is in-process, so a disposed attempt is not restored for that session and every later redelivery
   fails the same way after a fraction of a second. The nearest preceding event is not automatically
   the cause: confirm whether turns *succeeded* between it and the first failure
   (`session.ended … success`, a delivered reply). A restart followed by successful turns is a red
   herring — neither necessary for the wedge nor sufficient to explain it — so keep the candidate
   that survives this test. Finish when you can name the disposing event that survives, or have
   ruled out every candidate.

6. **Hand the remedy over; never self-restart mid-turn.** The process restart is the action to apply
   for a disposed attempt lifecycle — step 7 is what confirms or refutes that reading. This instance's
   documented path is `sudo systemctl restart openclaw-gateway.service`, run by the operator — never
   start a gateway restart from inside a running turn, because that is how this state is produced.
   Do not judge a restart by process identity: the gateway is a system-scope systemd unit that PID 1
   adopts, so `PPID=1` is normal, and `OPENCLAW_NO_RESPAWN=1` makes even a correct restart
   *in-process* — the PID and `systemd NRestarts=0` stay unchanged. Confirm the cycle from the log
   (`shutdown completed cleanly` … `restart mode: in-process restart` … `gateway ready`). Finish when
   the log shows `gateway ready` after the operator's restart.

7. **Confirm with a real inbound message, not a CLI probe.** Send one message on the affected channel
   and watch the `out:` age in `openclaw channels status`. Finish when the reply arrives and no new
   disposed-attempt error appears after the restart. If a fresh inbound message still fails, the wedge
   was not attempt-lifecycle teardown — return to step 2 and re-read the error instead of restarting
   again.

Verification: `openclaw channels status` shows a fresh `out:` for the affected channel; a real inbound
message received a reply; no new `attempt disposed before transcript write` line appears after the
restart.

---
name: "openclaw-instance-audit"
description: "The owner asks what you can access or where you stand, or a baseline is needed: survey agents, channels, automations, credentials, resources and report standing facts."
---

# OpenClaw Instance Audit

Use when the question is about the whole instance rather than one failing job:
"what do you have access to", "where do you stand", "are we healthy", "what can you
do here". The output is a grounded statement of what is running, what each agent
can reach, and what is broken — with a command output behind every claim.

Read-only first. Fix only what the owner asked to fix, and fix it in a separate,
named step after the survey.

## 1. Frame the instance

```bash
openclaw status
```

One call returns OS, dashboard URL, gateway reachability and service state,
agent count, session count, channel state, heartbeat cadence, backup age and
update state. Read it as the index for every later command.

`openclaw agents list` adds each agent's id, workspace, agentDir, model and
channel routing. `openclaw channels status --probe` returns live per-account
health (`enabled, configured, running, connected, works`) plus inbound/outbound
ages — the probe is what separates "configured" from "actually answering".

Prove the frame with a live probe, not the config file: a channel can be
configured and connected while its last outbound reply is hours old.

## 2. Inventory the automation fleet

```bash
openclaw automations list --all
```

Returns id, name, schedule, next/last run, status with a consecutive-error
count, target channel, and agent. Any `status: error (Nx)` row is a candidate
to diagnose; the count tells you whether it is one run or a streak.

Then, per interesting job:

```bash
openclaw automations show <jobId>            # last error + diagnostic, verbatim
openclaw automations runs --id <jobId> --json # the run history
```

The runs payload is an object with an `entries` array (not `runs`), and each
entry carries `error`, `errorReason`, `model`, `provider`, `runAtIso` and a
`diagnostics.summary`. The `errorReason` classifies the failure
(`auth`, `format`, …) so the next step targets the layer instead of guessing.

Read the *newest* entry first. A fixed job keeps its old `lastError` in the job
state until a succeeding run, so job state is history, not the current verdict —
and the run history is where the current verdict lives.

Route each failure to its specialist instead of re-deriving it here: an
archived-session block and trigger questions belong to
`scheduled-job-trigger-diagnosis`, a missing per-agent provider credential or a
stale catalog id to `model-route-change`, a wedged channel to
`session-liveness-recovery`, and a chat surface issue to
`channel-feedback-reactions`. This skill finds and names the failure; the
specialist fixes it.

## 3. Check credentials per agent, not per host

```bash
openclaw models auth list --agent <agentId>
openclaw models list --agent <agentId> --provider <provider>
```

Each agent owns its own credential store and its own catalog. A provider
working for the default agent proves nothing about a secondary agent, and the
`Auth` column in the model list is the fastest signal of which agent can
actually serve a model. A job bound to a secondary agent that lacks the
provider's credential fails at model selection, not at dispatch — the
`auth` reason code in the run history is the fingerprint.

Never print key values. Read them into a variable, keep them out of command
lines and out of the report.

## 4. Measure the host, because load masquerades as logic bugs

```bash
uptime; free -h; df -h /
ps aux --sort=-%mem | head -8
```

On a small box, load average and swap usage belong in the same report as the
service state: a 4-core host at load 7 with 10 of 15 GB swap in use produces
slow timeouts that look like broken automations. List the top consumers by
name — that names the real hog.

Container state may be visible only through process names when the Docker
socket is not accessible to your user; `ps aux` and `ss -tlnp` then substitute
for `docker ps`. The host's listening ports answer "is it serving" without
container tooling.

## 5. Report standing facts, not a checklist

Give the owner what is true now, grouped by area, each line backed by the
command that produced it:

- what runs, and where the gateway and dashboard live;
- per agent: what it can reach and which credentials it holds;
- every automation that is failing, with the verbatim error and the layer it
  names;
- host resources, stated as observed numbers;
- the one or two things that actually need a decision.

Keep it compact and lead with what is broken. Do not pad the report with
commands you ran that changed nothing, and do not end with a TODO list of
actions you could take yourself — act on what the owner asked for, and say
plainly what remains.

## 6. Close the loop on every repair

A repaired job is proven by a forced run, not by the absence of an error:

```bash
openclaw cron run <jobId> --wait --wait-timeout 8m --json
```

Require `status: ok` and `completionStatus: succeeded`. The error text changes
shape as each layer closes, so a moved error is a new diagnosis, not a finished
fix — keep going until the run succeeds.

Verification: the frame command's output covers every area you reported, each
failing automation carries its verbatim error and reason code, per-agent
credential state is stated separately per agent, host resources are given as
numbers, and every repair ended in a succeeding forced run.

# Backlog TODOs

## Review restored Memory Wiki

The wiki restored from `.openclaw_BAK` passes lint with **0 errors and 457 warnings**.

- Review stale historical claims before treating operational details as current.
- Remove, revise, or clearly mark legacy Docker and QMD material that no longer applies to the native OpenClaw setup.
- Add structured evidence to durable claims where appropriate.
- Re-run `openclaw wiki lint` after cleanup.

## Consider native semantic embeddings

The current builtin memory engine is usable with keyword/wiki search. Later, decide whether semantic (embedding) search would improve fuzzy recall across growing notes and eligible session history.

- Choose deliberately between a hosted embedding provider (cost and text-sharing implications) and a supported local provider (CPU/RAM cost).
- Do not restore the retired QMD backend or its maintenance cron.

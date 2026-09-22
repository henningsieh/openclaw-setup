# Backlog TODOs

## Review restored Memory Wiki

The restored Memory Wiki passes lint with **0 errors and 457 warnings**.

- Review stale historical claims before treating operational details as current.
- Remove, revise, or clearly mark legacy Docker and QMD material that no longer applies to the native OpenClaw setup.
- Add structured evidence to durable claims where appropriate.
- Re-run `openclaw wiki lint` after cleanup.

## Restore Clawfred natively

- Deliberately recreate the `clawfred` agent, its workspace, identity, compatible
  model/authentication, and Discord binding to `#🍴-nutriclaw`.
- Follow the detailed procedure in `~/.openclaw/CONTEXT.md`; do not copy
  legacy Docker runtime state, QMD state, or credentials wholesale.

## Consider native semantic embeddings

The current builtin memory engine is usable with keyword/wiki search. Later, decide whether semantic (embedding) search would improve fuzzy recall across growing notes and eligible session history.

- Choose deliberately between a hosted embedding provider (cost and text-sharing implications) and a supported local provider (CPU/RAM cost).
- Do not restore the retired QMD backend or its maintenance cron.

## Define future privileged access

- Define the least-privilege sudo/group access that `shelldon` needs only when a
  future root-level task requires it; do not grant broad standing access by default.

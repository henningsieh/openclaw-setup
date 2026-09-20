# OpenClaw Native Setup — Agent Guide

This repository documents the native Shelldon OpenClaw instance. Keep this file
short: it is always loaded. The detailed instance history, operational runbooks,
provider/channel/automation facts, and Vault Credential Access domain context
live in [`CONTEXT.md`](CONTEXT.md).

## Always follow

- Treat the live gateway, credentials, agent state, sessions, logs, caches, and
  media as runtime state, not repository content. Keep gateway tokens, provider
  credentials, Vaultwarden bootstrap values, and personal data out of Git and
  chat replies.
- The gateway runs natively as service user `shelldon`, never as root or Docker.
  Use `/home/shelldon` as the working directory for OpenClaw installation and
  package operations.
- Preserve the native architecture. Do not restore Docker-era QMD, caches,
  session exports, credentials, or configuration wholesale. Do not restore
  Clawfred unless explicitly requested.
- Before changing gateway configuration, providers, channels, reverse proxy,
  backups, automations, or security controls, read the relevant sections of
  `CONTEXT.md` and the applicable ADRs under `docs/adr/`.
- Before committing or pushing, inspect `git status` and the staged diff. The
  live `openclaw.json` and runtime state are intentionally ignored.

## Context routing

Read `CONTEXT.md` when a task enters one of these branches:

- **Native operations:** installation, gateway/service management, configuration,
  providers, authentication, channels, reverse proxy, backups, cron, memory,
  migration history, or security.
- **Vault Credential Access:** `vault_fetch`, Vaultwarden, credential retrieval,
  owner approval, use-only responses, encrypted bootstrap credentials, or the
  Bitwarden CLI runtime. Also read the relevant Vault ADRs.
- **Repository maintenance:** tracking policy, GitHub branches, deployment
  assumptions, or a fact whose source is the OpenClaw instance history.

For ordinary documentation or isolated code changes, this guide plus the
relevant ADR is sufficient. If a term or decision is missing from `CONTEXT.md`,
record the gap for domain modeling instead of inventing competing vocabulary.

## Instance anchors

- Host: `ubuntu-8gb-nbg`; public gateway: `https://ai.sieh.org/`; gateway port:
  `18789`; OpenClaw version: `2026.9.5`.
- Repository remote: `https://github.com/henningsieh/openclaw-setup.git`.
  Native work belongs on `native-setup`; remote `main` contains the Dockerized
  setup and remains untouched unless explicitly changed.
- Official OpenClaw documentation links in `CONTEXT.md` use the `.md` suffix.
  When remembered procedures disagree with the installed CLI, verify with
  `openclaw <command> --help` and the current official docs.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for `henningsieh/openclaw-setup`; use the
`gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Use `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and
`wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository. Read `CONTEXT.md` conditionally as routed
above and read relevant ADRs under `docs/adr/`. See `docs/agents/domain.md`.

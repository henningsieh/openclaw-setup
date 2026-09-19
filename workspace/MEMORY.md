# MEMORY.md — Bootstrap and routing

## Role

This file is a compact main-session index, not a knowledge base. The native
Memory Wiki at `~/.openclaw/wiki/main` is canonical for operational facts,
history, procedures, architecture, and domain data. Do not duplicate or maintain
those facts here; update the relevant wiki page instead.

## Retrieval policy

Search the wiki before answering questions about internal services, projects,
previous decisions, unfamiliar proper nouns, or operational configuration. Use
`wiki_search`, `wiki_get`, or `memory_search corpus=wiki`. General knowledge,
current time/weather, and simple reasoning do not require a wiki search.

## Canonical wiki entry points

- Coolify → `entities/coolify-server.md`
- Grocy → `entities/grocy-coolify-service.md`
- PatchMon → `entities/patchmon-service.md`
- MailCow → `entities/mailcow-mail-server.md`
- Telegram bot and command-menu behaviour → `entities/telegram-bot.md`
- NutriTrace / Nutriclaw → `entities/nutritrace-coolify-service.md`
- Hetzner administration → `concepts/hetzner-hcloud-cli-administration.md`
- Clawfred history → search the wiki for `clawfred`; its restored source history
  is retained for a future native agent restoration.

## Native migration decisions

- The restored wiki, including Clawfred and Nutriclaw history, must be preserved.
  It is valid historical and domain context for deliberately recreating Clawfred
  later; do not create the agent or its Discord binding until that work is
  explicitly requested.
- QMD is retired Docker-era infrastructure. Do not restore its backend,
  configuration, models, indexes, cache, sessions, or maintenance cron. Use the
  native wiki and supported native memory facilities instead.
- Consult `workspace/OPENCLAW_SETUP.md` for current native configuration,
  channel policy, backup procedure, and restoration runbooks. It is the source
  of truth for setup details, not this file.

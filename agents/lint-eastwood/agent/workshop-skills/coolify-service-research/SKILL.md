---
name: coolify-service-research
description: Issue asks about a Coolify-managed service, live service config needs read-only check; resolve, inspect, and record primary-source findings.
---

Resolve the service, inspect it read-only, then delegate docs research.

1. Fetch the issue with `web_fetch` and read every repository pointer file it names before touching infrastructure.
2. Locate the service with `list_resources` and filter by `service_type`, project, or environment name; do not trust a `search_resources` name match alone, because managed services are named per environment rather than per software. Confirm with `get_service`, then `list_service_applications` for the running image tag and FQDN, `list_storages` for volumes and mounts, and `list_env_keys` for the config contract (key names only). The check is image plus volumes plus FQDN returned.
3. Verify live state read-only over the SSH access documented in AGENTS.md under Coolify root: `docker ps --filter name=<service>`, `docker volume ls --filter name=<service>`, `lsblk` for block encryption, `docker exec <container> <binary> status`, layout or equivalent show command, `--version`, and read the managed config file. Run read-only commands only and change nothing, because research authorization excludes infrastructure changes.
4. Delegate primary-source documentation to one background subagent following the research skill: version-pinned official docs, source code, and specs only, distinguishing similarly named features; one Markdown file with a source link per claim, unknowns marked explicitly, a comparison of viable approaches with trade-offs, a recommendation scaled to the project, and a verification plan. No infrastructure changes as part of the research.
5. Merge the read-only host evidence with the subagent file and report the solution approach with sources, open questions, and proposed follow-ups.

# Disk Pressure Recovery

Read this only when step 3 of `SKILL.md` sees the Gateway report `ENOSPC`.

1. Inspect `df -h /` and check generated `/tmp/openclaw-plugin-build-*` and `/tmp/openclaw-model-catalog-*` directories with `fuser`. Also size the OpenClaw state temp dir: `du -sh ~/.openclaw/tmp/*` — on this host `~/.openclaw/tmp/plugin-captures` held 2.8 GB of never-disposed captures while the root disk sat at 97%, with the gateway logging `memory pressure: level=warning reason=rss_threshold`. Report the capture backlog with its size and age; whether to remove it is the operator's decision, not a step you take while repairing a memory fault.

2. Remove only those explicit directories that are not in use. Never remove the agent database, WAL/SHM files, or model files.

3. A later cleanup log may report `ENOENT` for a continuation already deleted with those directories; verify the target job state before restoring anything.

4. Finish when the filesystem has useful free space and the Gateway is reachable, then return to step 3 of `SKILL.md`.

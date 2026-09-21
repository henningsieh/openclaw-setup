# Disk Pressure Recovery

Read this only when step 5 of `SKILL.md` sees the Gateway report `ENOSPC`.

1. Inspect `df -h /` and check generated `/tmp/openclaw-plugin-build-*` and `/tmp/openclaw-model-catalog-*` directories with `fuser`.

2. Remove only those explicit directories that are not in use. Never remove the agent database, WAL/SHM files, or model files.

3. A later cleanup log may report `ENOENT` for a continuation already deleted with those directories; verify the target job state before restoring anything.

4. Finish when the filesystem has useful free space and the Gateway is reachable, then return to step 6 of `SKILL.md`.

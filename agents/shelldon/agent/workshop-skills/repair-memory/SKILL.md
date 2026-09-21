---
name: repair-memory
description: Repair memory index/search failures, embedding provider outages, disk-full rebuilds, and Memory Dreaming runs blocked by the model-override trust guard.
---

# Repair Memory

1. **Measure the failure first.** Run `openclaw memory status --agent <id> --deep`, `openclaw config get memory --json`, and `openclaw config get plugins.entries.memory-core --json`. Record the provider, index identity, dirty/indexed counts, embedding readiness, and `subagent.allowModelOverride`; finish only when the failing condition is explicit.

2. **Choose the embedding path.** If the configured remote provider is ready, keep it. Only when indexing fails because the remote embedding endpoint is unavailable or quota-exhausted, switch to the official local provider: read `references/local-embedding-fallback.md` and complete it before continuing. Never retry blindly or fall back silently to FTS-only.

3. **Authorize Memory Dreaming's model override when its log names the trust guard.** Set `plugins.entries.memory-core.subagent.allowModelOverride` to `true`; finish when the config readback shows the boolean under the plugin entry. Do not grant broader permissions or change the configured Dreaming model.

4. **Apply and rebuild safely.** If the provider change requires a restart, let the Gateway drain active work and verify the service returns to `active/running` before continuing. After an interrupted turn, re-check state before repeating any command. Run `openclaw memory status --index --agent <id>` (or `openclaw memory index --force --agent <id>`); finish only when all memory files are indexed, `dirty: no`, vector store/semantic vectors are ready, and the embedding model identity matches the configured provider.

5. **Recover disk pressure before retrying.** If the Gateway reports `ENOSPC`, read `references/disk-pressure-recovery.md` and complete it before retrying anything.

6. **Prove both repairs behaviorally.** Run `openclaw memory search --agent <id> --max-results 3 "<known term>"` and identify the managed job with declaration key `memory-core:memory-dreaming-promotion`. Trigger it once when safe, then verify its `cron get` state is `lastRunStatus: ok` and Gateway logs contain `memory-core: dreaming promotion complete` plus dream-diary entries, with no new `allowModelOverride` rejection. If a CLI wait times out, inspect the job state and logs before retrying; the run may have completed asynchronously.

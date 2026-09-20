---
name: repair-memory
description: Repair memory index or Memory Dreaming failures; restore embeddings and verify model-override trust.
---

# Repair Memory

1. **Measure the failure first.** Run `openclaw memory status --agent <id> --deep`, `openclaw config get memory --json`, and `openclaw config get plugins.entries.memory-core --json`. Record the provider, index identity, dirty/indexed counts, embedding readiness, and `subagent.allowModelOverride`; finish only when the failing condition is explicit.

2. **Choose the embedding path.** If the configured remote provider is ready, keep it. If indexing fails because the remote embedding endpoint is unavailable or quota-exhausted, use the official local provider instead of retrying blindly or falling back silently to FTS-only: install `clawhub:@openclaw/llama-cpp-provider` if `llama-cpp` is absent, set `memory.search.provider` to `local` and `memory.search.fallback` to `none`, then run `openclaw models auth login --agent <id> --provider llama-cpp --method local`. Accept the managed CPU embedding-only setup when prompted; it leaves the chat model unchanged. Finish when `memory status --deep` reports `Embeddings: ready` and the local server endpoints are ready.

3. **Authorize Memory Dreaming's model override when its log names the trust guard.** Set `plugins.entries.memory-core.subagent.allowModelOverride` to `true`; finish when the config readback shows the boolean under the plugin entry. Do not grant broader permissions or change the configured Dreaming model.

4. **Apply and rebuild safely.** If the provider change requires a restart, let the Gateway drain active work and verify the service returns to `active/running` before continuing. After an interrupted turn, re-check state before repeating any command. Run `openclaw memory status --index --agent <id>` (or `openclaw memory index --force --agent <id>`); finish only when all memory files are indexed, `dirty: no`, vector store/semantic vectors are ready, and the embedding model identity matches the configured provider.

5. **Recover disk pressure before retrying.** If the Gateway reports `ENOSPC`, inspect `df -h /` and check generated `/tmp/openclaw-plugin-build-*` and `/tmp/openclaw-model-catalog-*` directories with `fuser`. Remove only those explicit directories that are not in use; never remove the agent database, WAL/SHM files, or model files. A later cleanup log may report `ENOENT` for a continuation already deleted with those directories; verify the target job state before restoring anything. Finish when the filesystem has useful free space and the Gateway is reachable.

6. **Prove both repairs behaviorally.** Run `openclaw memory search --agent <id> --max-results 3 "<known term>"` and identify the managed job with declaration key `memory-core:memory-dreaming-promotion`. Trigger it once when safe, then verify its `cron get` state is `lastRunStatus: ok` and Gateway logs contain `memory-core: dreaming promotion complete` plus dream-diary entries, with no new `allowModelOverride` rejection. If a CLI wait times out, inspect the job state and logs before retrying; the run may have completed asynchronously.

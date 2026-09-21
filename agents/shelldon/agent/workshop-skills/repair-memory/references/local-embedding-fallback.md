# Local Embedding Fallback

Read this only when step 2 of `SKILL.md` finds indexing failing because the configured remote embedding endpoint is unavailable or quota-exhausted. Keep the remote provider whenever it is ready.

1. Install the official provider only if `llama-cpp` is absent: `openclaw plugins install clawhub:@openclaw/llama-cpp-provider`.

2. Set `memory.search.provider` to `local` and `memory.search.fallback` to `none`.

3. Run `openclaw models auth login --agent <id> --provider llama-cpp --method local`.

4. Accept the managed CPU embedding-only setup when prompted; it installs only the server and the embedding model and leaves the chat model unchanged.

5. Finish when `openclaw memory status --agent <id> --deep` reports `Embeddings: ready` and the local server endpoints are ready.

Restart the Gateway after installing or updating the plugin, then return to step 4 of `SKILL.md`.

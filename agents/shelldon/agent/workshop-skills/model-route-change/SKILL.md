---
name: "model-route-change"
description: "Change a default/fallback model route, fix a missing /models entry, or restore a provider absent from one agent’s Control UI model selector: distinguish catalog, agent auth, and route before proving the model live."
---

# Model Route Change

1. **Read the route and hunt for an override first.** `openclaw models status --json --check` gives the
   live route (`defaultModel`, `resolvedDefault`, `fallbacks`, `utilityModel`); read the config too —
   `agents.defaults.model` is the global route, and a per-agent `agents.entries.<id>.model` **wins
   over it**. Finish when you know the effective route *and* whether an override exists.

   **When the user withholds a route change but the route is already wrong, date the change before
   calling it intentional.** A global default can be silently rewritten by an update or migration:
   verified, `agents.defaults.model.primary` flipped from a documented `opencode-go/deepseek-v4.1-flash`
   to `openai/gpt-6-luna` inside a commit titled "finish 2026.9.7 update", contradicting the
   instance's own `CONTEXT.md` ("No OpenAI model remains in any configured default or fallback chain").
   `git -C ~/.openclaw log -S "<model-id>" -- openclaw.json` dates the entry in one call; compare the
   commit subject against the change to decide drift-versus-deliberate. Report the route *and* its
   origin so the user can decide; do not silently normalize it. Finish when the effective route, the
   override state, and (when it looks wrong) the commit that set it are all known.

   **When the user reports that a model "failed" or "didn't take effect", compare the models
   actually pinned to the sessions before blaming the provider.** Every session carries its own
   `model`, independent of the global route and of the other channels: `openclaw sessions list
   --json --limit all | jq '[.sessions[] | {key, model}]'` (the payload is an object with a
   `sessions` array, not a bare list). A failing session that still reports the *previous* model
   means the switch never landed there — a session-selection problem, not a provider, credential,
   or upstream fault, and the model under suspicion may be working fine on another session. Only
   once the pins agree does a provider fault become the live hypothesis. Read the user's error text
   verbatim too: a failed turn is frequently absent from both `sessions_history` and the greppable
   gateway log tail, so when neither retains it, ask for the exact string instead of attributing a
   cause.

   **A session pin outlives a default change AND `/new`.** Verified: after switching
   `agents.defaults.model.primary`, `/new` in a channel still ran the old model because that
   session kept its `modelOverride`/`providerOverride`; a pin-free sibling already showed the new
   default. Do not edit the route again — clear the pin from inside that channel with
   `/model default` (or `/model <provider/model>`); `thinkingLevel` is a separate pin (`/think`).
   Finish when the session reports `modelOverride: null` and the configured default, and a cause is
   either established or explicitly left open pending the error text, not just the global route.

   **When new sessions report thinking `off` although `agents.defaults.thinkingDefault` is `high`,
   read the model's provider thinking profile, then declare the endpoint's real effort ladder.**
   `openclaw gateway call sessions.list --params '{"limit":200}' --json` returns the session's
   `thinkingLevels` and `thinkingDefault`. A profile that exposes only
   `{id:"off",label:"always on"}` has no selectable level, so a configured `high` cannot apply.
   For `opencode-go` models declared `reasoning: true` on `openai-completions`, OpenClaw selects
   that fixed profile when the model entry has no `compat.supportedReasoningEfforts`. Do not stop
   at that observation and do not read `dist/` source for a config question: the official catalog
   is authoritative. Fetch `https://models.opencode.ai/api.json` and read
   `opencode-go.models.<model-id>.reasoning_options` with the exact local model id as the key
   (e.g. `muse-spark-1.3-contributor`, not `muse-spark-1.3` — a wrong key returns null and
   the model only looks missing). Take the `effort` values verbatim (verified:
   `deepseek-v4.1-flash` → `["low","high","max"]`; `muse-spark-1.3-contributor` →
   `["minimal","low","medium","high","xhigh"]`). Write both keys in one batch:
   `compat.supportsReasoningEffort: true` and
   `compat.supportedReasoningEfforts: ["low","high","max"]` on that model entry. Verify with
   `openclaw gateway call models.list --params '{"provider":"opencode-go"}' --json`: the model's
   `thinkingLevels` must include `off`, the declared efforts, and harness `ultra` (`ultra`
   is always appended and is no provider level; `off` only omits the effort), and
   `thinkingDefault` must equal
   the configured default (`high`). The change applies without a gateway restart. Finish when the
   catalog values, the model profile, and the session projection agree; existing sessions keep
   their stored `thinkingLevel` until `/think default` or an explicit `/think <level>` is sent.

2. **Validate the active provider catalog before selecting a fallback.** Run
   `openclaw models list --agent <id> --provider <provider> --json`; `--all` does not escape a
   provider's active static subset. A model named only in `agents.defaults.model.fallbacks` can
   appear in `/models` while still being unresolvable. For a catalog-backed provider, inspect `models.providers.<id>`: an authored
   `models` array can replace the plugin's runtime catalog with that subset. If the intended provider
   models are missing from a route/catalog task, remove that obsolete static override, refresh
   discovery, and re-list the provider **before** changing the route. If you intentionally hard-code
   a provider subset to fit a channel picker limit, keep every intended selectable model in that provider array and verify its
   count; do not confuse the subset with the primary/fallback route. For route/catalog tasks,
   finish when every intended primary/fallback is in the active provider list and the catalog count
   matches the intended picker surface; for an absent UI provider, follow the auth branch below.

   **When the user reports a model missing from the channel `/models` picker right after it was
   added**, prove the gateway-side view before treating the add as failed: `openclaw agent --agent
   <id> -m "/models <provider>"` returns exactly what the picker serves. Two benign causes explain
   most complaints: the interactive picker paginates ~8 models per alphabetical page, so a
   late-alphabet entry sits on the last page; and a degraded reply (`<provider>: checking
   models…`) means the running Gateway's prepared catalog awaits its next restart after
   `openclaw models refresh` while the authored config is already live and directly selectable.
   Never re-add the entry or restart the Gateway on the channel complaint alone. Finish when the
   probe lists the model id or an absence it confirms.

   **When a provider is entirely absent from one agent’s Control UI selector**, read
   [control-ui-provider-absent.md](references/control-ui-provider-absent.md) and follow it. Finish
   only when the affected selector shows them.

   **When one agent's model call fails while the default agent's call to the same provider
   succeeds**, read [secondary-agent-provider-gaps.md](references/secondary-agent-provider-gaps.md).
   That gap is two-layered — the agent's own credential store and the agent's own model
   catalog — and the error text changes shape as each layer closes, so diagnose the new
   error instead of re-reporting the old one.

   **When a catalog model id 404s at inference or the user asks to audit a provider's ids,
   compare the catalog against the provider's own models endpoint before editing.** Fetch the
   authoritative list (NVIDIA: `GET https://integrate.api.nvidia.com/v1/models` with the stored
   `nvidia:default` api_key read from the agent's `auth_profile_store`, kept in-process and never
   printed; opencode-go: `https://models.opencode.ai/api.json`) and diff it against
   `openclaw models list --provider <id>`: entries present locally but absent upstream are wrong
   (verified: `z-ai/glm-5-3-flash` 404d while `z-ai/glm-5.3-flash` is the real id). Repair explicit
   `models.providers.<provider>.models[].id` entries with `openclaw config set` (dry-run first)
   and prove the new id live with `openclaw infer model run --model <provider/model> --thinking off
   --prompt "Reply with exactly: ok" --json`. Finish when the id exists upstream, the catalog shows
   no duplicate, and the probe returns the exact string.

3. Change only requested primary, thinking and fallback fields; preserve existing fallbacks unless the user explicitly changes them. Inspect `agents.defaults.model`, `agents.defaults.thinkingDefault`, and each `agents.entries.<id>` first. Remove a per-agent `model` or `thinkingDefault` override when the requested value should inherit the shared default. For a requested Codex route, consult the installed OpenAI runtime docs and model catalog: use the canonical `openai/<model>` reference and, when native Codex is required, set `agents.entries.<id>.models["openai/<model>"].agentRuntime.id` to `codex`.

   For an atomic multi-agent change through the running Gateway, first use `gateway` `config.schema.lookup` on each affected path to verify it hot-applies, then read `gateway` `config.get` for a current `hash`. Submit a JSON merge patch with `openclaw gateway call config.patch --params '<JSON>' --timeout 60000 --json`, where the JSON object has `baseHash` equal to that hash and `raw` equal to the serialized partial patch; use `null` for an override that must be deleted. Verify `ok`, `changedPaths`, and `restart` in the response, then reread the config. Respect a no-restart instruction and do not commit when the user requests a preview first.

   Verify each agent with `openclaw gateway call models.list --params '{"agentId":"<id>"}' --json`: the row tagged `default` must have the expected provider/model, `thinkingDefault`, availability, and runtime. For changed routes, use `openclaw infer model run --agent <id> --gateway --prompt 'Reply with exactly ROUTE_OK' --json`; require `ok`, the expected provider/model, and exact output with no fallback attempts. This tests the Gateway's raw model route, not the existing chat session. Check existing session selections separately and leave explicit overrides untouched unless requested.

   **Write every path of a multi-field change in one call, and confirm the provider id is current.**
   Chained `openclaw config set <path> <value>` calls each re-read the file, so a concurrent writer
   makes each link fail with `The config file changed while this command was writing (config changed
   since last load), so nothing was changed` — observed three times in a row, losing the whole chain
   including the links that would have succeeded. Build a JSON array of `{"path": …, "value": …}`
   objects in a temp file and issue a single `openclaw config set --batch-file <file>`; verified to
   report `Updated 3 config paths.` Also prefer that over replacing a whole subtree with a merged blob
   (`config set agents "$(cat merged.json)"`), which rewrites the full file, emits harness noise, and
   can be killed mid-run. A rejected model reference is a provider-id problem, not a routing one:
   `Unknown model: openai-codex/gpt-6-luna. "openai-codex" is a legacy provider ID` means the id predates
   the current format — take the provider from `openclaw models list` (`openai/gpt-6-luna`) and retry;
   confirmed live afterwards when a session reported that model. Finish when the batch reports the
   expected path count and a readback shows the intended values.

4. **If changing a route, never point a per-agent override at a catalog-only model.**
   That write can fail with
   `Unknown model: … no matching models.providers["<provider>"].models[] entry`. Remove the override
   with `openclaw config unset agents.entries.<id>.model` so the agent inherits the global route
   instead of duplicating it. Finish when the agent entry carries no `model` key.

5. **Separate route from catalog visibility.** `agents.defaults.models` is not the primary/fallback
   route, but an authored map can act as a model visibility/allowlist register for `/models`; omitting
   it can expose the provider's broader native catalog. Never populate it with only the primary and
   fallback when the user wants a larger selectable catalog. For a deliberate hard-coded catalog,
   keep the complete intended model set in the provider's `models.providers.<id>.models` array and
   synchronize any visibility map with that full set, or remove the visibility map and accept native
   discovery. Finish when the route comes from `agents.defaults.model` plus the per-agent override,
   and picker visibility comes from an intentional, complete catalog rather than an accidental
   two-model map.

6. **Prove the route with a fresh session, not the current one.** Run
   `openclaw agent --agent <id> --session-key <new-key> --message 'Reply with exactly: ROUTE-PROOF-OK'
   --json` and read `terminalReceipt` — `requested` and `effective` provider/model must match, with
   `rerouted: false`. For a visibility/auth-only repair, add `--model <provider/model>` to test
   an intended selectable model without changing the configured default. Use a **new** session key:
   an existing session can carry its own model pin, so a turn there may still show the old model
   and mask the result. Finish when the probe returns the exact string on the intended provider
   and model.

   **When the probe runs from inside an agent session, use the `sessions_send` tool with
   `agentId` instead of the CLI.** Both `openclaw agent --agent <id> -m ...` and
   `openclaw gateway call sessions.send` are refused from an agent exec with
   "Gateway agent from agent exec would lose inter-session attribution", so the CLI cannot serve
   as the probe there. `sessions_send` with `agentId` returns the reply and the `sessionKey` it
   used; a turn that lands in `agent:<id>:main` is the main session, which has no channel target
   and therefore reports `delivery.status=skipped` even though the model call succeeded.

Verification: the affected agent’s selector shows the intended models (and its auth profile
is healthy when auth was missing); `openclaw models list --agent <id> --provider <provider> --json`
contains them; `openclaw models status --agent <id> --json --check` reports unchanged defaults for
a visibility-only repair or the intended route for a route change; the fresh-session probe returns
the exact proof string with `rerouted: false` and the intended provider/model.
`openclaw models status --probe` is unusable while the Gateway runs — it refuses
with "Stop the Gateway first"; do not stop the Gateway to run it.

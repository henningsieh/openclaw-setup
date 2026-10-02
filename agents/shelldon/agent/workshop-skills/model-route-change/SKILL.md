---
name: "model-route-change"
description: "Change a default/fallback model route, fix a missing /models entry, or restore a provider absent from one agent’s Control UI model selector: distinguish catalog, agent auth, and route before proving the model live."
---

# Model Route Change

1. **Read the route and hunt for an override first.** `openclaw models status --json --check` gives the
   live route (`defaultModel`, `resolvedDefault`, `fallbacks`, `utilityModel`); read the config too —
   `agents.defaults.model` is the global route, and a per-agent `agents.entries.<id>.model` **wins
   over it**. Finish when you know the effective route *and* whether an override exists.

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
   cause. Finish when the session pins are known and a cause is either established or explicitly
   left open pending the error text.

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

   **When a provider is entirely absent from one agent’s Control UI selector**, do not equate
   `models list` rows with selectable, authenticated models. Compare `openclaw models status
   --agent <id> --json --check` and `openclaw models auth list --agent <id> --provider
   <provider> --json` for both agents. If only the affected agent lacks an OpenAI OAuth profile,
   use `openclaw models auth login --agent <id> --provider openai --device-code` (without
   `--set-default`), have the owner complete the short-lived device approval privately, then
   recheck its profile status and the UI. `auth activate` selects a saved profile *within* the
   target agent store; it cannot adopt another agent’s profile. Do not copy agent SQLite stores,
   change a shared default, or restart solely because the login warns that Gateway auth refresh
   was unconfirmed: first check whether the actual UI now lists the models. Finish only when the
   affected selector shows them; CLI catalog metadata alone is insufficient.

3. **Only when a route change was requested, set primary and fallbacks through the CLI.**
   `openclaw models set <provider/model>`, then
   `openclaw models fallbacks clear` and `openclaw models fallbacks add <model>` per entry. A
   `not in the local model catalog` warning is not proof that the route will work; run a direct probe
   before relying on it. Finish when `openclaw models fallbacks list --json` shows exactly the intended
   list and each model remains listed by its provider.

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

Verification: the affected agent’s selector shows the intended models (and its auth profile
is healthy when auth was missing); `openclaw models list --agent <id> --provider <provider> --json`
contains them; `openclaw models status --agent <id> --json --check` reports unchanged defaults for
a visibility-only repair or the intended route for a route change; the fresh-session probe returns
the exact proof string with `rerouted: false` and the intended provider/model.
`openclaw models status --probe` is unusable while the Gateway runs — it refuses
with "Stop the Gateway first"; do not stop the Gateway to run it.

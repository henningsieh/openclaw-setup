---
name: add-model-to-provider
description: "A model the user wants to use is not in `openclaw models list` — stealth or promo models just announced by a provider: discover the real model id, append it to the existing provider's models array, prove the live route."
---

# Add A Model To An Existing Provider

Use when the user asks to make a named model available through an already-configured provider (for example a "stealth" or free-promo model announced on social media) and the hosted catalog does not list it yet. Adding a whole provider with new credentials is different work.

1. **Prove the provider exists and the model is genuinely absent.** `openclaw models list --agent <id> --plain` (or `--provider <id> --json`). Finish when you can name the provider and confirm the model id is missing. Do not wait on or restart for a catalog: `openclaw models refresh` reports the running Gateway applies its result only "after its next restart", and a refresh generated after the announcement still omitted the model (verified: 1065-model refresh, `models list --all` still zero matches).

2. **Confirm the provider's auth is already installed.** `openclaw models auth list --agent <id>` shows a `<provider>:…` profile. A config path such as `models.providers.<id>.apiKey` may read "valid but unset … runtime default applies" while `--json` shows `resolved-elsewhere` — that is the auth store supplying it, not a missing key. Never touch credentials to add a model. Finish when an existing profile is named.

3. **Discover the canonical model id from the provider's own docs or API, never by guessing.** OpenCode Zen, for example, publishes a table at `https://opencode.ai/docs/zen/` whose "Model Id" column is the path segment (e.g. `space-bunny-free`) and whose Endpoint column shows `/chat/completions` — the same openai-compatible route the existing provider `baseUrl` already serves, and stealth/free promo models share that account's auth with no extra setup. Finish when you can name the exact id, context window, and input modalities.

4. **Append to the provider's authored `models` array — never replace it.** Model resolution for these providers uses the provider's `models.providers.<id>.models[]` array as the catalog: an id absent from the array is unresolvable even when the endpoint serves it, and an id present is live without a restart. Read the current array (`openclaw config get models.providers.<id>.models --json`), extend with `jq` by one entry shaped exactly like its siblings (`id` = `<provider>/<model-id>`, `name`, `input` modalities, `contextWindow`, `reasoning`, `cost` zeroes, `maxTokens`), validate with `openclaw config set models.providers.<id>.models '<json>' --strict-json --dry-run`, then run the same command without `--dry-run`. Expect "Change will apply without restarting the gateway". Finish when a config readback shows the new id and every previous id still present.

5. **Prove the live route before announcing success.** `openclaw agent --agent <id> --model <provider>/<model-id> -m "Reply with exactly: PROVIDER-PROOF-OK"` and require the exact string. A model that only resolves from config is not a proven route. Finish when the probe returns the string verbatim; otherwise report the exact error and separate id/endpoint mistakes from auth ones.

Do not change the default route or fallbacks as part of this task; the user opts into that separately (`model-route-change` skill governs routes and picker visibility).

Verification: the step-5 probe returned the exact proof string; the provider array still contains every previously listed id plus the new one; no credential path or gateway restart was used.

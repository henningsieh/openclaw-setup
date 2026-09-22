# Refused Call Triage

Read this only when a `vault_fetch` call returns no usable credential.

1. **The guard is a code check, not a config policy.** `before_tool_call` in
   `plugins/vault-access-broker/src/index.ts` runs `isShelldonTurn`, which is
   exactly `context.agentId === "shelldon"`. Any other agent is blocked with
   `Vault Access Broker is available only to Shelldon.` No config flag widens
   it; report the agent mismatch instead of hunting for one. Shelldon turns are
   never blocked by sender, channel, or session type.

2. **A Shelldon call always needs the approval, not a special turn.** Every
   `vault_fetch` call from Shelldon requests a one-time `Retrieve login
   credential` approval (allow-once / deny) regardless of requester, channel, or
   session type, including cron, heartbeat, background, and subagent turns. A
   missing, denied, timed-out, or unavailable approval route fails closed; do
   not retry around it or substitute the CLI.

3. **Confirm the tool is granted to the agent at all.** Exposure comes from
   `agents.entries.shelldon.tools.alsoAllow` listing `vault_fetch`. The optional
   tool is absent from the agent catalog until that entry exists, and a rendered
   tool list can omit optional plugin tools — call the tool rather than
   concluding availability from a list. Finish when the grant is present or you
   have reported it missing.

4. **`Vault Access Broker: is not provisioned` is a runtime problem.** The
   gateway process is missing `CREDENTIALS_DIRECTORY`,
   `VAULT_ACCESS_BROKER_BW_BIN`, or `VAULT_ACCESS_BROKER_SERVER_URL`; the broker
   was never usable in that process. Send it to
   `docs/runbooks/vault-access-runtime.md`; a retry cannot fix it.

5. **Never infer success from the marker text.** The `tool_result_persist` hook
   rewrites every `vault_fetch` result — success and failure alike — to
   `[Vault Access Broker Credential Response redacted]`, so the persisted marker
   alone never proves a fetch succeeded. Confirm the downstream login actually
   worked instead.

6. **Finish** when the named login is retrieved for the downstream use, or when
   you have reported the specific unmet condition from steps 1-4 instead of
   retrying blindly.

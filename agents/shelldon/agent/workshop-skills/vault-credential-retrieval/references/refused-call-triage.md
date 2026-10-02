# Refused Call Triage

Read this only when a `vault_fetch` call returns no usable credential.

1. **The capability grant is the agent's tool policy.** Shelldon and Kalle Kief
   are the Authorized Agents under ADR 0001. Each needs an explicit effective
   `vault_fetch` allowlist entry. The broker has no duplicate hard-coded agent
   guard, and `approvals.plugin.agentFilter` is not a capability ACL. Report a
   missing grant instead of widening policy or bypassing approval.

2. **Every call needs approval, not a special turn.** Every `vault_fetch` call
   requests a one-time `Retrieve login credential` approval (allow-once / deny)
   regardless of requester, channel, or session type, including cron,
   heartbeat, background, and subagent turns. A missing, denied, timed-out, or
   unavailable approval route fails closed; do not retry around it or
   substitute the CLI.

3. **Confirm the tool is granted to the requesting agent.** Check that agent's
   effective tool policy, normally
   `agents.entries.<agent-id>.tools.alsoAllow: ["vault_fetch"]`. The optional
   tool is absent from the agent catalog until explicitly allowed, and a
   rendered tool list can omit optional plugin tools. Finish when the grant is
   present or you have reported it missing.

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

6. **A failed sync is not a lookup result.** Before every lookup the broker
   runs `bw sync`; a CLI failure ends retrieval and still attempts the final
   lock. Report the failure without reading `state/data.json`, returning stale
   cached values, or invoking the private CLI. Runtime verification belongs in
   `docs/runbooks/vault-access-runtime.md`.

7. **Finish** when the named login is retrieved for the downstream use, or when
   you have reported the specific unmet condition instead of retrying blindly.

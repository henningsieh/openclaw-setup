---
name: "vault-credential-retrieval"
description: "Asked for a login, credential, or authentication: call vault_fetch, handle the owner approval, never echo the secret."
---

# Vault Credential Retrieval

1. **Name the downstream login before calling the tool.** Identify the exact Vault Item name and the site or form that will consume the credential. Finish when both are known; when the user gave no item name, ask once instead of guessing.

2. **Call `vault_fetch` with that item name.** Pass `itemName` exactly as the Vault Item is named. Finish when the call returns a Credential Response with `username` and `password`, or a `Vault Access Broker:` error.

3. **Treat the approval prompt as the owner's decision.** Every call raises a one-time Retrieval Approval titled `Retrieve login credential` (allow-once / deny) routed to the owner. Finish when it is approved once; a deny, timeout, cancellation, or unavailable approval route ends the attempt failed — report it and stop, with no CLI fallback.

4. **Consume the credential in the same turn.** Use the returned username and password to complete the downstream login immediately. Finish when the login completes; the persisted tool result keeps only `[Vault Access Broker Credential Response redacted]`, so a later turn cannot recover the values.

5. **Keep the credential out of every reply surface.** Never repeat the username or password in chat, channel progress, status lines, memory files, or notes. Finish when no output you produced contains them; refer to it as "the fetched login" instead.

6. **Resolve lookup errors by correcting the name.** `Vault Item not found` means the name is wrong — ask for the exact name. `ambiguous Vault Item lookup` means several items matched — ask which one, then retry with its exact name. `Vault Item is not a username-and-password login` means the item cannot serve a login. Finish when a retry returns a Credential Response, or you have told the user why it cannot be fetched.

7. **Keep retrieval in an interactive owner-facing Shelldon turn.** The broker serves only the `shelldon` agent and refuses cron, heartbeat, background, subagent, and unverified-requester contexts. Finish when the fetch happens in an interactive Shelldon turn; when a scheduled or delegated job needs a login, report that it cannot fetch and hand that step back to the owner.

8. **Retrieve only through the tool.** Invoke `vault_fetch`; never call the Bitwarden CLI or the private absolute `bw` path by hand, and never construct an approval workaround. Finish when the only retrieval evidence is the normal OpenClaw approval and session record.

Verification: confirm the downstream service accepted the credential, that no reply, progress line, or message contains the username or password, that the persisted tool message shows only the redaction marker, and that exactly one approval appears in the session record.

Reference: `vault_fetch` (snake_case) is the tool name; `vault-fetch` is only the legacy script name. The parameter is `itemName`; the lookup prefers an exact name match and accepts a suggested candidate only when it is the sole match. A `Vault Access Broker: is not provisioned` error means the gateway runtime (server URL, CLI binary, or encrypted credentials) is missing — a broker deployment problem for `docs/runbooks/vault-access-runtime.md`, not a retry.

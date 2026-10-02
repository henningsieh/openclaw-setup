# Personal Vault Identity for Shelldon

Shelldon accesses the owner's existing Vaultwarden account through the Vault Access Broker rather than a dedicated restricted account. This deliberately favors full personal credential availability for authorized agents over reduced vault blast radius.

## Amendment — 2026-10-02

The owner explicitly authorizes `kalle-kief` as an additional Authorized Agent.
Capability authorization has one source of truth: each Authorized Agent's
effective OpenClaw tool policy must explicitly allowlist `vault_fetch`. The
broker must not maintain a second hard-coded agent allowlist, and plugin
approval routing must not duplicate the capability ACL with `agentFilter`.
Every actual `vault_fetch` invocation still requires one-time Retrieval
Approval routed to the owner. No other agent receives access unless explicitly
approved later.

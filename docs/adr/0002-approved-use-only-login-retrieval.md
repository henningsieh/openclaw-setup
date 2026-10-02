# Approved Use-Only Login Retrieval

The Vault Access Broker returns only a Vault Item's username-and-password pair to an Authorized Agent. Capability authorization follows the agent's effective tool policy, as amended in ADR 0001; every invocation requires one-time owner Retrieval Approval regardless of requester, channel, or session type. An Interactive Verified-Owner Turn is the production-validation procedure, not an additional runtime gate.

Credential Responses are use-only for downstream login rather than chat disclosure, and persisted tool results are redacted. This accepts interaction friction to limit disclosure from the full Personal Vault Identity.

Every approved retrieval must complete `bw sync` after any required authentication and unlock, before searching Vault Items. `bw list` reads the local CLI cache, so synchronization is required on every fetch, not just at startup. A failed sync aborts retrieval without a stale-cache fallback; the broker still attempts to lock the vault in `finally`. The additional network dependency is accepted to avoid returning superseded credentials.

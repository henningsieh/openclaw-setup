# OpenClaw Vault Credential Access

The credential-access context governs how OpenClaw agents obtain credentials held in the owner's self-hosted Vaultwarden password vault.

## Language

**Vault Access Broker**:
The native OpenClaw capability through which an authorized agent retrieves a narrowly defined credential response from Vaultwarden.
_Avoid_: vault integration, secret manager

**Personal Vault Identity**:
The owner's existing Vaultwarden account, whose complete password vault is available to the Vault Access Broker.
_Avoid_: service account, dedicated agent account

**Authorized Agent**:
An OpenClaw agent explicitly permitted to use the Vault Access Broker. Shelldon is the sole Authorized Agent initially.
_Avoid_: default agent, trusted agent

**Credential Response**:
One intentionally limited username-and-password pair from a Vault Item.
_Avoid_: password-only response, full vault item, item JSON, named field

**Use-only Credential Response**:
A Credential Response supplied for an Authorized Agent to complete a downstream login, not to disclose in a chat reply.
_Avoid_: credential disclosure, password sharing

**Retrieval Approval**:
The owner's explicit approval required for each Vault Access Broker request.
_Avoid_: standing approval, automatic retrieval

**Interactive Verified-Owner Turn**:
A user-initiated Shelldon turn with a verified owner requester. It excludes scheduled, background, delegated, and unverified turns.
_Avoid_: automation, anonymous turn

**Encrypted Bootstrap Credential Set**:
The Vaultwarden API credentials and master password supplied to the Gateway as systemd encrypted credentials, not as OpenClaw configuration or environment variables.
_Avoid_: environment variables, gateway config secrets

**Vault Item**:
A named record in the Personal Vault Identity that supplies a Credential Response.
_Avoid_: secret, credential

**Lookup Fallback**:
A Vault Item search that prefers an exact name and otherwise succeeds only when the legacy search yields exactly one result.
_Avoid_: first-result selection, exact-only lookup

**Legacy Vaultwarden API Key**:
The API key and paired client secret retained from the retired Docker deployment for native-gateway Vaultwarden authentication.
_Avoid_: rotated API key, new API key

**Local Plugin Source**:
The locally tracked, credential-free source and tests for the Vault Access Broker, installed into OpenClaw as a packed local plugin artifact.
_Avoid_: Docker-era plugin, unmanaged runtime patch

**Pinned Vault Access Runtime**:
The exact tested versions of the Vault Access Broker and Bitwarden CLI dependency, updated only through deliberate maintenance.
_Avoid_: floating latest, automatic upgrade

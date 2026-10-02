---
name: "secret-file-disposal"
description: "Dispose of a plaintext secret file — dotenv dump or credential backup: inventory names, classify, probe liveness, route the live ones, then shred."
---

# Secret File Disposal

1. **Inventory names, never values.** List the keys without reading any value:
   `grep -oE '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=' <file>`.
   Never `source`, `cat`, or interpolate the file — a value containing `|` runs the trailing
   segment as a command — and never let an extracted value reach stdout, chat, or a command line.
   Finish when you have the key list and no value.

2. **Classify every key before touching anything.** For each key decide: (a) already duplicated in
   an authoritative store, (b) live but unique, (c) dead, or (d) a non-secret identifier. Only (b)
   needs routing. Finish when each key has a class.

3. **Probe liveness before routing.** A key that no longer authenticates must not be routed or
   copied. Probe with a status-only request and read only the HTTP code. Do not treat `200` as
   proof: an open `/models` endpoint answers `200` with and without auth. Probe an action endpoint
   with a bogus key and the real key — differing codes (e.g. `401` vs `400`) prove the real key
   authenticates. Finish when each candidate is proven live or dead.

4. **Dedupe before writing.** Grep the candidate value into the agent auth profile store and config
   (`grep -aqF "<value>" <sqlite>`) so you do not create a second copy of a secret that already has
   an owner. Finish when each key destined for routing is confirmed unique.

5. **Route live, unique secrets into the single secrets file `~/.openclaw/.env`.** This instance
   keeps exactly one location for secrets. Build a mode-`600` staging file containing only the keys
   being routed, normalize each line to `KEY="value"` (quote it — a value containing `|` breaks
   unquoted sourcing), append it to `~/.openclaw/.env`, and leave that file at mode `600`. When a
   value already lives in the protected secret store instead, read
   `references/relocate-store-entry.md` first and complete it. Finish when every routed key reads
   back from `~/.openclaw/.env` with a non-zero length.

6. **Select the destination by credential type.** A username-and-password login belongs in a Vault
   Item (see the `vault-credential-retrieval` skill); a non-login machine secret belongs in the
   process environment — the single secrets file `~/.openclaw/.env`, which exec inherits; a
   complete vault-unlock set (master password plus API client credentials) belongs in systemd
   `LoadCredentialEncrypted`, never a plaintext file. Do not open a second location for an
   environment secret: the protected secret store is not an env-secret destination here. Finish
   when the destination matches the credential type and only `~/.openclaw/.env` holds env secrets.

7. **Shred only after the routes are verified.** Re-check the store, then
   `shred -u -z -n 3 <file>` and confirm no residue remains for that filename. Finish when the file
   is gone and the routed keys still read back.

   `shred` is a local-filesystem tool. On a network mount (SMB/CIFS, NFS) or a snapshot-backed
   share it overwrites the live copy and unlinks it, but a pre-deletion snapshot may still hold the
   old version — `shred` is then *not* a guarantee, and complete removal additionally needs snapshot
   pruning on the storage side. Check the filesystem before reporting a shred as irreversible
   (`findmnt -T <path>` or `stat -f -c %T <path>`): even on a local filesystem, SSD wear leveling,
   copy-on-write, journaling, and snapshots can leave recoverable copies. On a network or
   snapshot-backed target say plainly that only the live copy was retired. Never let a
   later user believe a value is unrecoverable when it is not.

8. **Audit for the rest, then report.** Run `openclaw secrets audit` to surface remaining plaintext
   exposures and backup copies; report them along with any un-routed dead or identifier keys
   instead of silently expanding scope.

Verification: every live unique secret reads back from `~/.openclaw/.env`; the shredded file and
its backups are gone; `openclaw secrets audit` findings are reported; no secret value appeared in
any output you produced.

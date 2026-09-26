---
name: "immich-operations"
description: "Inspect Immich health or assets; reconcile sources; import, export, stack, or repair photo metadata with scoped previews and verification."
---

# Immich operations

1. **Scope the request.** Read `entities/immich.md` via `wiki_get` and the relevant
   section of the [instance runbook](/home/shelldon/.openclaw/docs/runbooks/immich-operations.md).
   The Google Photos migration is closed; its export is a backup, not a standing
   import queue. Keep server maintenance and disaster recovery separate. Finish
   when the requested source, target and intended effect are explicit.

2. **Prove the required access.** Check the live server version and `/api/users/me`
   for the asset-owner account. For CLI tasks, check `~/.local/bin/immich-go version`
   and the installed subcommand's `--help`. Use the existing non-admin
   `IMMICH_API_KEY` without printing or persisting it; never substitute the admin
   key for asset ownership. Finish with a verified account and version, or an
   exact access blocker.

3. **Choose the narrow interface.** Use version-matched OpenAPI or the bundled
   read-only helpers for health, search and metadata. Use `immich-go` for imports,
   exports and stacks. `reconcile_source.py` checks SHA-1 bytes, not metadata;
   `find_duplicates.py` groups *candidates* by filename/time, not proven byte
   duplicates. Paginate searches to the verified end and include trash when
   assessing duplicate residue. Use `from-google-photos` only for a newly scoped
   Takeout with JSON sidecars; use `from-folder` for ordinary media/XMP. For a
   partial import read [partial-import recovery](references/upgrade-path-recovery.md)
   before retrying; for suspect dates read
   [undated-asset triage](references/undated-asset-triage.md). Finish when the
   selected interface and current schema support the operation.

4. **Preview state changes.** Follow the runbook's key mapping and command
   environment. For `immich-go`, use a private empty working directory,
   `umask 077`, absolute paths and private logs; keep traces and `--save-config`
   off. Dry-run the exact source, filter, destination and mode; archive previews
   need both `--dry-run` and `--from-dry-run`. Read-only queries need no dry-run.
   Finish with reviewable counts, exclusions and errors.

5. **Execute the authorized scope.** Reuse existing authorization only if it
   covers that exact operation. Run the reviewed invocation without preview
   flags; keep the non-admin upload key separate from any admin job key. Do not
   directly edit production media or delete a source as part of an import. Finish
   with a completed result or a reported partial failure.

6. **Verify independently.** For imports, reconcile CLI counts, rerun the same
   dry-run for zero new uploads, compare source SHA-1 with active server assets,
   and read back relevant dates, albums and formats. Treat unknown API responses
   or zero-present/zero-absent reconciliation as a failed check, not an all-clear.
   For metadata writes read back *each* changed asset; for exports inspect the
   destination; for stacks confirm groups and retained variants. Preserve source
   evidence until verification passes. Finish with observed counts and named
   exceptions.

## Bundled read-only helpers

- `scripts/immich_health.py` — health, version and account roles.
- `scripts/search_assets.py` — paginated search, optionally with albums/trash.
- `scripts/reconcile_source.py` — local SHA-1 against the server.
- `scripts/find_duplicates.py` — filename/time candidate groups, not proof of duplication.

Load `IMMICH_API_KEY` from the native dotenv in the invoking environment; never
put its value in arguments, logs or output. Keep one copy of each helper.

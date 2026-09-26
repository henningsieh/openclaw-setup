# Recover a partial import

Trigger: an import reports server errors, especially an asset-copy or metadata
step, even if media upload errors are zero. Do not rerun the same source until
the partial state is understood; a retry can create another asset.

1. Record the failing file, asset IDs, operation, HTTP status and correlation ID
   from the private job log. Keep the source and log. Finish when the affected
   asset set is bounded.
2. Search active **and trashed** assets. Match each candidate to source media by
   SHA-1, not filename or timestamp. Read albums, tags, dates and formats, and
   confirm the intended surviving asset is usable. Finish when a winner and any
   incomplete metadata are identified, or report uncertainty.
3. Check the live server version's OpenAPI for metadata-copy and asset-trash
   requests. Prepare a reversible repair of the confirmed winner; preview the
   exact IDs and fields for owner review. Never use permanent deletion to fix
   bookkeeping. Finish when the repair scope is approved.
4. Apply only that scope, then read back the surviving asset, its album membership
   and the trash state of alternatives. Reconcile source SHA-1 and import counts.
   Finish only when media and metadata are both verified; otherwise retain the
   source and report the remaining exception.

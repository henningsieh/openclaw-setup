# Triage suspicious capture dates

Trigger: a group of photos appears under one implausible timeline date. First
determine whether a real date was lost or the source never held one.

1. Match each asset to its source media and sidecar by content and directory;
   check EXIF, sidecar capture time and any original export copy. A placeholder
   name or identical sequential timestamps across a batch may indicate an
   upstream synthetic date. Treat `0.0/0.0` coordinates as absent. Finish with
   evidence for each date's provenance, not an inferred date from filename.
2. If a real source date exists, compare it with Immich's `fileCreatedAt` and
   `localDateTime` and prepare a bounded metadata repair. If no real date exists,
   present an undated/review label or an explicitly approximate date as a user
   choice; do not call an invented date a recovered original. Finish with the
   intended policy for the affected set.
3. Before a write, verify the current API schema and list every asset ID. After
   an authorized canary, read back both timeline fields and album membership;
   then verify **every** changed asset. A 2xx response alone is not success.
   Keep source sidecars, and do not re-import solely to change existing dates.

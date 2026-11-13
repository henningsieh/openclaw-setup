---
name: bulk-metadata-annotation
description: Annotating every procedure or endpoint with metadata (tags, summaries, descriptions): table-driven insertion, structural guard, live verification.
---

# Bulk Metadata Annotation

Add one kind of metadata (OpenAPI tags, summaries, descriptions, deprecation flags) to every entry point in a large surface without hand-editing dozens of files, and prove it landed.

## 1. Inventory from the registration point

Read the router/registry that lists every entry (e.g. `router.ts`), not the file tree. Record each exported symbol in `.handler(` order per file; that order is what your insertion script will rely on. Count handlers per file with `grep -c` and keep the numbers as your expectation.

## 2. Build the text table before touching code

Write one `(file, [entries in handler order])` table in a throwaway script. Each entry carries the metadata payload only. Validate first and abort on mismatch:

```python
if len(HANDLER_RE.findall(text)) != len(entries):
    sys.exit(f"MISMATCH {rel}")
```

A mismatch means the inventory is wrong, not the file. Never write on mismatch, so a failed run leaves the tree clean.

## 3. Insert at the chain position, not by line number

Match `^\s*\.handler\(` with `re.MULTILINE` and insert the metadata block immediately above it, reusing the captured indentation. `^` without `MULTILINE` silently matches only the file start and reports zero handlers — if every count is zero, the regex flags are the bug.

## 4. Insert imports by sorted specifier

Sort-aware linters order imports by module specifier. Insert the new import before the first existing import whose specifier sorts later, and skip a leading side-effect import such as `import "server-only";`.

Do not insert "after the last import line": when the original last import is a multi-line `import { ... }` block, that position lands inside the braces and produces a syntax error. After running the script, any parser error means an insertion point was computed wrong; fix the script and re-run from a clean tree rather than patching the broken file.

## 5. Handle shared factories once

When several entries come from one factory call, add a single metadata block inside the factory and pick the payload from a lookup keyed by the factory argument. Do not duplicate the block per call site.

## 6. Split instead of suppressing line limits

Adding metadata can push a hub file over a `max-lines` limit. Split the module into focused files and re-export what other modules import.

Never add a `max-lines` suppression to make room. The user treats it as a no-go; a suppression hides the growth instead of paying it down.

When moving code, keep every module that other files import reachable at its original path, either by keeping it in place or re-exporting it, then run the type checker: unresolved imports name exactly which symbol landed in the wrong file. Re-point every guard keyed by file path to the file that now holds the code — invariant-throw allowlists and per-file budgets fail with the old path and pass only once moved — and update the registration point that imported the moved symbols.

## 7. Keep the diff additive

For a metadata-only change, `git diff --stat` must show insertions only. A deletion in a handler, schema or return value means the script rewrote more than metadata; revert and fix the script.

## 8. Add a structural guard

Add a test that scans procedure sources (not the router import, which drags in env validation and the database client) and asserts per file:

- count of `^\s*\.handler\(` equals count of `^\s*\.meta\(`,
- every value from the metadata vocabulary is in the allowed set,
- no empty payload.

This guard is what catches an entry you missed; run it before claiming coverage, and treat its failure as a real finding, not a flaky test.

## 9. Verify against a running server

Unit tests alone do not prove the user-visible result. Start the dev server, then assert the served artifact:

```sh
curl -s -o /dev/null -w '%{http_code}\n' --noproxy '*' http://localhost:<port>/<docs-route>
curl -s --noproxy '*' http://localhost:<port>/<spec-route> -o /tmp/spec.json
```

If the route is session-gated, sign in through the API first and reuse the cookie jar:

```sh
curl -s -c /tmp/cj.txt -X POST http://localhost:<port>/<sign-in-route> \
  -H 'content-type: application/json' -H 'origin: http://localhost:<port>' \
  -d '{"email":"...","password":"..."}'
curl -s -b /tmp/cj.txt http://localhost:<port>/<spec-route> -o /tmp/spec.json
```

Then count from the artifact, not from source: total operations, distribution per category, entries missing the payload, entries carrying more than one category. Report those numbers.

Stop the dev server afterwards and confirm the port is free.

## Reporting

State the operation count and per-category distribution from the live artifact, name the guard that prevents regression, and disclose anything still pending (for example fields deferred to a follow-up ticket).
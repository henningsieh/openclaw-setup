---
name: validator-gated-fanout
description: Children must return machine-checked JSON (ledgers, findings, schemas): strict prompts, checker-first consolidation, re-queue on malformed results.
---

# Validator-Gated Fan-Out

Use when delegating work where each child must return JSON that a checker script validates (coverage ledgers, findings files, report schemas, any machine-checked artifact).

1. Paste the exact contract into every child prompt: every ID and key the child must echo back verbatim, because any shortening or invention fails validation and wastes the round.
2. Enumerate every allowed enum value and array-vs-object shape in the prompt, and name the single JSON object to return with no surrounding prose, because children drift toward plausible-but-invalid shapes without an explicit closed set.
3. Stay under the platform's max active children and queue the remainder, because excess spawns are refused and the rejected batch still costs coordination.
4. Run the checker on each child result before consolidating (e.g. `node <skill-dir>/validate-*.cjs <run-dir>/<file>.json`); when the IDs do not map, treat the result as unassigned work to re-queue with a stricter prompt, because repairing a verdict corrupts the evidence chain. When the IDs map but only the finding payload is malformed, keep the mapping and re-queue just the payload with the exact failure quoted, because discarding a valid mapping wastes the round.
5. Normalize only format deviations that preserve meaning (missing empty arrays, line ranges to the cited line, trace kinds to entrypoint/propagation/sink), and send anything that changes meaning back for re-hunt with the exact failure quoted, because silent correction hides real disagreement.
6. Re-run the checker after every consolidation and before any coverage or completion claim; record untouched scope as `deferred` with the blocking reason and disclose the gap, because a partial pass with a disclosed gap beats a false complete claim.

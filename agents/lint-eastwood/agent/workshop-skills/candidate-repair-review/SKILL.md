---
name: candidate-repair-review
description: "Review a repair/security-fix candidate against a base commit: clone, diff map, race checks, demonstrated vs unproven findings, failed-suite attribution."
---

Review one candidate commit range for a stated repair without touching the user's worktrees, tests, servers, or database. Produce a verdict on whether the original defect is closed and separate demonstrated bugs from unproven risks.

1. Isolate the review. `mkdir -p <review-dir> && git clone --filter=blob:none --no-checkout <https-remote> repo`; fetch both SHAs by value (`git fetch origin <sha>`) and confirm `git cat-file -t` returns commit. Check out the candidate detached (`git switch --detach <candidate>`). Never switch or reset the user's existing worktree; a read-only review may share the object store but not the checkout. If the source is a bundle, `git bundle list-heads <bundle>` and fetch `HEAD:refs/heads/review`; bundles often expose only `HEAD`.
   Check: `git rev-parse HEAD` equals the candidate; `git merge-base <base> <candidate>` equals the base.

2. Read the governing rules. Open the repo's `AGENTS.md` and only the instruction files/ADRs scoped to the touched areas (procedures, persistence, locks, error contract). Do not pre-read the whole docs tree.
   Check: every claim in the review cites a repo rule or ADR, or is labelled a judgement call.

3. Map the exact delta. `git diff --stat <base>..<candidate>` and `git diff --name-status`. If the task states a file count, verify it. For each file, state its role in one line before reading details.
   Check: no file outside the stated scope; if there is one, report it as scope drift.

4. Verify the repair, not just the diff. For a race or visibility repair, enumerate every actor (list/link/submit/delete/upload), the rows each locks and in what coverage order, and the window in which metadata or bytes are visible. Then check three invariants: nothing is published before the external write; the final transaction rechecks identity, lifecycle state, and capacity under the same lock; compensation deletes only the unique object created by this attempt.
   Check: draw the interleaving for "actor first" and "finalizer first"; if either exposes metadata before the write, the defect is open.

5. Prove reachability. `grep -rn` the changed symbols and table names across the app; list every caller and writer. A repair that covers one call path leaves the others open. Check that a failed external write cannot leave a row pointing at missing bytes (commit-ack ambiguity), and that a failed cleanup only leaks an orphan, never a dangling row.
   Check: every caller is either covered or named as out of scope.

6. Classify findings. Use three buckets: demonstrated (reproduced by a test/log or proven by an interleaving in the code), unproven risk (reasoned but not reproduced), and test gap (the claim is argued but not covered). Each finding gets severity, `path:line`, evidence, and the smallest correction. Never claim a suite or test ran when the task forbade it.
   Check: no finding sits in "demonstrated" without a reproduction or a step-by-step code proof.

7. Adjudicate failed suites. First establish reachability: `git diff --name-only <base>..<candidate>` and grep the failing test for the changed symbols. If the diff cannot reach the failing code, say "no demonstrated causal path" without dismissing. Read the first failure and its cascade separately; a timeout followed by lock/FK cleanup errors is one blocker, not many. Prescribe an isolated rerun with the repo's canonical integration command (for Vitest: one worker, no file parallelism, isolate, zero retries) and capture the first stack plus lock/session state.
   Check: the report either explains the failures or states them unresolved and blocks acceptance; full-suite evidence from the base is never presented as candidate evidence.

8. Deliver. Start with a verdict: original defect closed/open, demonstrated bugs, unresolved blockers. Then findings by severity, then the evidence level (what was actually run vs read). Save the long report under the review directory and send a short summary with the path; keep secrets out.
   Check: the summary names the candidate, base, verdict, and blocker count.

Standing preferences: report-only unless asked to fix; severity and smallest correction per finding; separate demonstrated from unproven; explicit race-closure verdict; no secret values.

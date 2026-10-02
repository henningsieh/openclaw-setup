---
name: progress-card-sync
description: "A session progress card is stale, still shows pending/clock state, the owner asks to mark completed work done, or a multi-step task needs a card created: write a schema-valid plan and verify its stored state."
---

# Progress card sync

Use this when a session progress card disagrees with verified work, especially
when a clock or pending icon remains after completion, and when starting a
multi-step task that should be tracked. Creating and updating are the **same
call** — see step 2 before the first attempt.

1. **Reconcile the task state before touching the card.** List the original steps, attach the observed evidence to each, and mark a step `completed` only when its completion check passed. Keep unrelated or genuinely unresolved work separate. Finish when one full, non-duplicated step list represents the current work.

2. **Read the live tool schema.** Use the available tool search/description (or the native tool schema) and pass the fields it declares. The plan value is one direct array of objects with exactly `step` and `status`; do not pass it as a string, a nested array, or an extra wrapper. A validation error is not proof that the card changed. Finish when the payload matches the tool's current schema.

   **There is no `action` field.** Writing `action: "create"`, `fields`, or
   `title` is rejected outright with `must not have additional properties`, and
   a plan nested one level too deep is rejected with `plan: must be array`. The
   accepted call is the whole plan in a single flat payload:
   `{"markdown": "<optional heading>", "plan": [{"step": "...", "status":
   "pending" | "in_progress" | "completed"}]}`. The tool states this expected
   shape back in its own error text, so read that message instead of guessing a
   second variant. Two rounds of shape-hunting is the signal to stop and take
   the schema from the error verbatim.

3. **Update the existing card in place.** For a completed task, send the whole reconciled plan with the relevant statuses set to `completed`; reserve `pending` and `in_progress` for work that remains. Do not create a replacement suggestion/task or rely on a prose claim. When step history matters, do not use a markdown-only update: a result with `steps: null` means the checklist was cleared or not supplied. Use markdown alone only for a text-only status note when no plan history is required. Finish when the tool accepts the intended full plan.

4. **Verify the stored state.** Read the tool result and require an updated revision plus the expected plan (or re-read the card when the tool supports it). If the result has an error, `steps: null`, stale statuses, or an unknown write outcome, report the UI/tool mismatch separately and do not claim the clock icon is gone. Retry only after a fresh read, never by repeating an unverified mutation. Finish with the card state or the exact UI/runtime blocker.

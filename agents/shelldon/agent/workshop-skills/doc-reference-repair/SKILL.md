---
name: "doc-reference-repair"
description: "Stale doc pointers or a referenced path that no longer exists: verify existence, trace git renames, repair backup claims, leave no dead reference."
---

# Document Reference Repair

1. **Confirm what is actually missing.** Test the path on disk directly
   (`[ -e <path> ]`). A git lookup alone misleads: `git ls-files --error-unmatch <path>` and
   `git cat-file -e HEAD:<path>` both fail for a file that exists only on another branch or was
   renamed, so read them as "not at this ref", never as "does not exist". Finish when you know
   whether the path is absent from disk or merely absent from the current ref.

2. **Before rewriting a pointer, trace the path's history for a rename.** Run
   `git log --name-status --all --format='%h %s' -- <path>`.
   An `R100 <old> <new>` line means the file was **renamed** — repoint every reference to the
   successor instead of deleting the reference or recreating the old file. A `D` line means it was
   deleted; then the pointer must be corrected or removed. Finish when you can name the successor,
   or confirm the path is genuinely gone.

3. **Replace the dead reference with the live fact — never leave a tombstone.** A pointer is still
   dead when the sentence keeps the missing path inside a "since removed" or "no longer exists"
   note; this operator's standing rule is no dead pointers at all. Test the path; when it is absent,
   delete the reference and state only what is current, substituting a surviving path where one
   exists and dropping the clause where none does. Finish when no edited claim names a path that
   does not exist.

4. **Repair every live copy, and only those.** Re-grep the dead path across live documentation and
   fix each occurrence. Exclude historical archives — wiki `sources/` pages, migration logs, and
   install recipes — where the old name is a record of what happened, not an instruction to follow.
   Finish when a repeat grep finds no live document referencing the nonexistent path.

Verification: every edited pointer names a path that exists; no live document names a path that does
not exist, not even inside a "removed" or "no longer exists" note; historical archives were left
unchanged.

# Review finding to GitHub issue

Use when the user asks to file review findings as a bug report.

1. Check for duplicates before creating anything:

   ```bash
   gh issue list --repo <owner>/<repo> --state all --search "<key terms>" --limit 10
   ```

   Continue only when no open issue covers the same finding.

2. Write the body to a workspace file, not inline shell:

   `<workspace>/issue-<slug>.md`

3. Use these sections in order:

   - Summary: what changed, what is broken, and why it matters.
   - Environment: repo, branch, commit, base, app, data context.
   - Steps to reproduce: exact commands.
   - Expected behavior: observable outcomes.
   - Actual behavior: observed output with file:line references.
   - Root cause: the specific mock, gate, or endpoint cap.
   - Proposed fix: minimal actionable changes.
   - Acceptance criteria: checkbox list that can be verified.
   - Verification: commands and results already observed.
   - Out of scope: related issues, with issue numbers.

4. Create and label:

   ```bash
   gh issue create --repo <owner>/<repo> \
     --title "<surface>: <broken behavior>" \
     --body-file <path> \
     --label bug
   ```

   Add `--label ready-for-agent` only when the acceptance criteria are complete enough to implement without further discovery.

5. Verify the result:

   ```bash
   gh issue view <number> --repo <owner>/<repo> --json number,title,url,state,labels
   ```

   Report the issue URL and the applied labels.

Keep credentials out of the body; cite file paths and commands instead of environment values.

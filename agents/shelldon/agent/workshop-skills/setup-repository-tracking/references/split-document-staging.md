# Stage one document section without rewriting the working file

1. Use `git add -p <path>` when the relevant changes occupy separable hunks. If the document mixes topics in adjacent edits, construct the intended staged version in memory instead of replacing the working file.

2. Start from the existing index blob (`git show :<path>`), not an unstaged working copy, because earlier staged edits must survive. Read the working file separately and select the exact uniquely delimited section to include. Inspect `git ls-files -s -- <path>` first; refuse an unmerged index and preserve the existing file mode.

3. For a text file with unique section markers, adapt this Python snippet from the repository root, replacing the path and markers with the inspected values:

```python
from pathlib import Path
import subprocess

path = "CONTEXT.md"
start = "## Repository tracking\n"
end = "## Next section\n"
entry = subprocess.check_output(
    ["git", "ls-files", "-s", "--", path], text=True
).rstrip("\n")
mode, old_blob, stage_and_path = entry.split(" ", 2)
assert stage_and_path.startswith("0\t"), "Unmerged index"
base = subprocess.check_output(["git", "show", ":" + path], text=True)
working = Path(path).read_text()
assert base.count(start) == working.count(start) == 1
assert base.count(end) == working.count(end) == 1
assert base.index(start) < base.index(end)
assert working.index(start) < working.index(end)
section = working.split(start, 1)[1].split(end, 1)[0]
staged = base.split(start, 1)[0] + start + section + end + base.split(end, 1)[1]
blob = subprocess.check_output(
    ["git", "hash-object", "-w", "--stdin"], input=staged, text=True
).strip()
current = subprocess.check_output(["git", "rev-parse", ":" + path], text=True).strip()
assert current == old_blob, "Index changed; inspect before retrying"
subprocess.run(
    ["git", "update-index", "--cacheinfo", f"{mode},{blob},{path}"], check=True
)
assert Path(path).read_text() == working
```

4. Inspect `git diff --cached -- <path>` and `git diff -- <path>` before committing, because the first must contain only this commit’s section and the second must retain the remaining changes. Run `git diff --cached --check`; do not stage the whole file until its remaining topics belong to the next commit.

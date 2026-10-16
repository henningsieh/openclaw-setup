# Recover a Provider Absent From One Agent's Control UI Selector

Read this only when a whole provider is missing from **one** agent's Control UI
model selector. Do not equate `models list` rows with selectable, authenticated
models.

Compare catalog, agent auth, and route for both agents:

```bash
openclaw models status --agent <id> --json --check
openclaw models auth list --agent <id> --provider <provider> --json
```

If only the affected agent lacks an OpenAI OAuth profile, log in for that agent
(without `--set-default`):

```bash
openclaw models auth login --agent <id> --provider openai --device-code
```

Have the owner complete the short-lived device approval privately, then recheck
its profile status and the UI.

`auth activate` selects a saved profile *within* the target agent store; it
cannot adopt another agent's profile. Do not copy agent SQLite stores, change a
shared default, or restart solely because the login warns that Gateway auth
refresh was unconfirmed: first check whether the actual UI now lists the models.

Finish only when the affected selector shows them; CLI catalog metadata alone is
insufficient.

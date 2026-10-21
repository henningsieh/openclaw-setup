# Give One Agent a Provider It Lacks

Read this when one agent fails a model call while the default agent's calls to the
same provider succeed. Two independent gaps live behind that symptom: the agent's
own credential store and the agent's own model catalog. Fix the credential first,
then the catalog, then re-run the job.

## 1. Prove which side has the credential

```bash
openclaw models auth list --agent <defaultAgentId> --provider <provider>
openclaw models auth list --agent <affectedAgentId> --provider <provider>
```

The default agent lists `<provider>:default [<provider>/api_key]`; the affected
agent omits the profile entirely. A profile that exists for one agent is not
inherited by another.

## 2. Read the key out of the default agent's store

External `sqlite3` refuses databases under the active state directory
("external sqlite3 cannot open databases under the active OpenClaw state
directory"), so copy the store out and query the copy:

```bash
cp ~/.openclaw/agents/<defaultAgentId>/agent/openclaw-agent.sqlite /tmp/agent-store.sqlite
sqlite3 /tmp/agent-store.sqlite \
  "select store_json from auth_profile_store where store_key='primary';"
```

The JSON holds `profiles."<provider>:default".key`. Keep the value out of
transcripts, command lines, and reports; pass it through a shell variable.

## 3. Write it into the affected agent

Read the source profile's `type` field first (`api_key` or `token`) and use the
matching paste command, because the command decides the type written into the
target store:

```bash
printf '%s' "$KEY" | openclaw models auth paste-api-key \
  --provider <provider> --agent <affectedAgentId> --profile-id <provider>:default
```

```bash
printf '%s' "$KEY" | openclaw models auth paste-token \
  --provider <provider> --agent <affectedAgentId> --profile-id <provider>:default
```

Only portable static `api_key` and `token` profiles may be copied this way;
OAuth refresh-token profiles are not portable and need their own sign-in for
that agent.

## 4. Verify the store, then the route

```bash
openclaw models auth list --agent <affectedAgentId> --provider <provider>
```

Expect a line `<provider>:default [<provider>/api_key]` for a paste-api-key
transfer, or `<provider>:default [<provider>/token]` for a paste-token
transfer. A paste warning that
the running Gateway could not refresh auth concerns the live process, not the
store — the profile is written and applies to the next run.

A present credential does not prove the agent can serve the requested model.
That agent's catalog can differ from the default agent's, so list it and
compare the ids against the id the failing job asks for:

```bash
openclaw models list --agent <affectedAgentId> --provider <provider>
```

A job payload id missing from that list is a second, independent gap. The
error echoes the mismatch in a doubled form — `provider/provider/<id>:<thinking>`
— because the payload id already carried the provider prefix. Fix the payload
id to the id the agent's catalog actually lists; do not add a second prefix to
the payload to satisfy the error text.

A job payload can also name a model id the provider never had. Query the
provider's live model list against its own key to learn the current ids:

```bash
curl -s -H "Authorization: Bearer $KEY" <providerBaseUrl>/models
```

Compare that list with the ids in the job payload and in
`models.providers.<id>.models[]`. A job pinned to a retired id fails with
`Unknown model: <id>` even when the provider credential is perfect, and the
fallback chain then decides which model actually answers.

## 5. Prove with a forced run

```bash
openclaw cron run <jobId> --wait --wait-timeout 8m --json
```

Require `status: ok` and `completionStatus: succeeded`. The error text changes
to a different layer's error as each gap closes, so a moved error is progress
only when the new layer is diagnosed and fixed too.

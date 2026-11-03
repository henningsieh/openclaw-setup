# Secondary-agent provider gaps

1. Read the installed `docs/auth-credential-semantics.md` and `docs/concepts/oauth.md` before interpreting per-agent credential differences. For auth diagnosis and shared-store repair, load the installed `agent-auth-profile-activation` skill; keep that procedure as the single source of truth.
2. Compare each affected agent's effective provider/profile readiness with `openclaw gateway call models.list --params '{"agentId":"<id>"}' --json`. A refresh warning alone is not proof of a missing credential or failed model. Inspect unavailable reasons and the actual provider error.
3. Compare the exact model requested by the failing session or automation with that agent's catalog and current provider inventory. Preserve provider path segments: an upstream ID can legitimately contain its own provider-like prefix. An invalid or retired model ID is separate from auth.
4. Repair the proven layer without changing unrelated defaults, sandbox policy, or runtime ownership. Do not add per-agent credential copies when the owner requests shared auth.
5. Prove auth and model availability with the narrow `infer model run` procedure from the auth skill. Re-run an automation only when verifying its workflow is authorized; do not trigger external delivery merely to check a credential.

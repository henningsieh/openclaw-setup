# Domain Docs

This is a single-context repository.

## Required context before exploring

1. Read `AGENTS.md`. It contains the authoritative operational, deployment,
   security, provider, automation, and instance-history context for OpenClaw.
2. Read `CONTEXT.md`. It currently documents the Vaultwarden / `vault_fetch`
   feature and its domain terminology.
3. Read relevant ADRs under `docs/adr/` before changing an area they cover.

`CONTEXT.md` is not a replacement for `AGENTS.md`; both must be consulted.

## File structure

```text
/
├── AGENTS.md
├── CONTEXT.md
└── docs/
    ├── agents/
    └── adr/
```

## Use the glossary vocabulary

When naming domain concepts in issues, proposals, tests, or implementation
plans, use terminology defined in `CONTEXT.md`. If a needed concept is missing,
note the gap for domain modeling rather than silently inventing competing terms.

## Flag ADR conflicts

If proposed work contradicts an existing ADR, surface the conflict explicitly
rather than silently overriding it.

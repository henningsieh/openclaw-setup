# Domain Docs

This is a single-context repository.

## Context hierarchy

`AGENTS.md` is the short, always-loaded routing and safety guide. `CONTEXT.md`
is the full instance and domain reference, loaded when the task enters one of
its documented branches.

## Required context before exploring

1. Read `AGENTS.md`.
2. For native OpenClaw operations, repository-history questions, or Vault
   Credential Access work, follow its routing rules and read the relevant
   sections of `CONTEXT.md`.
3. Read relevant ADRs under `docs/adr/` before changing an area they cover.

The Vault Credential Access vocabulary and constraints live in `CONTEXT.md` and
are further constrained by the Vault ADRs. Do not replace them with synonyms.

## File structure

```text
/
├── AGENTS.md                 # always-loaded routing and safety guide
├── CONTEXT.md                # full instance and domain reference
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

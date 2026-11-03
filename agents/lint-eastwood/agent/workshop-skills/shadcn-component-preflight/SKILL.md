---
name: shadcn-component-preflight
description: "Before custom UI in a shadcn project: check the style registry for an existing component, compare deps, keep data wiring in a wrapper."
---

# shadcn component preflight

Use when asked whether shadcn already provides a component, or before building a custom dropdown, combobox, table, or dialog in a project with `components.json`.

## 1. Read the project's shadcn configuration

```bash
cat components.json
ls src/components/ui
```

Record `style` (for example `base-sera`), `aliases.ui`, and which components already exist. A component missing from `src/components/ui` may still exist in the registry; check the registry before building a custom one. The registry lookup is style-specific; a generic `/r/<name>.json` URL can return the docs HTML instead of JSON.

## 2. Query the style-specific registry

```bash
curl -sS -L "https://ui.shadcn.com/r/styles/<style>/<name>.json" | head -c 1200
```

A valid item is JSON with `name`, `dependencies`, `registryDependencies`, and `files`. Read `files[].path` and `files[].content` before deciding.

Verified example:

```bash
curl -sS -L "https://ui.shadcn.com/r/styles/base-sera/combobox.json" | head -c 800
```

## 3. Compare with the local project

Check whether the registry dependencies are already present:

```bash
node -e 'const p=require("./package.json");console.log(JSON.stringify({...p.dependencies,...p.devDependencies},null,2))' | grep -iE "base-ui|radix|cmdk|shadcn"
ls src/components/ui
```

List missing `registryDependencies` files. Installing the component can add them, but name them in the plan first.

## 4. Choose the boundary

Use the registry component when its interaction matches the requirement. Keep a project wrapper for server search, debounce, preload, permissions, and error states; the registry component supplies the accessible primitive, not the data flow. Keep `ui/button.tsx` at standard geometry and vary only color tokens per theme for every app variant (primary, secondary, ghost); put only the theme-breaking marketing CTA in `brand/` as a wrapper composing the primitive, because rewriting the primitive collapses the landing/app distinction and an app primary in `brand/` bypasses the standard.

Do not replace a working custom component during an unrelated bug fix. Separate the migration into its own change with the same props and tests.

## 5. Install and verify only when asked

```bash
npx shadcn@latest add <name>
ls src/components/ui/<name>.tsx
pnpm --filter <package> run type-check
```

Confirm the file exists and type-check passes. Do not report the component as installed from the CLI prompt alone.

## 6. Report

State the exact registry URL, the component name, its dependencies, missing registry dependencies, and whether the local project already has the component. Mark any unverified install step as unverified.

---
name: shadcn-preset-radius-migration
description: "Switching a shadcn base style/preset or making controls and cards inherit theme radius: registry diff, minimal primitive edits, computed-theme verification."
---

# shadcn preset / radius migration

Use when the user wants a different shadcn base style (luma, maia, ...) or wants buttons, inputs, selects, and cards to inherit the theme radius instead of per-theme overrides.

## 1. Inventory the radius system

- Read `components.json` (`style`) and `src/app/globals.css`.
- Run `grep -n -- '--radius' src/app/globals.css` and `grep -rn 'rounded-none' src/components/ui`.
- Record the single `--radius` base, the `@theme`/`@theme inline` scale, any per-theme `--radius-*` pins, and which primitives hardcode `rounded-none`.
- Audit font tokens in the same pass: `grep -n -- '--font-' src/app/globals.css`. Keep one `--font-sans`/`--font-heading`/`--font-mono` trio in `@theme`, delete per-theme `--font-sans`/`--font-heading` overrides, and remove unused `next/font` imports and variables from the root layout. Verify `fontFamily` on body and a heading matches in light and dark.
- Centralize heading treatment in `@layer base`: `h1`-`h6` get `font-family: var(--font-heading)`, `font-weight: 900`, `letter-spacing: -0.03em`, `line-height: 1.05`, `text-wrap: balance`. Keep per-level sizes on the elements; do not apply the display clamp to every heading. Remove `font-semibold`/`font-extrabold`/`tracking-*` utilities from heading call sites so the base wins. HTML has no `h7`.
- Give surface titles one role: `CardTitle`, `DialogTitle`, `SheetTitle`, and `EmptyTitle` use `font-heading`, `font-extrabold`, `tracking-tight`, normal case. Keep a section title used as the card-header reference at weight 800 even when content `h2` are 900.
- Keep one eyebrow utility: mono, weight 500, uppercase, wide tracking, `var(--primary)`; apply it to page and section eyebrows and let color follow the theme. Do not force brand yellow on light backgrounds.
- Verify `fontFamily`, `fontWeight`, `letterSpacing`, and `textTransform` for h1, section h2, card title, and eyebrow in light and dark.

## 2. Read the target preset from the registry

- Style names differ from CLI preset names: `components.json` uses `base-maia`, the CLI preset is `maia`, the registry path is `/r/styles/base-maia/<component>.json`.
- Fetch the index and the candidate component recipes:

```bash
curl -sS "https://ui.shadcn.com/r/styles/base-maia/index.json"
curl -sS "https://ui.shadcn.com/r/styles/base-maia/card.json"
```

- Choose maia for conventional SaaS geometry (cards `rounded-2xl`, pill controls `rounded-4xl`); luma also makes cards `rounded-4xl`. Record each component's radius token before editing.
- Use `shadcn apply <preset> --only theme` only on a scratch copy: it rewrites color tokens, and a full apply installs the preset's icon package. Copy only the radius scale from its output.

## 3. Collapse to one radius source

- Keep one `--radius` in `:root` (maia default `0.625rem`) and one scale:

```css
--radius-sm: calc(var(--radius) * 0.6);
--radius-md: calc(var(--radius) * 0.8);
--radius-lg: var(--radius);
--radius-xl: calc(var(--radius) * 1.4);
--radius-2xl: calc(var(--radius) * 1.8);
--radius-3xl: calc(var(--radius) * 2.2);
--radius-4xl: calc(var(--radius) * 2.6);
```

- Delete `--radius-*` pins from every theme block so all themes inherit identical geometry.

## 4. Move primitives to the preset tokens

- Replace only the radius class in each primitive base string; keep brand typography, sizes, colors, and custom variants.
- Never pass shape, color, or spacing classes to `Input`, `SelectTrigger`, or `Button` from pages: a `shadcn/no-restyle` lint guard rejects them. Put the geometry in the primitive's cva variant or base string, then use the plain component at call sites.
- Never mint a new Button variant or component style to make a picker trigger match a field; use an existing variant. Replace hand-built wrappers (`space-y-2` + raw label + Button/Input mix) with `Field`/`FieldGroup`. Keep a searchable entity picker on its Combobox/Popover implementation: replacing it with `Select` removes search and breaks assignment flows and tests. When its popover corners are square, clip the popover surface with `overflow-hidden` and render one-line option labels; verify the open panel.
- maia mapping: start with button/input/select/combobox/toggle/input-group `rounded-4xl`; when the user wants compact controls, move every control to one smaller token (`rounded-xl`) and keep all surfaces on `rounded-2xl`. Surfaces: card base and ember variants, popover, dropdown-menu, dialog, select content, toast. Menu items `rounded-xl`; textarea `rounded-xl`; kbd `rounded-sm`; empty icon `rounded-lg`; sidebar `rounded-md`/`lg`/`xl`.
- When changing field fill or border, audit every field-bearing primitive, not just Input and SelectTrigger: `grep -rn 'border-b-input\|bg-transparent\|px-0' src/components/ui` and align Textarea, InputGroup, and ComboboxChips to the same boxed geometry; otherwise the next form mixes underline and boxed fields.
- Retint stock field fills by changing the token value in `:root`, not the utility class in the primitive. Keep `bg-input/30`, solve the base token for the target composite over the card (`token = (target - (1 - 0.3) * card) / 0.3`), then sample a rendered screenshot pixel to prove the result; the user rejects swapping in another color utility because it edits the original component. Note that the same token also colors borders and every other `border-input` consumer.
- To restore a primitive to the preset, run `shadcn add <component> --dry-run` first: a plain `--overwrite` also rewrites its registry dependencies (button/input/sheet/tooltip) and can reintroduce the preset's radii. Copy that component's registry recipe into the local file, rewrite `@/registry/<style>/ui/...` imports to `@/components/ui/...`, then re-apply only the theme normalization (control token, height, ring) and rescue custom cva variants by hand.
- Put the card radius on the cva base so every variant inherits; remove per-variant radius classes and set header/image corners with `rounded-t-*`/`rounded-b-*`.
- Keep `rounded-none` only where the preset keeps it (joined toggle groups, inner input-group controls).
- Update tests that assert the old class: `grep -rn '"rounded-none"' src --include='*.test.tsx'`.

### Audit the app for remaining overrides

Run this after the primitive sweep; the lint guard only checks primitive call sites.

```bash
grep -rnE '<(select|input|textarea)\b' src --include='*.tsx'
grep -rn 'shadcn/no-restyle' src --include='*.tsx'
grep -rnE 'rounded-(sm|md|lg|xl|2xl|3xl)' src --include='*.tsx' --exclude-dir=ui
```

- Flag raw form elements with `rounded-sm|md`, `bg-background|bg-card`, `border-b-input`, or `px-0`: native controls bypass the primitives; replace them with Input/Textarea/Select or match the primitive box.
- Treat every `shadcn/no-restyle` suppression as a known override: align controls to `rounded-xl`, overlay content to `rounded-2xl`, or move the styling into a named variant.
- Classify non-primitive `rounded-*` by role: bordered panels, dialogs, and list surfaces are `rounded-2xl`; links and list rows are `rounded-xl`; avatars, dots, and swatches stay `rounded-full`.
- Keep marketing pages and micro-elements (flags, kbd, empty icons) as explicit exceptions.
- Report findings grouped by priority with file:line so the next pass can pick a group.

## 5. Verify computed geometry, not just classes

- Run `pnpm --filter <app> run lint:design-system` and `pnpm --filter <app> run type-check`; run only the test file whose class-contract assertion changed, never the full unit suite for design-only radius edits.
- Start the dev server on its configured port and open the printed `localhost` origin, not `127.0.0.1`; check listeners with `ss -ltnp` and never kill an unowned server.
- Playwright: force each theme before paint with `context.addInitScript((t) => localStorage.setItem("theme", t), theme)`, read `getComputedStyle(el).borderRadius` per role, and assert identical values across themes.
- Assert one control token for button, input, select trigger, and toggle; keep one surface token for card, dialog, popover, dropdown menu, select content, and toast. Dialog is a surface, not a control.
- Measure closed trigger, input, and adjacent button separately: equal control radii, equal heights, and aligned bottom edges. Name trigger and popup separately in the report; the popup is intentionally one step rounder.
- Replace `space-y-*` field wrappers with `grid gap-*` or `flex gap-*`: Base UI Select adds a hidden input as the last child, so `space-y` puts margin-bottom on the trigger and shifts it one spacing step.
- Screenshot the design-system page in light and dark, view it before sending, then stop the dev server you started.

## 6. Report

- Name the preset chosen and why; list the single radius source and the token per component class; report lint/type/unit results and computed px values per theme; attach the screenshot; state whether the changes are committed.

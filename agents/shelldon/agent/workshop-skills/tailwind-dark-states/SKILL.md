---
name: tailwind-dark-states
description: "Implement an approved dark theme in Tailwind v4 + shadcn: per-theme tokens that actually vary, transitions that glide, disabled/pending states that stay dead."
---

# Tailwind Dark-State Hardening

Use when implementing approved dark-theme tokens or components in a
Tailwind v4 + shadcn codebase, or when hover/press/disabled states leak
across each other (a disabled button that still glows, lifts, or sweeps
on tap). The design itself is assumed approved — this skill is the
plumbing, not the taste.

1. **Keep per-theme values out of `@theme inline`.** Inlined values bake
   into utilities at build time, so overrides in theme blocks (radius
   scale, `--font-sans`) silently never apply. Put every varying key in a
   plain `@theme` block whose defaults preserve the light behavior
   exactly; keep only theme-invariant keys in `@theme inline`. Finish
   when `rounded-xl` and `font-sans` resolve differently per theme block.

2. **Transition `translate` and `scale`, never `transform`.** Tailwind v4
   implements translate/scale utilities as separate CSS properties, so a
   `transition-[transform,...]` never glides them — buttons snap instead
   of lifting. Name exact properties only
   (`transition-[translate,scale,background-color,border-color]`).
   Finish when press/hover visibly glide instead of jumping.

3. **Scope every interactive rule with `:not(:disabled)`.** Chrome still
   matches `:active` on disabled buttons, and a single global
   `:hover{background:…}` outranks a dimming class — so an untouched
   pending button brightens on tap. Write press as
   `:not(:disabled):active` and hover fills as `:not(:disabled):hover`,
   and gate hover motion behind
   `@media (hover:hover) and (pointer:fine)` (touch taps otherwise stick
   the hover state). Prefer an explicit `calm` class over `:has()`
   opt-outs — older browsers drop `:has` silently and the exemption
   vanishes without an error. Finish when tapping a disabled or pending
   control changes nothing but its own loop animation.

4. **Dim with `color-mix`, never `opacity`.** `opacity` dims the
   `box-shadow` glow along with the surface, so a glowing pending state
   goes flat. Mix the fill toward the page background instead
   (`color-mix(in srgb, <accent> 45%, <bg>)`) and keep the glow at full
   strength. Finish when the dimmed control still glows.

Verification: theme switch changes radius and fonts; press and hover
glide; tapping disabled/pending controls is visually inert; dimmed
controls keep their glow.

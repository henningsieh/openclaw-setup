---
name: ui-defect-repro-probe
description: Reported UI or visual defect needs reproduction against a running app; produce DOM/style evidence, the responsible code and original intent before any fix.
---

# Reproduce a UI defect with a browser probe

Use when the user describes a visual glitch (an element gets a ring, jumps, flickers) and asks you to start the app and confirm it.

## 1. Start the app in the mode the report describes

Run the production build when the user saw it in production; use a dev server only for a dev-only report.
Start long-lived services with the exec timeout disabled, because a killed server turns the repro into connection failures that look like defects.
Check: the port answers before you probe.
Open the app on the exact origin the dev server prints (`http://localhost:<port>`), not `127.0.0.1` or another loopback alias: Next.js dev blocks cross-origin `/_next/*` requests, and the page then renders without hydrating, so clicks, selects and theme switches silently do nothing. Check: before trusting any interaction, confirm React attached — a DOM node carries a `__reactFiber$…` key, or a theme click changes `document.documentElement.className`.

## 2. Write the probe as plain JS inside the app that owns Playwright

Place the script under the app whose `package.json` declares `@playwright/test` and run it with that directory as cwd; Node resolves the dependency from the script location, not from the repo root.
Use `.mjs` without TypeScript syntax: a cast such as `x as HTMLElement` is a syntax error under plain node.
Check: `node <script>.mjs <url>` prints the snapshot JSON instead of a module error.

## 3. Sample the live state over time

Record at several delays (0, 1, 3, 5, 7 s), because effects fire after hydration rather than at first paint. Capture for each sample:

- `document.activeElement` tag, text content and `tabindex`
- `getComputedStyle` outline width, style, color and offset
- `el.matches(":focus-visible")`

Take a screenshot in the same run, read it, then delete the probe script.
Check: the snapshot names the concrete element and the measured style values.

## 3b. Compare theme or variant tokens side by side

For a report that one theme or variant looks off, reproduce every variant instead of judging one.
Find how the app persists the choice — with next-themes, the localStorage key plus the class on `<html>` — and set it in `addInitScript` before navigation so the first paint already uses that variant.
Measure the tokens and the rendered property: read `getComputedStyle(document.documentElement).getPropertyValue("--radius-xl")` and the computed value on representative components, then report the numbers per variant.
Verify the CSS properties a variant's copy promises, not its class names: `border-<color>` sets only border-color, so the variant also needs `border` to render a width; an arbitrary `bg-[var(--token)]` whose token holds a gradient compiles to background-color and renders `background-image: none`, so write `bg-[image:var(--token)]`. Read `borderTopWidth`, `borderTopColor` and `backgroundImage` from the live node before saying the variant matches its description.
Save screenshots under the workspace artifacts directory; `view_image` refuses `/tmp`, so write or copy them there before reading.
Check: each variant has a JSON snapshot and a screenshot, and the reported difference is a measured delta, not an impression.

## 4. Find the responsible code and its age

Search the reported component for `.focus()`, `autoFocus` and `tabIndex={-1}`, then `git log -S "<exact expression>"` to date it.
Say whether the behaviour is a regression from recent work or pre-existing, naming the commit.
Check: you can cite file:line and the introducing commit.

## 5. Explain the original intent before proposing a change

Read the effect dependencies and the render branches: React runs an effect after the first render even when its dependency never changed, so focus on initial load is usually unintended while focus on a real view change is deliberate.
Confirm intent against sibling components and any test asserting `toHaveFocus()`.
Report in this order: measured evidence, mechanism, intended behaviour, then the narrowest fix options ranked; edit only after the user decides when they asked why the behaviour exists.

## 6. Fix the call, then pin both behaviours

Guard the effect on the previous dependency value (a `useRef` holding it) so the focus call fires only when the view genuinely changed, and keep the announcement for real transitions instead of deleting the call.
Add one test for the fixed case (no focus on the first render) and one for the preserved case (heading focused after a real change).
Assert focus with the matcher the runner ships: `toHaveFocus()` in jest-dom unit tests, `toBeFocused()` in Playwright specs; a typecheck rejects the wrong one.
For a "must not happen during load" case, install a recorder with `page.addInitScript` that pushes every `focusin` target into `window.__focusLog` before any page script runs, then assert the log never contains the tag: a visible element only proves server rendering, and one sample after a fixed delay misses a transient focus.
Prove the spec is sensitive before trusting it: revert the guard, watch the spec fail with the recorded tag, restore it, watch it pass.
Check: the restored spec passes against the production build, the reverted run failed with the recorded tag, and the full unit suite stays green.

## Standing preferences

- For theme or variant inconsistencies, cite the conflicting token declarations in the global stylesheet before starting the app; a central token with a derived scale in one block and hardcoded values in the others is the defect, and rendering only confirms the computed delta. For transient behavior such as focus jumps, reproduce first and never infer from source alone.
- Explain the originally intended behaviour before proposing the fix.
- Keep global focus styling untouched; fix the focus call, not the visible ring.

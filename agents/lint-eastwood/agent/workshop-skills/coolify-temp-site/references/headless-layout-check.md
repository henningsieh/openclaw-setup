# Headless layout check for a static page

Use when a screenshot shows overlap, overflow, or shifting but not the cause, or after a fix to prove overflow is zero and truncation engages.

## Steps

1. Serve the site directory locally: `python3 -m http.server <port> --bind 127.0.0.1` from the site dir, since `file://` URLs misbehave with storage and module scripts.
2. Drive the installed headless Chromium through `playwright-core` resolved from any repo's pnpm store: `find <repo>/node_modules/.pnpm -maxdepth 1 -name 'playwright-core@*'` then import `<match>/node_modules/playwright-core/index.mjs`; browsers already live in `~/.cache/ms-playwright` and need no install step.
3. Recreate reader state in `page.evaluate` (fill inputs, `dispatchEvent(new Event('input', { bubbles: true }))`), since truncation and overflow only appear with real content in place.
4. Measure, don't guess: require `document.documentElement.scrollWidth - clientWidth === 0`; for the suspect element compare `clientWidth` vs `scrollWidth` (ellipsis engages only when `scrollWidth > clientWidth` with `text-overflow: ellipsis` computed); walk `el.parentElement` logging `clientWidth` plus computed `display/min-width/overflow` to find the level where the width explodes.
5. Treat `min-width: auto` (the default) on a grid or flex item holding nowrap or unbreakable content as the prime suspect, since the item grows past its track and spills over siblings; read the walk from step 4 bottom-up and add `min-width: 0` to the first ancestor whose clientWidth jumps — with nested grids that level sits below the item already clamped (for example a grid rail whose cards are themselves grid items), so clamp every flagged level and re-run until overflow is 0.
6. For an ellipsis row that must not shift layout: give the truncating element `flex: 1 1 0%; min-width: 0; max-width: 100%; overflow: hidden; white-space: nowrap; text-overflow: ellipsis`; clamp every ancestor up to the fixed track with `min-width: 0`; hold the row on a fixed `min-height` with identical box metrics in empty and filled states; confirm equal row heights across states and zero `pageerror` events before deploying.

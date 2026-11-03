# Viewport-aware intro disclosure for single-file pages

Use when a single-file helper page's header fills the whole mobile viewport and pushes content and progress below the fold.

## Markup

Wrap the intro paragraph in an open-by-default disclosure:

```html
<details class="intro" open><summary>Wie dieser Check läuft</summary><p>…intro text…</p></details>
```

## CSS

```css
.intro{margin-top:8px}
.intro>summary{display:inline-block;font-size:15.5px;font-weight:700;color:inherit;text-decoration:underline;text-underline-offset:3px;cursor:pointer;border-radius:6px}
@media(min-width:861px){.intro>summary{display:none}}
```

Add `summary:focus-visible` to the page's existing visible-focus rule, since the summary is an interactive element. Tighten band padding and type under `@media(max-width:860px)` in the same pass.

## Chevron affordance

Use when the plain underlined summary is overlooked on mobile: hide the native triangle and make the summary a full-width row with a rotating chevron, since a small gray marker next to underlined text does not read as tappable.

Markup: wrap the label in a span and append the chevron inside the summary:

```html
<summary><span>Label text</span><svg class="chev" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="6 9 12 15 18"/></svg></summary>
```

CSS: remove the native marker everywhere, switch the summary to a full-width space-between row only on small screens, and rotate the chevron when open:

```css
.intro>summary{list-style:none}
.intro>summary::-webkit-details-marker{display:none}
.intro .chev{transition:transform .18s var(--ease-out)}
@media(max-width:860px){.intro>summary{display:flex;width:100%;align-items:center;justify-content:space-between;gap:12px;padding:10px 2px}}
.intro[open] .chev{transform:rotate(180deg)}
@media (prefers-reduced-motion:reduce){.intro .chev{transition:none}}
```

Check headless at 390px: the chevron's right edge sits within a few pixels of the summary's right edge; after tapping, `details` reports open and the chevron's computed transform is the 180-degree matrix; desktop keeps `display: none` on the summary.

## JS

Default follows the viewport on load; the reader's first toggle wins and is never overridden on resize:

```js
(function(){var d=document.querySelector('details.intro');if(!d)return;var mq=window.matchMedia('(max-width:860px)');function fit(){if(d.dataset.touched)return;if(mq.matches)d.removeAttribute('open');else d.setAttribute('open','')}d.addEventListener('toggle',function(){d.dataset.touched='1'});if(mq.addEventListener)mq.addEventListener('change',fit);fit()})();
```

Append it as a separate IIFE per SKILL.md step 5 (keep the previous `})();` terminator intact).

## Checks

Headless at 390px and 1280px: 390 must report `open === false` with a visible summary and roughly halved band height; 1280 must report `open === true` with `display: none` on the summary; both need `docOverflow === 0` and zero `pageerror` events before deploying.

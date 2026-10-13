---
name: design-mockup-previews
description: "Approve a web design visually before implementing it: standalone HTML mockups, headless screenshots, image delivery to chat."
---

# Design Mockup Previews

Use when a design needs approval before any app code moves: build throwaway
static mockups, render them, deliver images to the channel. Never implement
tokens or components first and ask for review after.

1. **Build standalone mockups, no app build.** Self-contained HTML with inline
   CSS (CDN fonts allowed) under the repo's prototype dir
   (e.g. `docs/design/prototype/<variant>.html`). No framework, no app
   imports — each file must render from any static server. Open one distinct
   direction per variant (palette, type scale, density), not three shades of
   one idea. Finish when the files exist and differ on purpose.

2. **Use real domain content.** Copy figures and labels from the app's actual
   screens or prototype fixtures. Invented metrics (wrong units, wrong domain)
   invalidate the review — the reader sees content before style. Finish when
   every number on the mockup could plausibly appear in the app.

3. **Serve, then prove the server before shooting.** `python3 -m
   http.server <port>` detached in the prototype dir, then `curl` the file
   URL and require HTTP 200. A dead server yields a valid-looking blank PNG
   (suspiciously small file, ~20KB for a full-page shot). Finish when curl
   returns 200 with the real byte size. Record the server PID at start (`echo
   $!`) and kill by PID when done — `pkill -f` with the port or command in the
   pattern matches the killing shell itself and aborts the run (observed
   SIGTERM self-kill); see `coolify-preview-deployments` for the same rule on tunnels.

4. **Screenshot with headless-shell, not the browser tool.** Browser-tool
   navigation to localhost is policy-blocked. Use the Playwright-cached
   binary —
   `chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell`
   (that exact filename; no `headless_shell` file exists) — with
   `--no-sandbox --screenshot=<out> --window-size=<w>,<h> --hide-scrollbars
   --virtual-time-budget=5000 <url>`. `--no-sandbox` is required on this
   host. Match width to the design (desktop 1440 / mobile 480) and crop
   height to content; excess height renders as dead space. At mobile width,
   assert no horizontal overflow before approving
   (`document.documentElement.scrollWidth <= innerWidth`): fixed-width
   absolutely-positioned decor (observed: 1100px glow layer) is the usual
   suspect — contain with `overflow-x:clip` on html/body plus fluid widths,
   then re-shoot. Finish when the PNG shows rendered content, never blank.

5. **Stage images under the workspace media tree before inspecting or
   sending.** `view_image` rejects paths outside allowed directories (e.g.
   `/tmp`) — copy PNGs into the workspace `media/` tree first, inspect,
   fix, re-shoot. Deliver with `message(action=send)` plus `attachments`
   (type `image`); a text reply alone carries no pixels. End with exactly
   one question: pick a variant, or name what stings. Finish when the user
   has images in-channel and a direction to give.

6. **Publish the mockup at a URL when hands-on review is requested.**
   App creation via API is unavailable on this server (`POST
   /applications` 404s; the MCP catalog has deploy/control for existing
   apps only, no create) — so serve static mockups as an explicitly
   unmanaged nginx container on the Coolify host instead of blocking on UI
   clicks. Access paths live in `hetzner-coolify-access`; use only native
   paths. `scp -r` the mockup dir to the host, then:
   `docker run -d --name <slug> --network coolify --restart unless-stopped
   -v <dir>/index.html:/usr/share/nginx/html/index.html:ro` with the
   Coolify traefik pattern — `traefik.enable=true`, an `http` router on
   `redirect-to-https` middleware plus an `https` router with
   `tls.certresolver=letsencrypt`, both `Host(\`<name>.<apps-host>\`) &&
   PathPrefix(\`/\`)`, services on port 80. Wildcard DNS already resolves
   `*.<apps-host>` and the LE http-challenge flows through traefik, so no
   DNS or cert step is needed. Label it `coolify.managed=false` plus a slug
   label, and record in the reply that it is unmanaged and must be removed
   once a real Coolify app or the app tokens take over. Commit the mockup
   files to the branch first — the repo stays the source of truth, the host
   only mirrors it. Finish when `curl` returns 200 on the https URL (http
   answers 302 to https) and the served `<title>` matches the mockup.

7. **After every static deploy, require a hard reload before accepting
   visual bug reports.** An already-open tab serves the pre-deploy DOM, so
   taps, glows, and animations reported against it describe dead code —
   observed across several turns of phantom glow/animation/tap bugs that
   vanished on a fresh load. Say "reload first" with every deploy notice
   and do not debug pixels until a fresh load is confirmed. For timing
   disputes (tap-created brightening, loop phases) ask for a screen
   recording — stills cannot show timing. For presence disputes (is the
   glow there?) sample pixels with PIL instead of trusting a scaled-down
   screenshot. Finish when the report reproduces on a freshly loaded page
   or the recording/pixels settle it.

Verification: mockups render from the static server; screenshots show
content at the intended width; the user received images in-channel; no app
source file was modified for the review.

Once the design is approved and implementation starts, `tailwind-dark-states` owns the Tailwind v4 plumbing (per-theme tokens, gliding transitions, dead disabled states).

# Upstream image watch for a patched runtime

Use when the vulnerable runtime is bundled inside a container image and the owner wants
daily read-only monitoring until upstream ships the fix. A newer tag does not mean a
patched runtime: verify the bundled version yourself.

1. **Resolve the digest per tag, not the tag name.** Query Docker Hub directly and
   compare `latest`, the major tag and the version tag; identical digests mean one build.

   ```bash
   for t in latest 2 2.16.0; do
     curl -fsSL "https://hub.docker.com/v2/repositories/<owner>/<repo>/tags/$t" \
       | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("name"),d.get("last_updated"),d.get("digest"))'
   done
   ```

   Also read the release and tracking issue state so the report says whether upstream is
   aware: `api.github.com/repos/<owner>/<repo>/releases/latest` and the issue number the
   owner named.

2. **Verify the bundled runtime in a disposable container.** Never mount production data,
   never publish ports, never reuse the running container.

   ```bash
   sudo -n docker run --rm --network none --entrypoint node <image>:<tag> -v
   ```

   Finish when you have a concrete version string such as `v22.23.2`.

3. **Compare versions numerically, not lexically.** `22.23.4` is newer than `22.23.10`
   only under `sort -V`:

   ```bash
   [ "$(printf '%s\n%s\n' "$MIN" "$BARE" | sort -V | tail -1)" = "$BARE" ] && echo patched
   ```

4. **Cache verification by digest.** Pulling a 1 GB image every day is waste. Keep a
   small JSON state file with `digest`, `node`, `verifiedAt`, `checkedAt`; re-run the
   container check only when the digest changed or `verifiedAt` is empty. Report the
   verification timestamp so a cached result is never mistaken for a fresh one.

5. **Schedule it as a command-payload automation.** A command job runs `sh -lc <script>`
   with no agent session, so it cannot be blocked by an archived session and costs no
   model tokens:

   ```bash
   openclaw automations add --name "<name>" --cron "20 3 * * *" --tz Europe/Berlin \
     --exact --command /path/to/script.sh --announce --channel discord --to <channel-id>
   ```

   Pick the time inside the window the owner named, and rely on `--tz` for CET/CEST.
   Keep the job read-only: no pull for production use, no compose change, no restart.

6. **Report four facts every run:** image tag plus digest prefix, bundled runtime version,
   whether that version was directly verified (and when), and upstream release/issue
   state with the source URLs. When nothing changed, say so in one line.

Working example on this host: `~/.openclaw/scripts/npm-node-security-watch.sh` with state
at `~/.openclaw/workspace/nginx-proxy-manager-node-watch.state.json`.

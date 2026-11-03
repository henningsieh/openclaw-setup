---
name: "runtime-patch-verification"
description: "Node.js/Python/OpenSSL security advisory or a just-installed patch: prove running processes still use the old binary, then restart the owning service."
---

# Runtime Patch Verification

Use when a runtime publishes a security release, the owner asks whether the host is
affected, or a package upgrade has just run and the service must be proven patched.
Installing the new package is not the fix: long-lived processes keep the old binary
mapped until they restart.

1. **Pin the fixed version per release line before checking anything.** For Node.js,
   read the vendor feed and the release index:

   ```bash
   curl -fsSL https://nodejs.org/en/feed/blog.xml | grep -i -m3 security
   curl -fsSL https://nodejs.org/dist/index.json | python3 -c '
   import sys,json
   d=json.load(sys.stdin)
   seen=set()
   for r in d:
       major=r["version"].split(".")[0]
       if major in seen: continue
       seen.add(major)
       print(r["version"], r["date"], "lts="+str(r["lts"]), "security="+str(r.get("security")))
   '
   ```

   A release with `security=True` is the fixed build for that line; the newest entry
   without it is not. Finish with the exact fixed version for the line the host runs.

2. **Compare installed against fixed, and note the package revision mapping.**

   ```bash
   node -v
   dpkg -s nodejs | grep -E '^(Version|Status)'
   apt policy nodejs
   apt-get -s install --only-upgrade nodejs | tail -3
   ```

   A NodeSource version like `24.22.1-1nodesource1` corresponds to runtime `v24.22.1`;
   do not compare the package string to `node -v` literally. Finish when installed and
   fixed versions are stated in the same notation.

3. **Test the running process, not the installed binary.** An in-place upgrade replaces
   the path while the running process keeps the old image; `/proc` then shows a deleted
   target.

   ```bash
   pid=$(systemctl show <unit> -p MainPID --value)
   ps -o pid,lstart,etime,cmd -p "$pid"
   readlink /proc/$pid/exe           # '/usr/bin/node (deleted)' means old image
   stat -c '%y %n' /usr/bin/node     # install time to compare with process start
   strings /proc/$pid/exe | grep -m1 -E '^v[0-9]+\.[0-9]+\.[0-9]+$'
   ```

   A process started before the install timestamp runs the old code even when `node -v`
   already reports the patched version. Enumerate every long-lived runtime process, not
   just the main one:

   ```bash
   for p in /proc/[0-9]*; do
     pid=${p#/proc/}
     exe=$(readlink "$p/exe" 2>/dev/null) || continue
     case "$exe" in *node*) echo "$pid $exe | $(tr '\0' ' ' <"$p/cmdline" | cut -c1-90)";; esac
   done | grep deleted
   ```

   Finish when each runtime process is classified as patched or old, with its version and
   start time.

4. **Restart the owning service, then prove the new image is live.** `/restart` in chat
   is an in-process SIGUSR2 reinitialization: it recycles sessions but keeps the same PID
   and the same mapped binary, so it never loads the patched runtime. Ask the owner to run
   `sudo systemctl restart openclaw-gateway` on the host instead; never run `openclaw
   update`, a gateway restart, or a detached service restart through exec from the agent.
   For other units use `systemctl restart <unit>` with the normal approval. Then verify:

   ```bash
   systemctl show <unit> -p MainPID -p ActiveEnterTimestamp --value
   readlink /proc/$newpid/exe                   # must not end in ' (deleted)'
   strings /proc/$newpid/exe | grep -m1 -E '^v[0-9]+\.[0-9]+\.[0-9]+$'
   systemctl is-active <unit>
   ```

   A changed PID and `ActiveEnterTimestamp` is the proof of a real reload; a chat reply
   saying it is back is not, because the in-process path answers while the old binary
   stays mapped.

   A restart replaces its worker children too, so re-run the enumeration from step 3 and
   finish when it prints nothing.

5. **Audit secondary runtimes that do not share the system package.** Separate apps with
   their own pinned Node (for example Ghost under `/var/lib/ghost` running
   `node current/index.js`) keep their old runtime across a system upgrade:

   ```bash
   pid=$(pgrep -f 'current/index.js' | head -1)
   readlink /proc/$pid/exe
   strings /proc/$pid/exe | grep -m1 -E '^v[0-9]+\.[0-9]+\.[0-9]+$'
   ```

   An end-of-life line receives no build from the advisory at all; report it as an upgrade
   item, not as patched. Finish when every runtime on the host is either on a supported,
   patched version or named as an open upgrade.

6. **Watch an upstream image until it ships the fix.** When the vulnerable runtime is
   bundled in a container image, monitor the image digest and verify the bundled version
   in a disposable container instead of assuming a newer tag means patched Node. Follow
   `references/upstream-image-watch.md`.

Verification: the fixed version came from the vendor release index, the installed version
was read from the package and from `node -v`, each long-lived process was classified by its
`/proc/<pid>/exe` target and start time, the owning service was restarted by the owner or
with approval, and the post-restart enumeration shows no process on a deleted or old
binary. A green `node -v` alone is not evidence that the running service is patched.

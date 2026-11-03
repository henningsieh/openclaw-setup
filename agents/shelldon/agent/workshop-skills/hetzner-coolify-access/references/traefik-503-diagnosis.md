# Traefik 503 on the Coolify host

Symptom: a domain that resolves to the Coolify server answers `503` with Traefik's `no available
server`, and the Coolify API/UI lists no application for it. The route's backing container is
missing; the proxy, DNS and certificates are usually fine.

1. Confirm the domain resolves to the Coolify public IP, then SSH in with the workspace key
   (`coolify-access.md` section 1):
   ```bash
   dig +short <domain>            # expect 188.245.144.137
   ssh -i ~/.openclaw/workspace/coolify-server-access/ssh_key root@10.0.0.3
   ```

2. Find the container by name, then by its Traefik label. The container name often differs from
   the domain, so an empty name grep is not evidence of absence:
   ```bash
   docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Image}}' | grep -i <slug>
   for c in $(docker ps -aq); do
     docker inspect "$c" 2>/dev/null | grep -qi "<domain>" &&
       echo "$c $(docker inspect -f '{{.Name}} {{.State.Status}}' "$c")"
   done
   ```
   Use `docker ps -a`: a stopped container comes back with `docker start <name>`, no recreate
   needed.

3. Read the container's labels and mounts to see the exact router/service pair and the served path
   it was built with:
   ```bash
   docker inspect <name> -f '{{json .Config.Labels}}' | tr ',' '\n'
   docker inspect <name> -f '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}'
   ```

4. Probe the certificate: a cert present in `acme.json` proves the route once worked and only the
   container is gone, so no DNS or cert step is needed:
   ```bash
   grep -o "<domain>" /data/coolify/proxy/acme.json
   ```

5. When no container owns the domain, check the file-provider routes before blaming Traefik:
   ```bash
   ls /data/coolify/proxy/dynamic/
   grep -rl "<domain>" /data/coolify/proxy/dynamic/
   ```

6. Restart a stopped container (`docker start <name>`) or recreate a removed one from its recorded
   label set — the unmanaged-nginx recipe with the full label list is `design-mockup-previews`
   step 6. Traefik's docker provider reads container labels live, so the route returns without
   restarting the proxy.

7. Verify from the gateway host, not from the Coolify host, and expect the app's own title:
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' "https://<domain>/"
   curl -s "https://<domain>/" | grep -o '<title>[^<]*</title>'
   ```

No Coolify application for the domain is normal for an unmanaged container (`coolify.managed=false`)
— report it as unmanaged and due for removal once a real app takes over, not as a broken setup. A
query parameter that changes nothing server-side (for example a theme switch) is read by the served
page's own script, so re-read the page source before hunting for a server setting.

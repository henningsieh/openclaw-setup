---
name: host-stack-updates
description: "Mailcow, Nextcloud or Nginx Proxy Manager update pending, Portainer compose conflict, or new Mailcow domain needs mail-DNS proof: update safely and verify."
---

# Host Stack Updates

Mailcow and Nextcloud updates on the host server. The agent runs directly on the host with NOPASSWD sudo. Prefer the existing automation over manual updates.

1. **Mailcow: trigger the nightly automation, never run update.sh by hand.** Check with `sudo -n /usr/local/bin/mailcow-update --check`: exit 0 plus "Updated code is available" means an update is pending, exit 3 means current. If pending, run `openclaw automations run 5c4e5d00-6303-4bf6-908d-d6c23df93277` (verify the id with `openclaw automations list` if enqueue fails). The job checks, updates, health-checks all mailcow containers, and announces to its delivery channel. Confirm with `openclaw automations runs <job-id>` until the summary reads "update successfully installed". Finish when run summary and container health are collected.

2. **Nextcloud (Portainer stack): pass the compose project name explicitly.** The stack file lives under `/var/lib/docker/volumes/portainer_data/_data/compose/20/docker-compose.yml`, but the live project name comes from the container label `com.docker.compose.project` (read via `docker inspect nextcloud-app`), not the directory basename. Running without `-p` creates a stray network and fails with container-name conflicts. Update with `sudo docker pull nextcloud:32` then `sudo docker compose -f <path> -p nextcloud up -d`, so only the app container is recreated while db and redis keep running. Finish when the app container is recreated from the new image.

3. **Finish a Nextcloud image bump with occ upgrade.** New base images can jump many patch versions, set `needsDbUpgrade: true`, and bundle the PHP security fix (verify with `php -v` inside the container). Run `sudo docker exec --user www-data nextcloud-app php occ upgrade`, then `occ maintenance:mode --off` if maintenance is still enabled after a successful upgrade. Verify with `occ status` (maintenance false, needsDbUpgrade false) and `occ update:check` ("Everything up to date"). Finish when all three readbacks are clean.

4. **Onboard a new Mailcow domain by verifying public mail DNS with dig.** Check all four classes and compare a new subdomain against its parent pattern:
   ```bash
   dig +short MX <domain>
   dig +short TXT <domain>
   dig +short TXT _dmarc.<domain>
   dig +short TXT dkim._domainkey.<domain> | cut -c1-80
   ```
   Accept `MX 10 mail.sieh.org.`, an SPF `v=spf1 mx ip4:195.201.42.226 ip6:2a01:4f8:c0c:5bd4::1 a:mail.sieh.org -all` (adapt IPs per host), a DMARC `v=DMARC1; p=quarantine; ...`, and a `v=DKIM1...` key (split across two quoted strings is normal). Treat a missing SPF or DMARC as incomplete even when the parent `_dmarc` `sp=` policy covers the subdomain; request explicit records. Finish when all four classes answer correctly.

5. **Nginx Proxy Manager is the reverse proxy for every site, so treat a version bump as a planned outage.** The compose file is `/var/lib/docker/volumes/portainer_data/_data/compose/1/docker-compose.yml`, project `nginx-proxy-manager`, service `nginx-proxy`, container `nginx_proxy_manager`. The image is pinned by tag, so a bump means editing that tag, not pulling `:latest`. Keep the static `web_traffic` address (172.25.0.20): the Gateway and Nextcloud pin it as trusted proxy, and losing it breaks client-IP handling. Prepare before touching the running container, since a recreate drops all proxied sites including `ai.sieh.org` for roughly 30-60 seconds and needs explicit owner approval:
   ```bash
   sudo tar -C /opt/nginx-proxy-manager -czf /var/backups/npm/npm-data-$(date +%Y%m%d-%H%M%S).tar.gz data letsencrypt
   sudo docker pull jc21/nginx-proxy-manager:<new-tag>
   sudo docker run --rm --network none --entrypoint node jc21/nginx-proxy-manager:<new-tag> -v
   ```
   Read the new tag's release notes for breaking changes, and check whether any certificate uses a DNS-01 challenge (copy `data/database.sqlite` out and look for `dns_challenge` in `certificate.meta`): certbot plugin breakage only affects DNS-challenge certificates, HTTP-01 ones are unaffected.

   Clear orphaned certificates before recreating, or startup certbot renewal fails against domains that no longer resolve. List `certificate` rows with `is_deleted=0` that no `proxy_host`, `redirection_host`, `dead_host` or `stream` row references, ask the owner whether they are obsolete, then delete them through NPM's own modules inside the container. Assert the row moved to `is_deleted=1` and that `live/npm-<id>`, `archive/npm-<id>` and `renewal/npm-<id>.conf` are gone. Revoking an expired certificate reports an error while the deletion still succeeds, so judge by the DB row and the files, not by the revocation message.

   Then raise the tag in the compose file and recreate only that service with `sudo docker compose -f <path> -p nginx-proxy-manager up -d nginx-proxy`. Verify container up, `sudo docker exec nginx_proxy_manager nginx -t`, the static IP still attached, and every critical service answering over its public hostname — including the proxy's own UI — with the internal admin port only as an extra check. An internal-IP check alone does not prove the public route. Finish by reading `sudo docker logs --since <checks start> nginx_proxy_manager` and requiring no error, fail or emerg lines. Roll back by restoring the previous tag and the data tarball if the new image migrated the database.

Verification: Mailcow run summary success; Nextcloud version string advanced, PHP version advanced, maintenance off, update check clean; new mail domain answers all four DNS classes; Nginx Proxy Manager on the new tag with `nginx -t` clean, an HTTPS request answered and the static proxy IP intact.

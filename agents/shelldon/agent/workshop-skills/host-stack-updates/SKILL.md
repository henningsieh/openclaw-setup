---
name: host-stack-updates
description: "Mailcow/Nextcloud update pending, Portainer compose conflict, or new Mailcow domain needs mail-DNS proof: update safely, fix names, verify health and DNS."
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

Verification: Mailcow run summary success; Nextcloud version string advanced, PHP version advanced, maintenance off, update check clean; new mail domain answers all four DNS classes.

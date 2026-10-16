---
name: immich-update-operations
description: "Update Immich with its guarded release updater; diagnose failed version checks, compose pin parsing, deployments, health, or exit codes."
---

# Immich Update Operations

Use for Immich container updates and their failures. General asset/library work belongs to immich-operations. Host paths, backup schedule, automation and root-only updater are authoritative in the instance runbook: /home/shelldon/.openclaw/docs/runbooks/immich-operations.md.

1. **Read live state before an update or retry.** Check the installed version label, all Immich container health, root-disk space, recent updater log entries and whether a recent database backup exists. The host updater requires a .sql.gz backup younger than 48 hours. Use 97% as this procedure's disk stop threshold; it is an operator preflight, not an assumed script guard. Run sudo -n /usr/local/bin/immich-update --check: exit 0 means current, exit 2 means update available, other codes indicate error. Finish when current version, target, backup, disk and health are known.

2. **Use the tagged release asset as Compose truth.** Immich's docker/README.md warns that main may not match the latest release. For target vX.Y.Z, inspect https://github.com/immich-app/immich/releases/download/vX.Y.Z/docker-compose.yml; do not substitute docker/docker-compose.yml from main, whose digests can differ. Compare service names and pinned image lines in the tagged asset with the local compose. The service is named redis even when its image is Valkey; never infer service name from image name. Finish when the tag asset is valid and redis and database digest pins are found.

3. **Parse service blocks without a range that closes on its opening line.** The old pattern, awk range from /^  $svc:/ to /^  [a-z-]+:/, is broken: its end regex also matches the opening service header (redis:), so AWK closes the range immediately and grep finds no image. This range bug can produce that failure even when the tagged Compose has the pin. Use a stateful parser or YAML parser. Tested AWK alternative (run against the downloaded asset):

    awk -v svc="$svc" '
      $0 == "  " svc ":" { inside=1; next }
      inside && /^  [[:alnum:]_-]+:[[:space:]]*$/ { exit }
      inside && /^    image:[[:space:]]/ { sub(/^    /, ""); print; found=1; exit }
      END { if (!found) exit 1 }
    ' "$upstream_file"

   Validate the extracted image against the digest format before editing local Compose. Fail closed if a required service or digest is missing. Finish when a fixture with the tagged v3.3.3 layout yields the exact redis image and database pin, while the old range expression fails.

4. **Keep cleanup traps safe under set -u.** A RETURN trap referring to a function-local upstream_file can fire after that variable has left scope, causing an unbound-variable error after compose deployment and health checks succeeded. Use a safe expansion such as ${upstream_file:-} in the cleanup (or explicitly clear/restore the trap). Then run bash -n and --check. This is separate from deployment status: verify containers and version, and require updater exit 0. Finish when syntax and check-only exit are clean.

5. **Run the guarded update only after preconditions pass.** Invoke the host's root-only updater, sudo -n /usr/local/bin/immich-update. It verifies the backup, syncs only redis/Valkey and database digest pins from the release asset, then runs docker compose pull and up -d. Preserve local Portainer/network overrides; review any local compose diff before applying. Do not run unrelated application tests or modify other services. Finish when the updater reports the target version and exits 0.

6. **Verify independently.** Require all four containers (immich_server, immich_machine_learning, immich_redis, immich_postgres) healthy, the immich_server version label equal to target, the updater log's success line, and sudo -n /usr/local/bin/immich-update --check returning “Immich ist aktuell” with exit 0. A successful check-only is not proof of an upgrade. Finish when each readback is collected.

7. **On failure, classify before retrying.** Read /var/log/immich-update.log, current container versions/health, and the tagged release asset. “No image pin for service” means parser/source mismatch: prove the tagged asset has the named service and digest, then repair the parser—not an already-correct local compose. If containers reached the new version but updater exits non-zero during cleanup, report deployment applied but command failed; repair the trap, syntax-check, and verify with --check. If pull/up/health failed, preserve the pre-update compose backup and diagnose that stage before another attempt.

Verification: use tagged release Compose, not main; collect backup/disk preflight, parser validation, updater exit, four health/version checks and final check-only exit. No unrelated tests or services changed.

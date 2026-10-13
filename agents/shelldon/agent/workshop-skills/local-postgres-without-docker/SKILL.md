---
name: local-postgres-without-docker
description: "Need a throwaway local PostgreSQL but docker is unavailable (no socket permission) and no server binaries exist: provision one from the embedded-postgres npm package, start it on a loopback fixture port, and prove the connection before migrating or seeding."
---

# Local PostgreSQL Without Docker

Use when tests or migrations need a real PostgreSQL and neither `docker` nor system server binaries (`initdb`, `postgres`) are available. Verified end to end: install, TCP start, create database, `drizzle-kit migrate`, seed, disposable-database suites green.

1. **Confirm docker is really out, then take the npm binaries.** `docker ps` failing with socket permission denied plus missing `initdb`/`postgres` (client-only `psql` is fine) means this skill applies. In a scratch dir (`/tmp/pgtest`, never the repo): `npm init -y` + `npm install embedded-postgres`. Server binaries land at `node_modules/@embedded-postgres/linux-x64/native/bin/` (`initdb` and `postgres` present; `pg_isready` absent — use the system one).
2. **Do not rely on the node wrapper for anything that must outlive the session.** `new EmbeddedPostgres().start()` works, but the child dies with the launching session and defaults to Unix-socket-only listen. Instead `initdb` + `pg_ctl` directly:
  ```sh
  EB=<scratch>/node_modules/@embedded-postgres/linux-x64/native/bin
  $EB/initdb -D <scratch>/data -U postgres --auth=trust
  $EB/pg_ctl -D <scratch>/data -l <scratch>/pg.log \
    -o "-c listen_addresses='127.0.0.1' -p 55433 -k /tmp" start
  ```
  Match the port/auth the repo's fixture docs prescribe (trust auth is fine: loopback-only, disposable data). Finish when `pg_isready -h 127.0.0.1 -p <port>` reports accepting connections.
3. **Prove the full chain before calling it done.** `CREATE DATABASE`, run the project's real `migrate` with the fixture `DATABASE_URL`, re-run `migrate` as a no-op check, then seed and one DB-backed suite. Finish when migrate + no-op + seed + suite are all green against the fixture URL — a listening port alone is not proof.

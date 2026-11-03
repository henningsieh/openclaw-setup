---
name: dev-db-seed-inspection
description: "Checking seeded app data in a development database: locate DATABASE_URL, inspect tables, query fixture rows, report counts without exposing credentials."
---

# Dev database seed inspection

Use when a UI shows missing or unexpected seed data, or when asked to verify the development database state instead of inferring it from seed source.

## 1. Locate the database configuration

```bash
ls -la .env* */.env* apps/*/.env* packages/*/.env* 2>/dev/null
grep -R "DATABASE_URL" --include=".env*" -l . 2>/dev/null
```

Read the file that defines `DATABASE_URL`. Do not paste its value into chat or logs.

## 2. Load the URL without printing it

```bash
set -a
. path/to/.env
set +a
node -e 'const u=new URL(process.env.DATABASE_URL); console.log(JSON.stringify({protocol:u.protocol,host:u.hostname,port:u.port||"(default)",db:u.pathname.slice(1)}))'
```

Confirm the target host and database name. If `psql` is missing, use the project's database client or a container; do not install packages globally.

## 3. Discover the schema before writing queries

```bash
psql "$DATABASE_URL" -X -A -F $'\t' -c "select table_name from information_schema.tables where table_schema='public' order by table_name;"
```

Inspect columns for each relevant table:

```bash
psql "$DATABASE_URL" -X -A -F $'\t' -c "select column_name, data_type from information_schema.columns where table_schema='public' and table_name='<table>' order by ordinal_position;"
```

Use the actual column names. ORM camelCase fields are often snake_case columns.

## 4. Query the seed state

Start with counts, then list the rows that explain the UI:

```bash
psql "$DATABASE_URL" -X -A -F $'\t' -c "select count(*) from <table>;"
psql "$DATABASE_URL" -X -A -F $'\t' -c "select <columns> from <table> order by <stable columns> limit 50;"
```

For membership-scoped data, join the user, organization, and membership tables and filter by the reported account. For seeded fixtures, compare expected names or slugs with actual rows.

## 5. Report

State the database host and name, the query result counts, and the specific rows that explain the behavior. Never include the connection string, password, or token. Distinguish "data missing", "data present but filtered by active organization or permissions", and "data present and the UI is wrong".

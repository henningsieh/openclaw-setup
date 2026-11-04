---
name: channel-config-retirement
description: Channel removed but references remain: enumerate every leftover, ask migrate or retire per item, unset each path, verify none remain.
---

# Retire or migrate a messaging channel in OpenClaw config

Use when a channel block was deleted from `openclaw.json` but its settings still appear elsewhere, or when migrating a channel's settings to another channel.

## 1. Inventory every reference before changing anything

```bash
cd ~/.openclaw && grep -n -i "<channel>" openclaw.json
```

Grep finds values and keys in flat lines. Also walk the parsed config, because keys nested under arrays (bindings) and objects (migrations) are easy to miss:

```bash
cd ~/.openclaw && python3 - <<'PY'
import json
c = json.load(open('openclaw.json'))
def walk(o, p=''):
    if isinstance(o, dict):
        for k, v in o.items():
            np = f"{p}.{k}" if p else k
            if '<channel>' in k.lower():
                print('KEY:', np, '=', json.dumps(v)[:200])
            walk(v, np)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            walk(v, f"{p}[{i}]")
walk(c)
PY
```

The recurring locations are `plugins.entries.<channel>`, `meta.migrations.webhookListeners.<channel>`, `commands.ownerAllowFrom`, `approvals.plugin.targets[]`, `bindings[].match.channel`, and per-agent `heartbeat.target`/`to`. Check `channels` separately; the block is often already gone while these remain.

## 2. Get one decision per reference

Ask the owner one item at a time with a migrate/retire choice and a recommendation; do not batch the questions. Authorization entries (`ownerAllowFrom`, approval targets) migrate so owner commands keep working; bookkeeping and plugin entries with no equivalent retire.

Map identity fields to the surviving channel's real IDs before proposing a migration. A user ID from the retired channel is never valid on the new one.

## 3. Back up once, then apply path-scoped removals

```bash
cd ~/.openclaw && cp -a openclaw.json "openclaw.json.bak.pre-<channel>-migration-$(date +%Y%m%d-%H%M%S)"
openclaw config unset <dot.path> --dry-run
openclaw config unset <dot.path>
```

Use `config unset` with the exact dot path instead of rewriting the JSON; a full rewrite drops sibling keys and reformats the file. The command reports whether the change needs a gateway restart.

For one element of an array (`approvals.plugin.targets`, `bindings`), `config unset` cannot target it. Copy the file first, filter the element on the parsed JSON, write it back with `json.dump(c, f, indent=2, ensure_ascii=False)` plus a trailing newline, then `diff` the copy against the result and confirm only the intended lines disappeared.

If a `config set` or `config unset` call hangs or is killed, read the file before retrying: the write may already have landed, and a blind retry can duplicate an entry.

## 4. Verify no orphans remain

```bash
cd ~/.openclaw && grep -c -i "<channel>" openclaw.json
openclaw config validate
openclaw channels list
```

Zero grep hits, `Config valid`, and a channel list containing only the surviving channel is the completion check. Report each item's outcome as migrated or retired.

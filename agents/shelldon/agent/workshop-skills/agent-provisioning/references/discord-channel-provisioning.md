# Discord Channel Provisioning for a New Agent

Reference for step 6 of `agent-provisioning`: creating the channel, writing the allowlist entry, and shaping the peer binding that actually matches.

## Create the channel with the Discord REST API

The bot token in `channels.discord.token` is usually a `${VAR}` reference. Resolve it from the env file the Gateway loads, then call the API with the **`Bot` prefix** and a **`User-Agent`** header — Python's default `urllib` agent gets `403` with error code `1010` from Cloudflare, and a `Bearer` prefix gets `401`.

```python
import json, os, re, urllib.request, urllib.error

cfg = json.load(open('/home/shelldon/.openclaw/openclaw.json'))
name = re.match(r'^\$\{(.+)\}$', cfg['channels']['discord']['token']).group(1)
val = None
for path in ['/home/shelldon/.openclaw/.env', '/home/shelldon/.env']:
    if os.path.exists(path):
        for line in open(path):
            if line.strip().startswith(name + '='):
                val = line.split('=', 1)[1].strip().strip('"').strip("'")
                break
    if val:
        break

H = {'Authorization': 'Bot ' + val,
     'User-Agent': 'DiscordBot (https://github.com/henningsieh/openclaw-setup, 1.0)',
     'Content-Type': 'application/json'}
G = '<guildId>'

body = json.dumps({'name': '<channel-name>', 'type': 0,
                   'parent_id': '<categoryId>',
                   'topic': '<description>'}).encode()
req = urllib.request.Request(
    f'https://discord.com/api/v10/guilds/{G}/channels', data=body, headers=H, method='POST')
d = json.load(urllib.request.urlopen(req, timeout=25))
print('CREATED', d['id'], d['name'])
```

Make the call idempotent: list the guild's channels first and reuse the channel when the name already exists, so a re-run never creates a duplicate. Creating a channel needs the `MANAGE_CHANNELS` permission; a bot whose role carries `ADMINISTRATOR` has it.

## Allowlist entry

`channels.discord.guilds.<guildId>.channels` is an **allowlist**: adding one entry makes every unlisted channel denied. Two cases:

- The guild entry already had a `channels` map → add only the new channel's entry. Every other listed channel keeps working.
- The guild entry had **no** `channels` map → add the new entry **and** a `"*": { enabled: true, requireMention: true }` fallback, or every previously-working channel stops responding.

Per-channel shape:

```json5
"<channelId>": { "enabled": true, "requireMention": true, "users": ["<ownerUserId>"] }
```

`users` stays restricted to the owner; `users: ["*"]` opens the room to every member. `requireMention: true` requires an actual mention of the bot.

## The binding shape that matches

Compare against a binding that already works in the same config instead of an external spec.

```json5
{
  agentId: "<agentId>",
  match: {
    channel: "discord",
    accountId: "default",
    peer: { kind: "channel", id: "<channelId>" },
  },
}
```

**Omit `match.guildId`.** A peer binding that also pins `guildId` does not match, because Discord channel inbound carries no guild id at match time; the extra field forces the match onto the account-wide fallback and the request lands in the default agent. The gateway log shows the cause directly:

```
[routing] resolveAgentRoute: channel=discord accountId=default peer=channel:<id> guildId=none ... bindings=N
[routing] match: matchedBy=binding.peer agentId=<agentId>
```

`guildId=none` in the resolve line plus a `matchedBy=binding.channel` result means the peer binding was skipped. The `bindings=N` count tells you whether the running Gateway has your new binding at all: when N still equals the pre-change count, the runtime holds the old snapshot even though the file on disk is correct.

`bindings` is in the `kind: "none"` group of the config reload plan, so it is not hot-reloaded like the other agent keys.

## Why the round trip needs a human

The Discord adapter ignores messages authored by the bot's own account, and the channel's `users` allowlist contains only the owner. A message you send yourself as the bot therefore never becomes an inbound event, so the agent turn never starts. The owner has to post in the channel to exercise the path.

## Letting a bot-authored message reach the agent

`channels.discord.allowBots` decides whether bot-authored messages may trigger turns. The accepted values are `true`, `false` and `"mentions"`; `"mentions"` requires the message to carry a real mention of the bot, and bot messages stay readable as conversation context either way. It is an account-wide setting, not a per-channel one, so it applies to every Discord channel of that account.

```
openclaw config set channels.discord.allowBots '"mentions"' --strict-json
```

Bot-authored messages still pass the channel's access rules, so the bot account id must also be admitted in the channel's `users` list next to the owner:

```json5
"<channelId>": {
  enabled: true,
  requireMention: true,
  users: ["<ownerUserId>", "<botUserId>"],
}
```

Check the result the same way as any other inbound: the channel session `agent:<agentId>:discord:channel:<channelId>` appears in `sessions_list --agent <agentId>`, and the gateway log shows the routing match. Until that session key exists, the mention did not trigger a turn.

Related: a turn executed in the agent's **main** session reports `delivery.status=skipped` and its reply appears in the Control UI instead of Discord, because a main session has no channel target. Only a turn in the channel-routed session proves Discord delivery.

## Prove which sender actually drove the turns

When the owner asks whether an agent answers in a channel — or whether a bot-to-bot path was ever exercised — read the agent's channel session transcript and count the senders, instead of reasoning about it:

```
sessions_history with sessionKey: agent:<agentId>:discord:channel:<channelId>
```

Every inbound user message carries `__openclaw.senderId` and `__openclaw.transport.channel`. Count the distinct `senderId` values across the user messages: if every one of them is the owner's Discord id and none is the bot account, then only the owner has ever driven that agent, and no bot-authored message has produced a turn. A `senderId` histogram answers the question in one call.

## The channel session must exist before a turn can land

A freshly created agent has only a `main` session. `sessions_list --agent <new>` shows the channel session key `agent:<new>:discord:channel:<channelId>` only after the first routed turn. A `sessions_send` to that key fails with `No session found` until then, which is a missing-session symptom, not a broken binding. Check the session list before drawing conclusions from a failed send.

## Copy the reference channel's mention semantics

The trigger behaviour lives in the channel's allowlist entry, not in the binding. A reference channel whose entry omits `requireMention` answers every message in the room, while `requireMention: true` demands an actual mention of the bot. Read the reference channel's entry and mirror its `requireMention` value, because a spec that mandates `requireMention: true` silently changes when the agent reacts and needs the owner's explicit confirmation.

## Reading the channel for verification

```python
r = urllib.request.urlopen(urllib.request.Request(
    f'https://discord.com/api/v10/channels/{CH}/messages?limit=25', headers=H), timeout=25)
for m in reversed(json.load(r)):
    print(m['id'], m['author']['username'], m['author']['bot'], m['content'][:120])
```

The `author.bot` flag distinguishes a bot-authored message from the owner's, which is what decides whether the message could ever have triggered a turn.

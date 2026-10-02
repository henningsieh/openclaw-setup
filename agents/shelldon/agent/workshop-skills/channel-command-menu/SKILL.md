---
name: "channel-command-menu"
description: "A slash command is missing from a chat channel's `/` autocomplete, or the menu stops short of the full command list: separate the three visibility surfaces, then check per-scope registration, the command cap, and trim/collapse."
---

# Channel Command Menu

The `/` autocomplete in a chat channel shows only what the bot registered with the
platform's command-menu API. It is a **third** surface, distinct from the two most
troubleshooting starts in:

| Surface | Question it answers | Where to read it |
|---|---|---|
| Skill registry | Is the skill user-invocable at all? | `openclaw skills list --agent <id> --json` |
| Model picker | Is the *model* offered by `/models`? | `model-route-change` skill |
| Native command menu | What does `/` actually list? | this skill |

A command present in the registry can be absent from the menu, and a model present
in `/models` says nothing about it. Do not answer a menu complaint from either of
the other two.

1. **Read the registered menu per scope before changing anything.** The menu is
   registered per *scope*, and a narrower scope silently overrides a broader one.
   Compare the default scope with the scopes the user actually types in
   (`all_private_chats`, `chat:<id>`, `all_group_chats`) using the platform's
   get-commands API for the bot token. A menu that gained commands in one scope
   but not another is stale-scope, not a missing command. The per-scope divergence
   diagnosis and resync procedure are instance-specific and live in the
   `entities/telegram-bot.md` wiki page — read them there rather than
   re-deriving them. Finish when the counts per scope are known and you can say
   whether the entry is absent everywhere or only in one scope.

2. **Count the visible skill commands separately from the registry.** A skill row
   is not automatically a menu entry: a skill can be `userInvocable` yet not
   `commandVisible` (typically because a required binary or config is missing), and
   those never reach the menu regardless of room. Filter the registry on
   `commandVisible` before treating the gap as a platform problem. Finish when the
   set of genuinely menu-eligible skill commands is known.

3. **Rule out the platform cap and the trim collapse.** Command menus have a hard
   cap (100 entries for Telegram; confirm the current value by searching the
   installed bundle for the native-command-menu module rather than trusting a
   hash-named filename, which changes between releases). When the full set exceeds
   the cap, the runtime fits the list to the platform's text budget and **drops**
   entries. If the dropped entries include skill commands, the runtime collapses
   them into a single umbrella command (for Telegram, a leading `/skill` entry)
   instead of listing them individually. A specific skill command can therefore be
   missing from the menu while still working when typed — absence is not removal.
   Finish when you can say whether the entry was trimmed, or is genuinely
   unregistered.

4. **Recognise the trim signature.** A menu that stops mid-list at an alphabetical
   boundary — entries present up to some prefix and then nothing, rather than
   missing a later name that would sort earlier — indicates trimming, not deletion.
   Compare the registered count against the eligible set; when the registered list
   sits at the cap, treat every absent entry as a capacity casualty. Do not re-add
   the entry; it is already registered and the menu has no room for it.

5. **Give priority commands a guaranteed slot.** `customCommands` entries survive
   trimming ahead of plugin and skill commands (names normalized to `a-z0-9_`,
   1-32 chars, cannot override a native command). To surface a frequently used
   skill, add it as a custom command rather than hoping it fits alphabetically. The
   channel config also gates the families independently: `commands.native` for
   built-ins, `commands.nativeSkills` for skill commands. A custom command is a
   menu entry only — it does not implement behaviour, and typing an unlisted
   plugin or skill command still works.

6. **Verify on the user's own surface.** After any registration change, compare the
   scopes again and confirm the count moved. Chat clients cache the menu per bot, so
   a client still showing the old list needs restarting before the change appears;
   state that rather than re-registering a second time.

Verification: the entry is present in the scope the user types in; the registered
count is explained (below the cap, or at it with a named trim cause); no config
change duplicated an existing native command; and the absence is classified as stale
scope, ineligible skill, or trim — never silently left as "missing".

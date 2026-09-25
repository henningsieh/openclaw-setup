# Handover: OpenClaw Cultivation Agent Setup

**Status:** Implemented and done (2026-09-23). The isolated agent, model
authentication, cultivation turn, Discord round-trip, and existing-channel
routing were verified successfully.

**Goal:** stand up a new, isolated OpenClaw agent (`kalle-kief`) with its own workspace, seeded with the cannabis kalle-kief setup below (water analysis, fertilizers, EC methodology), reachable through one dedicated Discord channel via a binding — without touching the existing default agent or its channel(s).

Sources used for this handover (fetch the `.md` URL for the current version of any of these):
- https://docs.openclaw.ai/concepts/agent-workspace
- https://docs.openclaw.ai/concepts/multi-agent
- https://docs.openclaw.ai/concepts/agent-bindings
- https://docs.openclaw.ai/cli/openclaw

---

## Prerequisites

- OpenClaw Gateway already running.
- Shell access to the Gateway host and `~/.openclaw/openclaw.json`.
- An existing Discord bot account already connected to OpenClaw. No new Discord application is needed — a channel-level binding on the existing bot is enough to give this agent a distinct channel. Confirm the account id first:

  ```bash
  openclaw channels status --probe
  ```

---

## Step 1 — Create the agent and its workspace

Per [Agent workspace](https://docs.openclaw.ai/concepts/agent-workspace) and [Multi-agent routing](https://docs.openclaw.ai/concepts/multi-agent), every agent gets its own workspace, `agentDir`, and session store. Never reuse an existing `agentDir` for a new agent — it causes auth/session collisions.

```bash
openclaw agents add kalle-kief \
  --workspace ~/.openclaw/workspace-kalle-kief \
  --non-interactive
```

**Done when:** `openclaw agents list` shows `kalle-kief` with its own workspace path, distinct from `main`.

---

## Step 2 — Seed the workspace files

Bootstrap files load automatically at the start of every session for that agent. Write these two files into `~/.openclaw/workspace-kalle-kief/` (create the directory if `agents add` didn't already seed it):

### `AGENTS.md`

```markdown
# Cultivation Agent — Operating Instructions

You assist with a home cannabis kalle-kief setup (Cocos coir, indoor, single
feeding line). Your job: feeding/EC calculations, nutrient troubleshooting
from photos, and grow-cycle tracking.

## Non-negotiable constraint — read before every EC/dosing answer
Irrigation runs without any runoff/drain: max ~2 L per pot, no way to collect
overflow. Consequences:
- Cap EC recommendations in flower at 1.3-1.4 mS/cm total solution EC unless
  the user explicitly asks for a different target.
- Salts accumulate in the substrate over time with no leaching — factor this
  into any diagnosis of leaf tip burn or deficiency symptoms before anything
  else.
- Periodic plain, pH-6 water (no fertilizer) is the agreed mitigation for
  salt buildup, not runoff/flushing.

## Reference material
Full water analysis, fertilizer composition, and feeding history live in
CULTIVATION-SETUP.md in this workspace. Load it for any feeding, EC, or
dosing question.
```

### `CULTIVATION-SETUP.md`

```markdown
# Cultivation Setup Reference

## Water (Maintal Werke tap water, Analysen-Nr. 202517265, 25.08.2025)
- pH 7,85 · Leitfähigkeit 297 µS/cm · Gesamthärte 7,16 °dH (weich)
- Calcium 33,7 mg/l · Magnesium 10,6 mg/l · Kalium 2,3 mg/l
- Nitrat 8,8 mg/l (≈2,0 mg/l N) · Nitrit/Ammonium nicht nachweisbar
- Sulfat 16,9 mg/l · Chlorid 13,9 mg/l · Eisen 0,0096 mg/l

## Medium & irrigation
- Cocos coir, no drain/runoff possible (space constraint) — always ~2 L/pot
- pH corrected to 6,0 manually before every feed

## Fertilizers on hand
| Product | Analysis |
|---|---|
| Hakaphos Blau | 15% N (4,5 NO3 / 10,5 NH4) – 10% P2O5 – 15% K2O – 2% MgO + B/Cu/Fe/Mn/Mo/Zn |
| Haifa Cal (Calciumnitrat) | 15,5% N (14,4 NO3 / 1,1 NH4) – 26,5% CaO |
| EPSO Top (Bittersalz) | 16% MgO – 32,5% SO3 |
| Peters Blossom Booster | 10-30-20, only during the flip/stretch transition |
| Peters Professional Combi Sol | 6-18-36, main bloom fertilizer from ~week 4 |

## Calibration data (measured/sourced, not theoretical)
- Hakaphos Blau, manufacturer EC table (COMPO EXPERT datasheet):
  0,5‰ = 0,79 mS/cm · 1,0‰ = 1,52 mS/cm · 1,5‰ = 2,20 mS/cm
- Haifa Cal: ≈1,354 mS/cm per g/l (Kohlrausch calc from declared Ca²⁺/NH4⁺/NO3⁻)
- EPSO Top: ≈1,071 mS/cm per g/l (Kohlrausch calc from declared Mg²⁺/SO4²⁻)
- Confirmed incident: 0,9 g/l Hakaphos + 0,4 g/l Haifa Cal + 0,2 g/l EPSO Top
  measured >2,3 mS/cm total solution EC → visible leaf tip burn (nutrient/salt
  burn, not deficiency)

## Feeding methodology
- Fertilizer transitions: soft-switch (e.g. 50/50 blend over ~1 week), never abrupt
- EC ceiling in flower: 1,3-1,4 mS/cm total solution EC (meter reading), because
  of the no-runoff constraint above
- Health signal to watch: new growth/bud development, not cosmetic tip damage
  on older fan leaves
```

**Done when:** both files exist under the new workspace and a first test message to the `kalle-kief` agent reflects the no-runoff/EC-ceiling constraint without being told.

---

## Step 3 — Create the Discord channel and bind it

1. In the Discord guild the existing bot already has access to, create a new text channel (e.g. `#grow-log`).
2. Enable Developer Mode in Discord (User Settings → Advanced), right-click the new channel → **Copy Channel ID**.
3. Add a peer binding to `~/.openclaw/openclaw.json` (per [Agent bindings](https://docs.openclaw.ai/concepts/agent-bindings)):

   ```json5
   {
     bindings: [
       {
         agentId: "kalle-kief",
         comment: "Route the #grow-log channel to the kalle-kief agent",
         match: {
           channel: "discord",
           accountId: "default", // confirm against `channels status --probe`
           peer: { kind: "channel", id: "<NEW_CHANNEL_ID>" },
         },
       },
       // existing bindings can stay in any order relative to this one —
       // concrete peer matches are the most specific tier and always win
       // over the account/channel-wide fallback that keeps routing every
       // other channel to the existing agent.
     ],
   }
   ```

**Done when:** `openclaw agents list --bindings` lists the new binding, and a message in `#grow-log` is answered by `kalle-kief` while every other channel still reaches the original agent.

---

## Step 4 — Restart and verify

```bash
openclaw gateway restart
openclaw agents list --bindings
openclaw channels status --probe
```

**Done when:** all three commands return clean output and a round-trip test message in `#grow-log` gets a reply from the `kalle-kief` agent.

---

## Notes / open choices left for the operator

- **Model**: not set here — pick per the existing cost-conscious model policy (e.g. reuse whichever model currently handles structured/background tasks) via `agents.entries.kalle-kief.model` or `openclaw agents add ... --model <id>`.
- **Full bot separation**: this handover uses one existing Discord bot with a channel-level binding, the simplest documented path. If a visually distinct bot identity (separate avatar/name in Discord) is wanted later, create a second Discord application/token and switch to an `accountId`-level binding instead — see the "Discord bots per agent" example in [Multi-agent routing](https://docs.openclaw.ai/concepts/multi-agent).

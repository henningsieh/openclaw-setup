---
name: "grow-photo-status-check"
description: "Check plant status from the newest Immich grow-album photos: album-first query, skip non-grow images, inspect, report facts, hypotheses, gaps, one action."
---

# Grow photo status check

Use for any "how are the plants doing" question, recurring check-in, or diagnosis that depends on the current visual state.

1. Read `CULTIVATION-SETUP.md`, `WATER-ANALYSIS.md`, and the newest entries in `MEMORY.md` before answering. Take the last documented date and measurement from `MEMORY.md`, not from recollection; an unstated "last time" is usually stale.

2. Read the newest messages of the bound grow channel (`sessions_history` with that channel's session key) to catch a verbal update that is newer than the last photo. A user statement counts as evidence.

3. Scope to the grow album first: `Apple & Bananas x Tropicanna Banana` (`714933bc-837d-41a9-a655-fe78289ada1f`). Query it with `POST /api/search/metadata`, body `{"albumIds":["714933bc-837d-41a9-a655-fe78289ada1f"],"size":100,"page":1}`; `GET /api/albums/<id>` returns an empty `assets` array even when the album has assets, so do not trust it. Album membership lags because Henning uploads to the main stream and files photos only sometimes.

   If the newest plant photo in the album is older than the last documented check, widen to the global stream from that date, not from today, so a missed day stays visible. Pass a full ISO datetime with milliseconds and `Z`; a date-only value fails with `400 Validation failed ... invalid_format`:

```
cd ~/.openclaw/workspace-kalle-kief/skills/immich-operations
python3 scripts/search_assets.py --since 2026-10-29T00:00:00.000Z --albums --limit 40
```

The helper prints `total=N returned=N` plus id, filename, timestamp and albums; an empty result means no new visual evidence, so say that instead of inferring. In the stream, only plant frames are evidence: unrelated personal photos are outside the task, so do not name, describe, or tag them, and do not report their content beyond "N non-plant images skipped".

   If no new plant photo exists, attribute and use newer user-reported observations without claiming unseen visual signs; ask for a top-down photo only when visual confirmation would change the assessment, because missing photos limit visual rather than verbal evidence.

   When a plant photo sits only in the stream, file it into the album with `PUT /api/albums/714933bc-837d-41a9-a655-fe78289ada1f/assets`, body `{"ids":["<asset-id>"]}`, once Henning agrees, then confirm membership with the album metadata search.

4. Download each candidate preview and confirm it actually shows plants. Use Python urllib, never curl (curl returns 401 for a valid key):

```
python3 - <<'EOF'
import os, urllib.request
key = open(os.path.expanduser('~/.immich_key')).read().strip()
aid = '<asset-id>'
req = urllib.request.Request(
    f'https://immich.sieh.org/api/assets/{aid}/thumbnail?size=preview',
    headers={'x-api-key': key})
path = '/home/shelldon/.openclaw/workspace-kalle-kief/media/inbound/tmp/check.jpg'
open(path, 'wb').write(urllib.request.urlopen(req, timeout=60).read())
print(path)
EOF
```

Save under the agent workspace (`media/inbound/tmp/`); `view_image` refuses paths outside the allowed workspace directories, so a `/tmp` download cannot be inspected.

5. Classify every image before interpreting it. Auto-upload regularly contains drinks, sky, food, bong or tool photos; treat those as out of scope, leave them untagged, check one asset further back, and keep their content out of the answer — a single skipped-count is enough. Assess only frames that show the tent or plants.

6. Inspect with a fixed checklist: number of leaf pairs, leaf posture (upright vs drooping or clawed), colour of the newest growth, necrosis or margin burn and which leaves carry it, substrate surface moisture, thermometer/hygrometer readings, visible pests or silvery suction spots.

7. Answer in German with the casual tone in three labelled blocks: **Belegt** (measurements, user statements, what the photo shows), **Plausibel** (hypothesis plus mechanism), **Offen** (the values that are missing). Close with one small verifiable action and exactly one question whose answer would change the recommendation.

8. Judge recovery by the newest growth, not by old damage. Upright green tips mean the course is right; clawed or necrotic older leaves are cosmetic and justify no feed change.

9. Give any intervention 3–5 days before calling it failed, and state that window when recommending one. Do not add fertilizer or increase EC on photo evidence alone; with no runoff, check accumulation as input EC versus drain EC and aim for drain near input. When the photos follow a spray, drench, or flush, read [treatment damage and post-flush recovery](references/treatment-damage-recovery.md) before recommending a dose.

10. Tag only plant photos and only once the phase is clear. Never use `/` in a tag name (Immich rejects it with 400); use `🌰 Keimung`, `🌱 Sämling`, `🌿 Vegi`, `🌸 Blüte`, `✂️ Ernte`, `🫙 Trocknung`. Read the tag back from the asset's own `tags` field.

11. For a recurring morning check-in, create the automation with `references/morning-check-automation.md`; verify it with one forced run and read the outcome from `automations runs`, not from a scheduled test job.

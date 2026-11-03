# Morning grow check automation

Create the daily check-in with `automations` action `add` and these fields:

- `agentId`: `kalle-kief`
- `name` / `displayName`: `🌱 Grow-Check (Kalle)`
- `schedule`: `{"kind":"cron","expr":"30 6 * * *","tz":"Europe/Berlin"}`
- `sessionTarget`: `session:agent:kalle-kief:discord:channel:1552230093500325888`
- `delivery`: `{"mode":"announce","channel":"discord","to":"channel:1552230093500325888","accountId":"default"}`
- `payload`: `{"kind":"agentTurn","timeoutSeconds":240,"toolsAllow":["exec","read","view_image"],"message":"..."}`

The message tells the run to follow `grow-photo-status-check`, query the grow album first, and answer in German. Include the current grow state there (plant count, phase, last feeding or flush, and the active no-water or no-feed rule) because the run starts from the prompt, not from this conversation.

Include in the message: no new photo means one or two sentences plus a request for a top-down photo, never a diagnosis; a photo means Belegt / Plausibel / Offen, one action, one question.

## Verify

1. `automations` action `run`, `jobId`, `runMode: "force"`. A still-running job returns a `runId`.
2. `automations` action `runs`, `jobId`, `runId` until the entry shows `action: "finished"`, `status: "ok"`, `deliveryStatus: "delivered"`.
3. Check `nextRunAtMs` resolves to the next 06:30 Europe/Berlin.

Do not create a separate verification job; the run record is the proof.

`automations add` may extend `toolsAllow` with `skills_read`; keep it, because the run reads this skill. The owner stays `agent:kalle-kief:main` while the run itself executes in the Discord channel session.

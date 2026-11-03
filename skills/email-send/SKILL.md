---
name: email-send
description: "Poll and reply to openclaw@ai.sieh.org mail: allowlisted senders, threaded SMTP replies, UID watermark."
---

# Email Send

Shared sending mailbox for agents: `openclaw@ai.sieh.org` on `mail.sieh.org`.
Helper script lives beside this file: `{baseDir}/email-poll-reply.py` (stdlib only).

## Usage

```bash
python3 {baseDir}/email-poll-reply.py list
python3 {baseDir}/email-poll-reply.py send \
  --to 'sender@example.com' --subject 'Re: ...' --body-file /tmp/<uid>.txt \
  --uid <uid> --inreplyto '<message-id>' --from-name 'Shelldon'
```

`list` prints one JSON object: `unseen_allowlisted` entries (`uid`, `from_addr`,
`from_name`, `subject`, `message_id`, `date`, `body`) plus `mailbox` counters.

## Rules

- Allowlist is fixed: `henning@sieh.org`, `kontakt@henningsieh.de`. Never reply elsewhere.
- `--from-name` allowlist: `Shelldon`. Envelope-from and header stay `openclaw@ai.sieh.org`.
- Credentials: env `IMAP_SMTP_OPENCLAW_AI_SIEH_ORG_PASSWORD` (secret kind `env`). Never print it.
- New-mail tracking: UID watermark in `state.json` (uidvalidity + last_uid), advanced only
  after SMTP accepted a reply. Never use `UNSEEN` as the new-mail test; fetch with `BODY.PEEK`.
- Loop protection: inbound `X-Openclaw-Autoreply` or `Auto-Submitted: auto-*` is skipped;
  already-answered messages are filtered by matching `In-Reply-To` in this mailbox.
- Subject threading: `In-Reply-To` / `References` from the source mail; `\Seen` is set only
  after SMTP success.
- Reply body must be plain text in the sender's language, short and specific.

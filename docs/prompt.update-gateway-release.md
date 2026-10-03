# Prompt: Update the OpenClaw Gateway

Start a Pi session in the native setup repository and paste the body below.
It is evergreen: obtain the candidate release from the configured channel.
Governance: [gateway-update.md](runbooks/gateway-update.md), ADR 0005.

---

Update the native OpenClaw gateway end to end using the tracked
`scripts/gateway-update.sh`. Read `CONTEXT.md`,
`docs/runbooks/gateway-update.md` and ADR 0005 first. Read the target release
notes and establish whether this session is external Pi or gateway-hosted.

1. Run `scripts/gateway-update.sh plan`. Resolve any refusal without touching
   OpenClaw databases or credentials. Check the candidate, plugin inventory,
   guard/process state and disk/cache measurements. Do not perform live UI
   diagnostics before the update or treat historical notices as new failures.
2. Run `scripts/gateway-update.sh start --expect-version <candidate>` once.
   This launches the detached stop → update → broker rebuild/test/install →
   final Doctor → start → verification chain. Do not construct another shell
   chain, add updater flags, run a competing maintenance command, or use any
   other restart mechanism. The script creates its own guard; do not pre-create it.
3. **Monitor through startup.** Use `scripts/gateway-update.sh status` and the
   reported log path, with brief phase/result/next-step messages. Status reads
   receipts without probing OpenClaw maintenance state. Allow long steps and
   do not promise an ETA. If gateway-hosted, resume from an independent session
   or new turn after disconnection; external Pi continues monitoring.
4. On `failed`, report the exact phase/error, recovery-start result and service
   availability. Keep the guard and follow the runbook's failure branch. Do not
   retry merely because a step is slow; recovery alone is not update success.
5. On `awaiting-confirmation`, review automatic verification evidence. Verify
   `https://ai.sieh.org/` renders in the native browser and ask the owner to
   confirm the existing signed-in connection. A fresh token-login screen is
   normal; do not obtain a token or change auth to connect it. Verify startup
   journal evidence; if inaccessible, request the owner's independent check.
6. After rendering, owner connection and journal checks pass, run
   `scripts/gateway-update.sh finish --owner-ui-confirmed`. Add
   `--journal-confirmed` only when the owner actually verified journal evidence
   that the script could not access. Confirm status is `complete`, the owned
   guard is gone and watchdog recovery is armed. **Do not leave cleanup pending
   without explicitly reporting the outstanding confirmation.**
7. Sync version anchors and review actual tracked changes. Commit only when
   requested, after reviewing status and the staged diff; keep credentials,
   private lifecycle receipts and guards out of Git.

Report: before → after version, update/Doctor outcome, service/HTTP/UI/channels/
Vault registration checks, guard cleanup and watchdog recovery, and any pending
check with its exact next action. Version output alone does not mean complete.

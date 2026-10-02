---
name: "ssh-access-diagnosis"
description: "SSH login to the gateway host itself fails, or a new user key is being added: prove which auth methods the server actually offers, check the permissions that silently reject a good key, and append keys without losing the existing ones."
---

# SSH Access Diagnosis

Scope: SSH **into the host this agent runs on** (the OpenClaw gateway box), for key
onboarding and login failures. Remote Hetzner/Coolify hosts belong to the
`hetzner-coolify-access` skill; the wider host picture is in `~/.openclaw/CONTEXT.md`.

1. **Take the auth methods from the server's offer, never from a missing config line.**
   `ssh -vv -o BatchMode=yes -o ConnectTimeout=6 <user>@<host> true` and read
   `Authentications that can continue:`. That list is the ground truth for what a login may use.

   **Absence of a directive is not a disabled directive.** A `sshd_config` that never mentions
   `PasswordAuthentication` is running the OpenSSH default (`yes`), so password login is *offered*
   unless the handshake says otherwise. Do not report "password login is off" from a config grep
   that simply found nothing — that is an unsupported security claim, and it was wrong here once.
   The same applies to `PermitRootLogin` and every other default-valued option.

   `sshd -T` is the other authority but usually needs root; a drop-in you cannot read (mode `600`)
   is **unknown, not empty**. Treat unreadable config as an open question, report it as such, and
   fall back to the `ssh -vv` offer rather than guessing. Finish when the offered method list is
   known from the handshake.

2. **Check the three permissions before blaming the key or the provider.** OpenSSH silently
   refuses an otherwise valid key when ownership or mode is wrong:
   - home directory must not be group- or world-writable (`drwxr-x---` is fine),
   - `~/.ssh` must be `700`,
   - `~/.ssh/authorized_keys` must be `600`.

   `stat -c '%A %U:%G %n' ~ ~/.ssh ~/.ssh/authorized_keys` answers all three at once. Use
   `ssh-keygen -lf ~/.ssh/authorized_keys` to list which keys are currently accepted, so a failed
   login is compared against a known set. Finish when the modes and the accepted-key list are both
   known.

3. **Add a new key by appending, and prove the result by fingerprint.** Never rewrite
   `authorized_keys` wholesale and never drop an existing entry to make room. Append the single
   `.pub` line, then re-run `ssh-keygen -lf` and require the new fingerprint to appear *alongside*
   every pre-existing one — that readback is what proves nothing was lost. A client key is the
   user's to generate; this side only ever touches the `.pub` line, never a private key.

   Give the user a real command to generate it (`ssh-keygen -t ed25519 -C "<label>"`, then
   `cat ~/.ssh/id_ed25519.pub`) and state that a passphrase is worth setting: this key grants
   write access to the whole workspace, including the secrets dotenv. Offer `from=` restriction as
   a choice, not a default — mobile egress changes IP constantly.

4. **Report the host's real exposure alongside the key setup.** On a public port 22, the fact that
   the operator has not added a brute-force limiter (`fail2ban`, `ufw`) and what
   `PermitRootLogin` resolves to is material context for the key decision — but it is a separate
   change, so name it, do not bundle it into a key task, and do not edit `sshd_config` without an
   explicit go-ahead.

Verification: the `Authentications that can continue:` line from `ssh -vv` is quoted as the basis
for every auth claim; home/`~/.ssh`/`authorized_keys` modes were checked; `ssh-keygen -lf` shows
the new fingerprint together with all pre-existing ones; no private key was read, written, or
displayed; and any exposure finding was reported rather than silently fixed.

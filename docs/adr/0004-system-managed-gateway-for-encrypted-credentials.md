# System-Managed Gateway for Encrypted Credentials

The OpenClaw gateway remains a native process owned by `shelldon`, but the
system systemd manager owns its service unit. The previous per-user manager
cannot decrypt `LoadCredentialEncrypted=` inputs on the host's systemd 255.
Using a system unit with `User=shelldon` preserves the service identity and
avoids Docker, plaintext credential files, and bootstrap environment variables
while allowing systemd to supply the Encrypted Bootstrap Credential Set.

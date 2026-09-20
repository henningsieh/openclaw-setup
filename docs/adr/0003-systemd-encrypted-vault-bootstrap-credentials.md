# systemd Encrypted Vault Bootstrap Credentials

The Vault Access Broker will receive the Vaultwarden API credentials and master password through the native gateway service's `LoadCredentialEncrypted=` inputs. This keeps bootstrap values out of Git, OpenClaw configuration, and process environment variables, while acknowledging that the running Gateway must access plaintext credentials to unlock the Personal Vault Identity.

# Immich instance operations

This is the host-specific reference for managing the private photo cloud. Use
the `immich-operations` skill for procedure and `entities/immich.md` for
wiki discovery. Check live
service and client versions before using version-dependent API or CLI syntax.

## Instance and storage

| Item | Location or rule |
|---|---|
| Immich | `https://<immich-host>` (`/api` for API calls), on the main Ubuntu host, not the Coolify server |
| Production media | `/mnt/storagebox-node/immich`; never edit or stage files inside it |
| Storage Box | `/mnt/storagebox-node` is the `shelldon`-writable CIFS mount; `storagebox:` is the SFTP rclone remote |
| Former Google Takeout | `/mnt/storagebox-node/Google-Fotos` is a read-only backup/reference, not a standing import queue |
| Archived retry evidence | `/mnt/storagebox-node/trash/google-fotos-retry-20260925-archive`; inspect only if that case is reopened |
| CLI | `~/.local/bin/immich-go`; use the absolute path when PATH differs |
| Private job logs | `~/.local/state/immich-go/<job>/`, outside Git |

The Google Photos migration is closed. A new Takeout import requires a newly
scoped request; do not restart the old migration by default. Check free space
before exports or staging. Keep bulk media off the small host root disk. For
Storage Box access details outside Immich, use the `storagebox-file-access`
skill.

## Credentials and command environment

Read the Immich keys from the environment variables the running process already
provides: `IMMICH_API_KEY` is the asset owner's non-admin key; `IMMICH_ADMIN_API_KEY`
is for administrative operations. Use the value exactly as the runtime exposes it;
never hand-derive or re-parse it. When a key must be stored separately, keep it as
a raw file and always expand it quoted:

```bash
printf '%s' 'KEY' > ~/.immich_key && chmod 600 ~/.immich_key
IMMICH_API_KEY="$(cat ~/.immich_key)"
curl -s -H "x-api-key: $IMMICH_API_KEY" https://<immich-host>/api/users/me
```

An unquoted `$KEY` lets the shell eat special characters (`!`, `$`, backtick)
intermittently, which looks exactly like flapping auth. Verify access against
`/api/users/me` (expect HTTP 200) before asset work, without printing values.
Never substitute the admin key for the asset key: uploads would belong to the
wrong account.

**401 diagnosis order.** 1) `/api/server/version` — should be 200; a failure there
means server/network, not the key. 2) `/api/users/me` with the key. `Invalid API
key` means the *sent* value is wrong (check the file/variable), not that the server
should be restarted or the key rotated. After a container restart or update, a
short 401 window is normal: wait ~2 minutes and retest before touching the key.

| `immich-go` operation | Map `IMMICH_API_KEY` to | Origin flag |
|---|---|---|
| `upload` | `IMMICH_GO_UPLOAD_API_KEY` | `--server` |
| `stack` | `IMMICH_GO_STACK_API_KEY` | `--server` |
| `archive from-immich` | `IMMICH_GO_ARCHIVE_FROM_IMMICH_FROM_API_KEY` | `--from-server` |

Use the installed subcommand's `--help` before executing it. Pass keys through
the environment, never command arguments, config files, traces or logs. Run
`immich-go` from a private empty working directory (`umask 077`) so an existing
current-directory config cannot silently change behavior. Use absolute paths,
private logs and explicit HTTPS origin. Keep `--save-config` and API tracing off.
Do not point `--config` at a missing file. Disable job pausing for normal previews
(`--pause-immich-jobs=false`; archive: `--from-pause-immich-jobs=false`).

## Operation boundaries

| Task | Interface | Completion evidence |
|---|---|---|
| Health and asset search | Live, version-matched Immich API or bundled read-only helpers | Server version, intended account, complete paginated result |
| Source reconciliation | `reconcile_source.py` / `POST /assets/bulk-upload-check` | SHA-1 byte match *and* separate metadata check where relevant |
| Ordinary file import | `immich-go upload from-folder` (XMP sidecars) | Reviewed dry-run, upload report, independent server read-back |
| New Google Takeout import | `immich-go upload from-google-photos` (JSON sidecars and all relevant export parts) | Scoped source, reviewed dry-run, media and metadata verification |
| Asset export | `immich-go archive from-immich` | Reviewed filter, capacity-checked destination, exported content verified |
| Stacking | `immich-go stack` | Bounded preview, reviewed mode, resulting groups and retained formats verified |
| Metadata/date changes | Version-matched OpenAPI | Read back every changed asset; HTTP 2xx alone is insufficient |
| Tag create/assign | `POST /api/tags`, then attach to assets | Tag name has no `/`; read the created tag back |
| Version update | `sudo -n /usr/local/bin/immich-update` (root-only, NOPASSWD) | Release applied, `immich_server` healthy and version label matches |

The `📸 Immich Nightly Update` automation runs the update check daily at 02:30
(after the 02:00 DB backup, which the script requires <48 h fresh) and announces
one line to Discord `#system-status`. Agents otherwise treat Immich lifecycle as
root-only and stay read-only/API.

Use a dry-run for state-changing CLI operations; archive previews need both
`--dry-run` and `--from-dry-run`. Report the exact source, filters, destination,
counts, exclusions and errors before execution. Execute only the authorized
scope. Start shared-host uploads conservatively with
`--concurrent-tasks=2 --on-errors=stop --no-ui`; change concurrency only from
load or error evidence. Keep production media and source evidence until the
result is verified. A source-folder deletion or remote `rclone` mutation is a
separate reviewed operation. An asset export is **not** disaster recovery;
that requires database plus media backups and a restore test.

## API details worth retaining

Use the OpenAPI matching the live `/api/server/version`, not upstream `main`.
Send the user key as `x-api-key` over verified HTTPS. `POST
/assets/bulk-upload-check` is a read-only SHA-1 identity query despite its
method; `reject`/`duplicate` with `isTrashed: false` proves the bytes are present,
not that dates, albums or locations are correct. Include trashed assets when
triaging duplicates. Filename and capture time are only candidate grouping.

Paginate `POST /search/metadata` until an empty page (or the version's verified
cursor end). On the previously checked v3.2.2 server, `assets.total` echoed
the requested page size, not library size. For album membership, query the
asset's albums or search by `albumIds`; do not infer membership from a missing
`assets` property on album rows. Verify these shapes against the current server
version before writing a new client.

For a partial import or suspicious capture date, use the skill's focused
references. Preserve the source while resolving a partial result. Do not
re-import solely to repair existing metadata.

## Upstream references

- [Immich API](https://api.immich.app/) and [backup guidance](https://docs.immich.app/administration/backup-and-restore)
- [immich-go commands and configuration](https://github.com/simulot/immich-go/tree/main/docs)

# Backup & Disaster Recovery

> **Category:** Infrastructure
> **Status:** Active
> **Last Updated:** 2026-05-01

This is the operational runbook for backing up a Fluxora deployment and recovering after disk loss, accidental deletion, leaked secrets, or full-machine failure. Treat this as a checklist — every item here is a thing to verify, not just read.

---

## What lives where

Everything Fluxora-specific is under one directory per platform:

| Platform | Data dir |
|----------|----------|
| Windows | `%APPDATA%\Fluxora\` |
| macOS | `~/Library/Application Support/Fluxora/` |
| Linux | `~/.fluxora/` |

Inside that dir:

| Path | What it is | Backup priority | Recreatable? |
|------|------------|----------------|---------------|
| `fluxora.db` | SQLite primary database — libraries, files, clients, sessions, settings, polar_orders | **Critical** | No (loses pairings, library index, license, polar_orders) |
| `fluxora.db-wal`, `fluxora.db-shm` | WAL companion files. Skip during cold backup if `-wal` is empty; otherwise back up alongside `.db` | **Critical when present** | No |
| `.env` | Secrets — `TOKEN_HMAC_KEY`, `FLUXORA_LICENSE_SECRET`, `POLAR_WEBHOOK_SECRET`, etc. | **Critical** | Sort-of (you can rotate, but every existing license key dies) |
| `logs/server.log` (+ rotated `.1`–`.5`) | Server logs | Low | Yes (log fresh on restart) |
| `hls/<session_id>/*` | HLS segments for **active** streams only | None | Yes (cleaned automatically) |

Outside the data dir but worth knowing about:

| Path | What it is | Backup priority |
|------|------------|----------------|
| `~/.cloudflared/<tunnel-id>.json` (when v1 routing lands) | Cloudflare Tunnel credentials | **Critical** — losing this means re-creating the tunnel and re-pairing the public DNS record |
| User's media files (the directories listed in `libraries.root_paths`) | The actual movies/TV/music being served | User's own responsibility — Fluxora does **not** manage these and never moves or copies them |

---

## What does NOT need backing up

- HLS temp segments — ephemeral, deleted on stream end and on server restart.
- Anything under `~/.fluxora/logs/` — useful for forensics but not required for operation.
- The PyInstaller-bundled binary itself — re-download from GitHub Releases.
- Client-side `flutter_secure_storage` data on phones/desktops — clients will re-pair after a server restore.

---

## Backup procedures

### A. Cold backup (server stopped) — easy and reliable

If you can briefly stop the server, this is the simplest correct approach.

```bash
# Windows
net stop Fluxora        # if installed as a service; otherwise close the running process
robocopy "%APPDATA%\Fluxora" "D:\backups\fluxora-2026-05-01" /MIR
net start Fluxora

# macOS / Linux
sudo systemctl stop fluxora     # or kill the process if not a service
rsync -av --delete ~/.fluxora/ /mnt/backup/fluxora-2026-05-01/
sudo systemctl start fluxora
```

The whole `Fluxora/` data dir is copied as-is. Done.

### B. Hot backup (server running) — required for unattended scheduled backups

Naïve `cp` on `fluxora.db` while the server is running is **not safe** — WAL-mode SQLite has writes pending in `fluxora.db-wal` that the bare `.db` doesn't include. Use SQLite's online backup API instead:

```bash
sqlite3 ~/.fluxora/fluxora.db ".backup '/mnt/backup/fluxora-2026-05-01.db'"
```

This produces a single consistent file with WAL contents merged in. Run it on whatever schedule you want (cron, Task Scheduler, etc.).

Additionally copy `.env` and `~/.cloudflared/*.json` — they don't change often, so a once-a-week `cp` is fine.

### C. Off-site replication

A backup that lives only on the same disk as the original is not a backup. Two practical options:

| Option | Setup | Cost | Notes |
|--------|-------|------|-------|
| **rclone → S3/B2/R2** | `rclone copy /mnt/backup/ remote:fluxora-backups/` after each `.backup` | Pennies/month | Best balance. Encrypt with `rclone crypt` if the bucket isn't yours. |
| **Restic to a NAS** | `restic backup ~/.fluxora` | Free if you have a NAS | Deduplicates and encrypts. Best if you already use restic. |
| **Manual external HDD** | `rsync` to USB drive every Sunday | $0 ongoing | Fine for solo home use. Don't forget. |

**Whatever you pick, test the restore path quarterly.** A backup you've never restored from is a hopeful prayer, not a backup.

---

## Restore procedures

### Scenario 1: New disk, same machine

1. Install Fluxora server binary (download fresh from GitHub Releases).
2. Stop the freshly-started service (it created an empty `fluxora.db`).
3. Copy the backed-up data dir into place — overwrite the empty install.
4. Copy `~/.cloudflared/<tunnel-id>.json` back into place.
5. Start the service. Verify with `curl http://localhost:8080/api/v1/info`.
6. (If running) verify `cloudflared` reconnects with `cloudflared tunnel info <id>`.

### Scenario 2: New machine entirely

Same as Scenario 1, but also re-install `cloudflared` (per [03_public_routing.md](./03_public_routing.md)) and confirm the tunnel registers under the same ID. The Cloudflare DNS CNAME pointing at `<tunnel-id>.cfargotunnel.com` is unchanged on the Cloudflare side, so as soon as the daemon comes up, traffic resumes.

### Scenario 3: Lost `FLUXORA_LICENSE_SECRET`

This is the bad one. Every license key issued to date was signed with that secret — none of them validate any more.

Recovery steps:
1. Generate a new secret: `python -c "import secrets; print(secrets.token_hex(32))"` and write it to `.env`.
2. Restart the server.
3. **Re-issue every license key.** Pull the list from `polar_orders` (you backed it up — right?):
   ```sql
   SELECT order_id, customer_email, tier FROM polar_orders;
   ```
4. For each row, run `python -m services.license_service --tier <tier> --days 365` (or the appropriate lifetime).
5. Email each customer the new key with an explanation.
6. Update `polar_orders.license_key` for each row so future replays are idempotent.

This is annoying. Treat the license secret as *equally important* as the SQLite DB itself in your backup priority.

See [`docs/06_security/02_license_key_operations.md`](../06_security/02_license_key_operations.md) for the full secret-rotation runbook (including how to handle the case where the leak is not just lost but actively compromised).

### Scenario 4: Lost `TOKEN_HMAC_KEY`

Less catastrophic — only affects bearer-token validation:

1. Generate a new `TOKEN_HMAC_KEY` and write to `.env`.
2. Restart the server. **Every paired client is now invalidated** because the stored HMAC hashes no longer match.
3. Each client (mobile + desktop) re-pairs via the normal `/auth/request-pair` flow. The owner approves them again from localhost.

Annoying for ~5 minutes per client. No data loss.

### Scenario 5: Lost Cloudflare Tunnel credentials (`<id>.json`)

1. Run `cloudflared tunnel delete <old-id>` to clean up server-side state.
2. Run `cloudflared tunnel create fluxora-home` to create a new one — gets a new ID and credentials.
3. Update the Cloudflare DNS CNAME for `api.fluxora.marshalx.dev` to point at the new `<new-id>.cfargotunnel.com`.
4. Update `~/.cloudflared/config.yml` with the new tunnel ID.
5. Restart `cloudflared`.

DNS propagation takes a few minutes. Existing client `remote_url` strings keep working — only the underlying tunnel ID changed.

### Scenario 6: Polar webhook secret leak

1. Generate a new secret in the Polar dashboard.
2. Update `POLAR_WEBHOOK_SECRET` in `.env`.
3. Restart the server.
4. **Replay any in-flight orders** that may have been processed with the wrong/leaked secret — the `polar_orders` idempotency table prevents double-issuance, so safe to re-trigger from the Polar dashboard's "resend webhook" tool.

---

## Backup verification (do this quarterly)

A 5-minute drill that catches 90% of backup failures:

1. On a **different** machine (or a VM, or a temp dir), restore the latest backup.
2. Start the server pointing at the restored data dir.
3. `curl http://localhost:8080/api/v1/info` — server starts.
4. `curl http://localhost:8080/api/v1/library` — library listings load.
5. `sqlite3 fluxora.db "SELECT count(*) FROM polar_orders;"` — order history intact.
6. Issue and validate a fresh license key — confirms `FLUXORA_LICENSE_SECRET` was backed up correctly.

If any step fails, the backup is broken — fix the backup process before you need it.

---

## What customers should be told

If/when Fluxora becomes multi-tenant (v2 — see [03_public_routing.md](./03_public_routing.md#v2--multi-tenant-rollout)), users running their own home Fluxora server are still responsible for their own backups. The control plane (Cloudflare Worker + D1) only stores tunnel routing metadata — losing it means re-registering, not data loss. **The home server's data dir is the user's responsibility, always.**

A short paragraph in the desktop control panel under Settings → Data:

> "Fluxora stores everything in `~/.fluxora` (Windows: `%APPDATA%\Fluxora`). Back this folder up regularly. The `.env` file inside contains your license secret — losing it invalidates all your generated license keys. See [Backup & Recovery](https://github.com/Marshal-GG/Fluxora/blob/main/docs/05_infrastructure/05_backup_and_recovery.md) for the full guide."

This UI string is currently TODO in `apps/desktop/lib/features/settings/`.

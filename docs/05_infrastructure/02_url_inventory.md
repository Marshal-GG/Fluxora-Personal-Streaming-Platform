# URL Inventory

> **Category:** Infrastructure
> **Status:** Active — Created 2026-05-02
> **Last Updated:** 2026-05-09 (deep-audit sync — added `POST /api/v1/info/support-bundle`, `GET /api/v1/files/{file_id}/content`, `PATCH /api/v1/auth/clients/me`, transcoding benchmark endpoints `POST /benchmark` + `GET /benchmark/progress` + `GET /benchmark/history` + `GET/DELETE /benchmark/history/{id}` that were live in code but missing from the inventory). 2026-05-08 (added `DELETE /api/v1/auth/clients/me` self-revoke for mobile sign-out — audit §17.3 #3; added `POST /api/v1/files/{file_id}/reset-progress` for the "Start over" affordance — streaming pipeline plan §4.10)

Canonical reference for every URL Fluxora touches today and every URL that needs provisioning in the future. Update this file whenever an endpoint is added, a hostname is provisioned, or a third-party integration changes.

---

## Cross-references

- [`docs/04_api/01_api_contracts.md`](../04_api/01_api_contracts.md) — canonical per-endpoint request/response contracts
- [`docs/05_infrastructure/03_public_routing.md`](./03_public_routing.md) — Cloudflare Tunnel topology, routing matrix, security notes
- [`docs/05_infrastructure/04_domains_and_subdomains.md`](./04_domains_and_subdomains.md) — domain inventory, naming philosophy, TLS issuer details
- [`docs/10_planning/04_manual_tasks.md`](../10_planning/04_manual_tasks.md) — operator-driven URL provisioning tasks (Cloudflare Access, WAF rules, TURN, tunnel health alerts)

---

## A. Server REST Endpoints

All paths are under the base `http://{server_ip}:8000` on LAN or `https://fluxora-api.marshalx.dev` over WAN (Cloudflare Tunnel). Auth column uses the project's dependency naming.

### `info` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/info` | None | Server identity — name, version, tier, remote_url |
| `GET` | `/api/v1/healthz` | None | Liveness probe for Cloudflare Tunnel health check |
| `GET` | `/api/v1/info/stats` | Token OR localhost | Live CPU, RAM, network, uptime, active streams |
| `POST` | `/api/v1/info/restart` | Localhost only | Schedule graceful server restart |
| `POST` | `/api/v1/info/stop` | Localhost only | Schedule graceful server shutdown |
| `POST` | `/api/v1/info/support-bundle` | Localhost only | Generate redacted gzipped tar of operator debug state (settings + DB DDL + logs); secrets replaced with `***REDACTED***`. |

### `auth` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `POST` | `/api/v1/auth/request-pair` | None | Client initiates pairing; creates pending record |
| `GET` | `/api/v1/auth/status/{client_id}` | None | Poll pairing status; token returned once on approval |
| `POST` | `/api/v1/auth/approve/{client_id}` | Localhost only | Approve pending pair request |
| `POST` | `/api/v1/auth/reject/{client_id}` | Localhost only | Reject pending pair request |
| `DELETE` | `/api/v1/auth/revoke/{client_id}` | Localhost only | Revoke an approved client (operator action) |
| `GET` | `/api/v1/auth/clients` | Localhost only | List all paired clients |
| `GET` | `/api/v1/auth/clients/me` | Token required | Calling client's own profile (mobile profile screen) |
| `PATCH` | `/api/v1/auth/clients/me` | Token required | Self-rename `display_name` only. Cannot mutate any other client (the bearer identity drives the row); operator rename is a separate localhost-only concern. |
| `DELETE` | `/api/v1/auth/clients/me` | Token required | Self-revoke — caller's bearer + client row are torched in the same teardown as the operator-driven `/auth/revoke/{id}`. Backs the mobile sign-out flow (mobile redesign audit §17.3 #3) so the token stops authenticating immediately, not at natural expiry |
| `GET` | `/api/v1/auth/clients/me/stats` | Token required | Aggregate `{hours, movies, shows}` watch stats (mobile profile stats row) |
| `GET` | `/api/v1/auth/clients/me/continue-watching` | Token required | Files with non-zero resume position, sorted most-recent-first (mobile Home rail) |
| `GET` | `/api/v1/auth/clients/me/visible-libraries` | Token required | M6 of `13_groups_v2_content_spaces.md` — mobile Profile-screen "Locked / Unlocked / Visible Libraries" cards. Same shape as the localhost View-As route below, scoped to the calling client |
| `GET` | `/api/v1/auth/clients/{id}/visible-libraries` | Localhost only | M5 of `14_groups_management_page.md` — operator "View as" debug.  Returns `VisibleLibraries` snapshot (library_ids + provenance + locked-state buckets) for the target client right now |

### `files` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/files` | Token or localhost | List indexed media files (optional `?library_id=`) |
| `GET` | `/api/v1/files/recent` | Token or localhost | Most-recently-added files (mobile Home rail; `?limit=N` clamped to [1,50]) |
| `GET` | `/api/v1/files/search` | Token or localhost | Substring match on `name` + TMDB `title` (`?q=...&limit=N`; SQL `LIKE` for v1, FTS5 v2 swap-in) |
| `GET` | `/api/v1/files/{file_id}` | Token or localhost | Get single file by ID |
| `GET` | `/api/v1/files/{file_id}/content` | Token or localhost | Stream raw bytes (`FileResponse`) — backs M11 beyond-video viewers (PDF / photo / music) and the "Open in…" handoff. 404 (not 403) on cross-group access to prevent enumeration. |
| `POST` | `/api/v1/files/upload` | Token or localhost | Upload a file to a library |
| `DELETE` | `/api/v1/files/{file_id}` | Token or localhost | Remove file from index (does not delete from disk) |
| `POST` | `/api/v1/files/{file_id}/reset-progress` | Token or localhost | Zero `last_progress_sec` so next playback starts from 0:00 — backs the "Start over" affordance on title detail (streaming pipeline plan §4.10). 404 (not 403) when bearer caller's groups don't expose the file's library, to prevent enumeration of gated content; localhost skips the visibility filter |

### `library` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/library` | Token or localhost | List all libraries |
| `POST` | `/api/v1/library` | Token or localhost | Create a library |
| `GET` | `/api/v1/library/storage-breakdown` | Token or localhost | Per-type storage totals + disk capacity |
| `GET` | `/api/v1/library/{library_id}` | Token or localhost | Get single library |
| `PATCH` | `/api/v1/library/{library_id}` | Token or localhost | Update name and/or root_paths (type is immutable, ADR-016) |
| `DELETE` | `/api/v1/library/{library_id}` | Token or localhost | Delete library entry + file index (files on disk are NEVER touched, ADR-017) |
| `POST` | `/api/v1/library/{library_id}/scan` | Token or localhost | Walk root paths, index files, run TMDB enrichment (per-library lock — concurrent calls serialise) |
| `POST` | `/api/v1/library/{library_id}/enrich-tmdb` | Token or localhost | Re-run TMDB enrichment on rows where `tmdb_id IS NULL`; `?include_dvr=true` overrides DVR-filename skip |

### `stream` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/stream/sessions` | Localhost only | List all active stream sessions |
| `POST` | `/api/v1/stream/start/{file_id}` | Bearer token | Start FFmpeg transcode; returns HLS playlist URL |
| `GET` | `/api/v1/stream/{session_id}` | Bearer token | Get session details |
| `PATCH` | `/api/v1/stream/{session_id}/progress` | Bearer token | Record playback position |
| `POST` | `/api/v1/stream/{session_id}/seek` | Bearer token | Re-spawn FFmpeg from `seek_sec`; rewrites the playlist with `#EXT-X-DISCONTINUITY` markers |
| `POST` | `/api/v1/stream/{session_id}/fallback-transcode` | Bearer token | Plan 20 — opt-in `auto`-mode video fallback; blocklists `(client, codec)` + flips session to transcode |
| `POST` | `/api/v1/stream/{session_id}/fallback-audio-transcode` | Bearer token | Plan 21 — opt-in `auto`-mode audio-only fallback; blocklists `(client, audio_codec)` + re-encodes audio while keeping video stream-copy |
| `POST` | `/api/v1/stream/{session_id}/audio-track` | Bearer token | Plan 23 — switch source audio track by respawning FFmpeg with `-map 0:a:<index>?`; unlinks stale init.mp4; returns segment-snapped `applied_seek_sec` |
| `DELETE` | `/api/v1/stream/{session_id}` | Bearer token | Stop session and kill FFmpeg process |
| `GET` | `/api/v1/hls/{session_id}/playlist.m3u8` | Bearer token | Serve HLS playlist |
| `GET` | `/api/v1/hls/{session_id}/{segment}.ts` | Bearer token | Serve HLS segment |

### `settings` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/settings` | Localhost only | Return all server settings (incl. 18 extended fields) |
| `PATCH` | `/api/v1/settings` | Localhost only | Update one or more settings (dynamic SET-list) |

### `orders` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/orders` | Localhost only | Paginated Polar order list with license keys (`?limit=&cursor=`) |
| `GET` | `/api/v1/orders/portal-url` | Localhost only | Polar customer-portal URL; 404 if `FLUXORA_POLAR_PORTAL_URL` unset |

### `groups` router

v2 endpoints (PIN flow + per-client enrollment + master override) extend the v1 surface; full semantics in [`docs/04_api/01_api_contracts.md`](../04_api/01_api_contracts.md) and the v2 plan [`docs/10_planning/13_groups_v2_content_spaces.md`](../10_planning/13_groups_v2_content_spaces.md).

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/groups` | Token or localhost | List all groups with restrictions + member counts + v2 fields (`is_public`, `requires_pin`, `pin_mode`, `pin_model`, `icon`, `color`, `max_concurrent_streams`) |
| `POST` | `/api/v1/groups` | Localhost only | Create group with optional restrictions + optional `pin`/`pin_mode`/`pin_model`/`icon`/`color`/`max_concurrent_streams` (per-client groups reject `pin` at create) |
| `GET` | `/api/v1/groups/{id}` | Token or localhost | Get single group |
| `PATCH` | `/api/v1/groups/{id}` | Localhost only | Update group fields or restrictions; `pin` semantic null=unchanged / `""`=remove / `"<digits>"`=set; `pin_model` flip rules in API contracts |
| `DELETE` | `/api/v1/groups/{id}` | Localhost only | Delete group (cascades members + restrictions). 400 on the Public group |
| `GET` | `/api/v1/groups/{id}/members` | Token or localhost | List group members |
| `POST` | `/api/v1/groups/{id}/members` | Localhost only | Add client to group (idempotent) |
| `DELETE` | `/api/v1/groups/{id}/members/{client_id}` | Localhost only | Remove client from group |
| `PATCH` | `/api/v1/groups/{id}/members/{client_id}` | Localhost only | M5 of `14_groups_management_page.md` — set / clear per-member overrides (currently `time_window_override`).  Sentinel `start_h=0, end_h=0, days=[]` clears |
| `DELETE` | `/api/v1/groups/{id}/members/{client_id}/pin` | Localhost only | **M8** — clear a member's per-client PIN enrollment so they re-enroll on next access; also drops their grant. Idempotent |
| `POST` | `/api/v1/groups/{id}/enter` | Token only | Submit PIN to unlock a gated group for the calling client; rate-limited 5 fails / 60 s / (client, group); returns 200 + `expires_at` on success |
| `POST` | `/api/v1/groups/{id}/enroll` | Token only | **M8** — first-time per-client PIN enrollment; immediate session-length grant on success |
| `POST` | `/api/v1/groups/{id}/enroll/change` | Token only | **M8** — replace own per-client PIN; verifies `old_pin` against rate limiter |
| `DELETE` | `/api/v1/groups/{id}/grant` | Token only | Lock a previously-unlocked group on the calling client (drop own grant); idempotent |
| `GET` | `/api/v1/groups/{id}/grant-status` | Token or localhost | Whether the calling client holds a valid grant + `pin_model` + `enrollment_state ∈ {not_required, enrolled, enrollment_required}` for mobile UX routing |
| `POST` | `/api/v1/groups/{id}/grants/reset` | Localhost only | M7 follow-up — bulk-drop every active PIN grant for the group (shared-mode "Reset all PINs" Danger Zone action). Returns `{dropped: int}`. Per-client mode uses `DELETE /members/{cid}/pin` per row instead |
| `POST` | `/api/v1/groups/{id}/master-override?client_id=` | Localhost only | Operator recovery — issue a 12 h grant for `client_id` without supplying the PIN; no stored secret (auth = network proximity to the server) |

### `notifications` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/notifications` | Token or localhost | List notifications (`?unread=&limit=`) |
| `POST` | `/api/v1/notifications/{id}/read` | Token or localhost | Mark single notification as read |
| `POST` | `/api/v1/notifications/read-all` | Token or localhost | Mark all unread notifications as read |
| `DELETE` | `/api/v1/notifications/{id}` | Token or localhost | Dismiss (soft-delete) a notification |

### `activity` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/activity` | Token or localhost | Activity event log (`?limit=&since=&type=`) |

### `profile` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/profile` | Localhost only | Operator profile (includes computed `avatar_letter`) |
| `PATCH` | `/api/v1/profile` | Localhost only | Update display_name and/or email |

### `transcoding` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/transcoding/status` | Localhost only | Encoder loads, available encoders, per-encoder GPU engine + self-test result + tested-at, active transcode sessions |
| `GET` | `/api/v1/transcoding/advisor` | Localhost only | Recommendation for the active encoder (cpu_fallback / failed_active / hevc_compat / none) — drives Settings → Streaming banner |
| `GET` | `/api/v1/transcoding/devices` | Localhost only | Detected CPU + GPU inventory (lspci / wmic / system_profiler + nvidia-smi). Drives the Detected Hardware card. Cached for server lifetime. |
| `GET` | `/api/v1/transcoding/fallback-history` | Localhost only | Last 50 encoder routing decisions from `session_router` (in-memory ring buffer). Drives the FallbackHistoryPanel. |
| `POST` | `/api/v1/transcoding/benchmark` | Localhost only | Run a synthetic encode through every available encoder (per-encoder + per-resolution); persisted to `benchmark_runs`. Long-running — clients should set ≥ 90 s receive timeout. |
| `GET` | `/api/v1/transcoding/benchmark/progress` | Localhost only | In-flight benchmark progress snapshot (no DB hit; reads module-level state). Polled ~every 500 ms while a run is active. |
| `GET` | `/api/v1/transcoding/benchmark/history` | Localhost only | Recent benchmark-run summaries, newest first; per-encoder rows excluded for payload size. |
| `GET` | `/api/v1/transcoding/benchmark/history/{run_id}` | Localhost only | Full body for one stored run (per-encoder + per-resolution rows). |
| `DELETE` | `/api/v1/transcoding/benchmark/history/{run_id}` | Localhost only | Delete one stored run. |

### `logs` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/logs` | Token or localhost | Filtered, paginated structured log records (`?level=&source=&since=&until=&q=&limit=&cursor=`) |

### `webhook` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `POST` | `/api/v1/webhook/polar` | Polar HMAC signature | Polar paid-order webhook; issues license keys idempotently |

---

## B. Server WebSocket Routes

All WebSocket paths are mounted at the same base as REST. Loopback connections (desktop control panel) skip the token handshake.

| Path | Auth | Frame type | Purpose |
|------|------|-----------|---------|
| `/api/v1/ws/status` | First-message bearer token | `ping` / `pong` / `progress` | Per-client keepalive + playback progress |
| `/api/v1/ws/stats` | Loopback skip or first-message token | `{ "type": "stats", "data": {...} }` | Live system stats pushed every 1.1 s |
| `/api/v1/ws/notifications` | Loopback skip or first-message token | `{ "type": "notification", "data": {...} }` | Live notification fan-out |
| `/api/v1/ws/logs` | Loopback skip or first-message token | `{ "type": "log", "data": {...} }` | Live log tail (BroadcastHandler) |
| `/api/v1/ws/signal` | First-message bearer token | `offer` / `answer` / `ice-candidate` | WebRTC SDP/ICE relay for WAN streaming |

---

## C. Hosted Public URLs (Production Today)

| URL | Purpose | Backed by | Status |
|-----|---------|-----------|--------|
| `https://fluxora-api.marshalx.dev` | Public entry point to the home Fluxora server (REST + WS control plane; HLS blocked) | Cloudflare Tunnel `fluxora-home` → home PC `:8000` | Live ✅ |
| `https://fluxora.marshalx.dev` | Marketing landing page | Firebase Hosting — Next.js static export | Live ✅ |
| `https://uat.fluxora.marshalx.dev` | UAT / staging landing page | Firebase Hosting (`uat` channel) | Live ✅ |
| `https://marshalx.dev` | Owner brand apex | Cloudflare DNS (proxy off; apex is Firebase) | Live ✅ |
| `https://*.fluxora-streaming-platform.web.app` | Firebase auto-generated PR preview channels | Firebase Hosting | Auto-created per PR, not user-facing |

> Full domain inventory with TLS issuer, CF proxy state, and provisioning history: [`docs/05_infrastructure/04_domains_and_subdomains.md`](./04_domains_and_subdomains.md).

---

## D. Third-Party URLs We Depend On

| URL | Purpose | Auth | Notes |
|-----|---------|------|-------|
| `https://api.themoviedb.org/3/...` | TMDB metadata (movie/TV titles, posters) | API key (`FLUXORA_TMDB_KEY`) | User-supplied key; enrichment degrades gracefully if absent. Override via `FLUXORA_TMDB_BASE_URL` for users behind ISPs that block TMDB (Reliance Jio etc); see [`runbooks/12_tmdb_proxy_worker.md`](runbooks/12_tmdb_proxy_worker.md) for the Cloudflare Worker reverse proxy that handles this. |
| `https://image.tmdb.org/t/p/w342/...` | TMDB poster images (referenced by `poster_url` in MediaFile rows) | None (public) | Override via `FLUXORA_TMDB_IMAGE_BASE_URL` to route through the same proxy. |
| `https://1.1.1.1/dns-query` | DoH fallback when TMDB host is DNS-hijacked but the IP isn't blocked. Triggered lazily on first `ConnectTimeout` against the TMDB host. | None | See [`apps/server/utils/dns_override.py`](../../apps/server/utils/dns_override.py); installs a process-wide override in `socket.getaddrinfo`. |
| `https://fluxora-api.marshalx.dev/api/v1/webhook/polar` | **Inbound** — Polar sends paid-order events here | Polar Standard Webhooks HMAC (`POLAR_WEBHOOK_SECRET`) | Configured in the Polar dashboard under Webhooks |
| `https://polar.sh/<org>/portal` (configurable) | **Outbound** — Customer-portal URL returned by `GET /orders/portal-url` | None from our side; Polar handles the magic-link auth | Set via `FLUXORA_POLAR_PORTAL_URL` env var; 404 when unset |
| `1.1.1.1:80` (TCP) | Internet-connectivity probe in `system_stats_service.py` | None | Cached 30 s; used to populate `internet_connected` field in `/info/stats` |
| `https://api.cloudflare.com/client/v4/ips` | Cloudflare real-IP CIDR refresh in `utils/real_ip.py` | None (public endpoint) | Fetched periodically to keep `RealIPMiddleware` CIDR list current |
| `stun:stun.l.google.com:19302` | WebRTC STUN for ICE NAT traversal | None (public server) | Default STUN; overrideable via server config |
| `https://github.com/<owner>/<repo>` | GitHub — source hosting, Dependabot, releases, CI | GitHub token (CI only) | No production dependency; dev-time only |
| `https://sentry.io/...` (DSN) | Error monitoring; crash reports from the server | DSN via `SENTRY_DSN` env var | Optional; Sentry init is skipped when `SENTRY_DSN` is unset (conditional init in `main.py`) |

---

## E. Future / TBD URLs

These URLs are not yet live but have been scoped or referenced elsewhere in the docs. Track them here until they are provisioned (then move to Section C) or explicitly cancelled.

| URL / Pattern | Purpose | Trigger to provision | Reference |
|---------------|---------|---------------------|-----------|
| TURN server (e.g. `turn:fluxora-api.marshalx.dev:3478`) | WebRTC TURN relay for symmetric NAT clients where STUN fails | When WAN streaming reports ICE failures for a meaningful percentage of users; `fluxora_turn_url` already a config key, empty by default | [`docs/05_infrastructure/06_webrtc_and_turn.md`](./06_webrtc_and_turn.md) |
| Cloudflare Access policy on `fluxora-api.marshalx.dev/api/v1/orders` | Operator authentication for the most-sensitive admin-ish endpoints that are currently token-only | Phase 6 hardening; operator-driven | [`docs/10_planning/04_manual_tasks.md`](../10_planning/04_manual_tasks.md) |
| Tunnel-health alert webhook | Cloudflare notifies operator when the `fluxora-home` tunnel goes down | Phase 6 hardening; operator-driven | [`docs/10_planning/04_manual_tasks.md`](../10_planning/04_manual_tasks.md) |
| Cloudflare WAF custom-rule dashboard URL | WAF rule to rate-limit `/api/v1/info/stats` (60/min per IP) and block common abuse patterns | Phase 6 hardening; operator-driven | [`docs/05_infrastructure/03_public_routing.md`](./03_public_routing.md) |
| `https://polar.sh/fluxora/portal` (expected value of `FLUXORA_POLAR_PORTAL_URL`) | Customer self-service portal for Polar subscription management | Set `FLUXORA_POLAR_PORTAL_URL` in `~/.fluxora/.env` once the Polar org portal URL is confirmed | `GET /api/v1/orders/portal-url` returns 404 until this is set |
| App Store / Play Store URLs | Mobile client distribution pages for public release | Phase 6 — write when submitting to stores | [`docs/10_planning/01_roadmap.md`](../10_planning/01_roadmap.md) |
| `https://status.fluxora.marshalx.dev` | Public tunnel-up/down status page | Phase 6+ — provision if community grows; needs Cloudflare Workers + D1 | [`docs/05_infrastructure/04_domains_and_subdomains.md`](./04_domains_and_subdomains.md) |
| Email sender domain (`support@fluxora.marshalx.dev` or similar) | Transactional email if Fluxora ever sends activation or notification emails | Deferred; no email sending in v1 | Out of scope per `runbooks/README.md` |
| `https://docs.fluxora.marshalx.dev` | Public documentation site | If the community grows and `docs/` moves to a public-facing site | [`docs/05_infrastructure/04_domains_and_subdomains.md`](./04_domains_and_subdomains.md) |
| Per-user tunnel subdomains (`<id>.fluxora.cloud` or `<id>.fluxora.marshalx.dev`) | v2 multi-tenant — each operator gets their own subdomain | When multi-tenant SaaS launches (v2, scoped) | [`docs/05_infrastructure/03_public_routing.md`](./03_public_routing.md#v2--multi-tenant-rollout) |

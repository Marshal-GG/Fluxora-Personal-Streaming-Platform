# URL Inventory

> **Category:** Infrastructure
> **Status:** Active — Created 2026-05-02
> **Last Updated:** 2026-05-02

Canonical reference for every URL Fluxora touches today and every URL that needs provisioning in the future. Update this file whenever an endpoint is added, a hostname is provisioned, or a third-party integration changes.

---

## Cross-references

- [`docs/04_api/01_api_contracts.md`](../04_api/01_api_contracts.md) — canonical per-endpoint request/response contracts
- [`docs/05_infrastructure/03_public_routing.md`](./03_public_routing.md) — Cloudflare Tunnel topology, routing matrix, security notes
- [`docs/05_infrastructure/04_domains_and_subdomains.md`](./04_domains_and_subdomains.md) — domain inventory, naming philosophy, TLS issuer details
- [`docs/10_planning/04_manual_tasks.md`](../10_planning/04_manual_tasks.md) — operator-driven URL provisioning tasks (Cloudflare Access, WAF rules, TURN, tunnel health alerts)

---

## A. Server REST Endpoints

All paths are under the base `http://{server_ip}:8080` on LAN or `https://fluxora-api.marshalx.dev` over WAN (Cloudflare Tunnel). Auth column uses the project's dependency naming.

### `info` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/info` | None | Server identity — name, version, tier, remote_url |
| `GET` | `/api/v1/healthz` | None | Liveness probe for Cloudflare Tunnel health check |
| `GET` | `/api/v1/info/stats` | Token OR localhost | Live CPU, RAM, network, uptime, active streams |
| `POST` | `/api/v1/info/restart` | Localhost only | Schedule graceful server restart |
| `POST` | `/api/v1/info/stop` | Localhost only | Schedule graceful server shutdown |

### `auth` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `POST` | `/api/v1/auth/request-pair` | None | Client initiates pairing; creates pending record |
| `GET` | `/api/v1/auth/status/{client_id}` | None | Poll pairing status; token returned once on approval |
| `POST` | `/api/v1/auth/approve/{client_id}` | Localhost only | Approve pending pair request |
| `POST` | `/api/v1/auth/reject/{client_id}` | Localhost only | Reject pending pair request |
| `DELETE` | `/api/v1/auth/revoke/{client_id}` | Localhost only | Revoke an approved client (operator action) |
| `GET` | `/api/v1/auth/clients` | Localhost only | List all paired clients |

### `files` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/files` | Token or localhost | List indexed media files (optional `?library_id=`) |
| `GET` | `/api/v1/files/{file_id}` | Token or localhost | Get single file by ID |
| `POST` | `/api/v1/files/upload` | Token or localhost | Upload a file to a library |
| `DELETE` | `/api/v1/files/{file_id}` | Token or localhost | Remove file from index (does not delete from disk) |

### `library` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/library` | Token or localhost | List all libraries |
| `POST` | `/api/v1/library` | Token or localhost | Create a library |
| `GET` | `/api/v1/library/storage-breakdown` | Token or localhost | Per-type storage totals + disk capacity |
| `GET` | `/api/v1/library/{library_id}` | Token or localhost | Get single library |
| `DELETE` | `/api/v1/library/{library_id}` | Token or localhost | Delete library (not files from disk) |
| `POST` | `/api/v1/library/{library_id}/scan` | Token or localhost | Walk root paths, index files, run TMDB enrichment |

### `stream` router

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/stream/sessions` | Localhost only | List all active stream sessions |
| `POST` | `/api/v1/stream/start/{file_id}` | Bearer token | Start FFmpeg transcode; returns HLS playlist URL |
| `GET` | `/api/v1/stream/{session_id}` | Bearer token | Get session details |
| `PATCH` | `/api/v1/stream/{session_id}/progress` | Bearer token | Record playback position |
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

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/api/v1/groups` | Token or localhost | List all groups with restrictions + member counts |
| `POST` | `/api/v1/groups` | Localhost only | Create group with optional restrictions |
| `GET` | `/api/v1/groups/{id}` | Token or localhost | Get single group |
| `PATCH` | `/api/v1/groups/{id}` | Localhost only | Update group fields or restrictions |
| `DELETE` | `/api/v1/groups/{id}` | Localhost only | Delete group (cascades members + restrictions) |
| `GET` | `/api/v1/groups/{id}/members` | Token or localhost | List group members |
| `POST` | `/api/v1/groups/{id}/members` | Localhost only | Add client to group (idempotent) |
| `DELETE` | `/api/v1/groups/{id}/members/{client_id}` | Localhost only | Remove client from group |

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
| `GET` | `/api/v1/transcoding/status` | Localhost only | Encoder loads, available encoders, active transcode sessions |

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
| `https://fluxora-api.marshalx.dev` | Public entry point to the home Fluxora server (REST + WS control plane; HLS blocked) | Cloudflare Tunnel `fluxora-home` → home PC `:8080` | Live ✅ |
| `https://fluxora.marshalx.dev` | Marketing landing page | Firebase Hosting — Next.js static export | Live ✅ |
| `https://uat.fluxora.marshalx.dev` | UAT / staging landing page | Firebase Hosting (`uat` channel) | Live ✅ |
| `https://marshalx.dev` | Owner brand apex | Cloudflare DNS (proxy off; apex is Firebase) | Live ✅ |
| `https://*.fluxora-streaming-platform.web.app` | Firebase auto-generated PR preview channels | Firebase Hosting | Auto-created per PR, not user-facing |

> Full domain inventory with TLS issuer, CF proxy state, and provisioning history: [`docs/05_infrastructure/04_domains_and_subdomains.md`](./04_domains_and_subdomains.md).

---

## D. Third-Party URLs We Depend On

| URL | Purpose | Auth | Notes |
|-----|---------|------|-------|
| `https://api.themoviedb.org/3/...` | TMDB metadata (movie/TV titles, posters) | API key (`TMDB_API_KEY`) | User-supplied key; enrichment degrades gracefully if absent |
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

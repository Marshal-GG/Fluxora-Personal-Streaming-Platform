# Component Architecture

> **Category:** Architecture  
> **Status:** Active — Updated 2026-05-01 (added system stats, license, webhook, and orders services; refreshed desktop screen list; Profile Service added)

---

## Component Map

```
┌─────────────────── PC SERVER ───────────────────┐
│                                                  │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │  File API   │  │   Streaming Engine       │   │
│  │  Browser    │  │   (FFmpeg → HLS, HWA)    │   │
│  └─────────────┘  └─────────────────────────┘   │
│                                                  │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │  Library    │  │   Auth / Session Mgmt   │   │
│  │  Manager    │  │                         │   │
│  └─────────────┘  └─────────────────────────┘   │
│                                                  │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │  mDNS/      │  │   WebRTC Signaling      │   │
│  │  Zeroconf   │  │   (STUN/TURN mgmt)      │   │
│  └─────────────┘  └─────────────────────────┘   │
│                                                  │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │  License    │  │   Polar Webhook         │   │
│  │  Service    │  │   Receiver              │   │
│  └─────────────┘  └─────────────────────────┘   │
│                                                  │
│  ┌─────────────┐  ┌─────────────────────────┐   │
│  │  Settings   │  │   System Stats          │   │
│  │  Service    │  │   (psutil)              │   │
│  └─────────────┘  └─────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Group Service (client groups +          │   │
│  │  streaming restrictions)                 │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Profile Service (operator display name, │   │
│  │  email, avatar; avatar_letter computed)   │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  SQLite DB (metadata, library, sessions, │   │
│  │  user_settings [+ profile fields],       │   │
│  │  polar_orders, groups, group_members,    │   │
│  │  group_restrictions)                     │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘

┌──────────────── FLUTTER CLIENT ─────────────────┐
│                                                  │
│  Presentation Layer                              │
│  ┌──────────┐ ┌──────────┐ ┌─────────────────┐  │
│  │ Home /   │ │ Library  │ │ Player Screen   │  │
│  │ Connect  │ │ Browser  │ │ (HLS Playback)  │  │
│  └──────────┘ └──────────┘ └─────────────────┘  │
│                                                  │
│  Domain Layer (Use Cases)                        │
│  ┌────────────────────────────────────────────┐  │
│  │ StreamFile │ BrowseFiles │ DiscoverServer  │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Data Layer (Repositories + Sources)             │
│  ┌───────────────┐  ┌────────────────────────┐   │
│  │ HTTP API Repo │  │ mDNS / WebRTC Source   │   │
│  └───────────────┘  └────────────────────────┘   │
└─────────────────────────────────────────────────┘

┌──────────────── PC CONTROL PANEL ───────────────┐
│  Flutter Desktop App                             │
│  ┌──────────┐ ┌──────────┐ ┌─────────────────┐  │
│  │ Server   │ │ Active   │ │ Library / User  │  │
│  │ Settings │ │ Streams  │ │ Management      │  │
│  └──────────┘ └──────────┘ └─────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## Component Descriptions

### File API Browser
- **Responsibility:** Exposes server file system as REST endpoints; handles file listing, search, directory navigation
- **Interfaces:** `GET /files`, `GET /files/{path}`
- **Dependencies:** OS file system, SQLite (for library index)

### Streaming Engine (FFmpeg → HLS)
- **Responsibility:** Takes a file path, spawns FFmpeg subprocess, produces HLS segments served over HTTP. Reads encoder/preset/CRF from `user_settings` at start time and supports software (libx264) and hardware (NVENC/QSV/VAAPI) acceleration. On `POST /stream/start/{file_id}`, calls `group_service.get_effective_restrictions(client_id)` and `reason_to_deny(...)` before starting the session — returns 403 if the file's library is not in the client's allowed libraries or the current time is outside the client's active time window.
- **Interfaces:** `POST /stream/start/{file_id}` → returns `.m3u8` playlist URL; `DELETE /stream/{session_id}` to stop
- **Dependencies:** FFmpeg binary, `settings_service`, `group_service`, temp segment storage

### Library Manager
- **Responsibility:** Indexes media directories, fetches metadata from TMDB, stores in SQLite
- **Interfaces:** `POST /library/scan`, `GET /library/{type}`
- **Dependencies:** TMDB API, SQLite, file system

### Auth / Session Management
- **Responsibility:** Token-based auth, session storage, permission enforcement
- **Interfaces:** `POST /auth/token`, middleware on all routes
- **Dependencies:** SQLite (sessions table)

### mDNS / Zeroconf Discovery
- **Responsibility:** Broadcasts server presence on LAN, responds to client discovery queries
- **Interfaces:** UDP multicast (internal), `GET /info` (HTTP for confirmation)
- **Dependencies:** Zeroconf Python library

### WebRTC Signaling
- **Responsibility:** Coordinates offer/answer exchange between client and server for P2P connection setup
- **Interfaces:** WebSocket `/ws/signal`
- **Dependencies:** STUN server (external), TURN server (external or self-hosted — runbook in [`05_infrastructure/06_webrtc_and_turn.md`](../05_infrastructure/06_webrtc_and_turn.md))

### License Service
- **Responsibility:** Generates and validates 5-part HMAC-SHA256 license keys (`FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>`); enriches every settings response with `license_status` and `license_tier`. Operates in advisory mode if `FLUXORA_LICENSE_SECRET` is unset.
- **Interfaces:** Internal Python API (`validate_key`, `generate_key`, `LicenseResult`); CLI `python -m services.license_service --tier <plus|pro|ultimate> --days <N>`. No public HTTP surface — keys are read/written via `/settings`.
- **Dependencies:** `FLUXORA_LICENSE_SECRET` env var
- **Operations runbook:** [`docs/06_security/02_license_key_operations.md`](../06_security/02_license_key_operations.md)

### Polar Webhook Receiver
- **Responsibility:** Verifies Polar Standard Webhooks signatures, processes `order.paid` / paid `order.created` events idempotently, and delegates license-key issuance to the License Service. Stores generated keys + customer email in `polar_orders`.
- **Interfaces:** `POST /api/v1/webhook/polar`
- **Dependencies:** `POLAR_WEBHOOK_SECRET` env var, `license_service`, SQLite `polar_orders` table
- **Deployment notes:** [`docs/05_infrastructure/02_polar_webhook_deployment.md`](../05_infrastructure/02_polar_webhook_deployment.md)

### Settings Service
- **Responsibility:** Read/write `user_settings` row (server name, tier, max concurrent streams, license key, transcoding encoder/preset/CRF). Maps tier changes to stream-concurrency limits.
- **Interfaces:** `GET /api/v1/settings`, `PATCH /api/v1/settings` (both localhost-only). Internal helpers consumed by `stream` router and `ffmpeg_service`.
- **Dependencies:** SQLite `user_settings` table, `license_service` (for status enrichment)

### System Stats Service
- **Responsibility:** Live host metrics (CPU%, RAM, per-interface network rate with loopback excluded, uptime, LAN IP, cached internet probe to `1.1.1.1:80`, active stream count). Per-instance state so REST and WS subscribers don't collide on the network-rate baseline.
- **Interfaces:** `GET /api/v1/info/stats`, `WS /api/v1/ws/stats`
- **Dependencies:** `psutil`, SQLite (active stream count from `stream_sessions`)

### Orders / Licenses View
- **Responsibility:** Owner-only retrieval of issued Polar license keys for manual customer delivery. Reads from `polar_orders`.
- **Interfaces:** `GET /api/v1/orders` (localhost-only)
- **Dependencies:** SQLite `polar_orders` table

### Public Routing (v1 single-tenant Phases 1–5 complete; Phase 6 operator-driven)
- **Responsibility:** Expose the home server at `https://fluxora-api.marshalx.dev` for off-LAN clients via a Cloudflare Tunnel. Control plane only — media bandwidth stays on direct/P2P paths.
- **Interfaces:** All `/api/v1/...` paths reachable through the tunnel; HLS routes server-side blocked when `CF-Connecting-IP` is present; admin-only endpoints (`require_local_caller` / `validate_token_or_local`) reject any tunneled request.
- **Implementation:**
  - **Server:** `RealIPMiddleware` (rewrites `request.client.host` from `CF-Connecting-IP` against the published Cloudflare IP ranges), `HLSBlockOverTunnelMiddleware`, `_public_address()` probe in `system_stats_service`, `/healthz` endpoint, `remote_url` field on `/info`.
  - **Shared core:** `ApiClient` resolves between `localBaseUrl` and `remoteBaseUrl` per request via `NetworkPathDetector` (in `fluxora_core`); `SecureStorage.savePairing()` persists both URLs atomically.
  - **Mobile:** Pairing flow re-fetches `/info` post-pair to read `remote_url` and configures the dual-base ApiClient. Failure is non-fatal.
- **Dependencies:** `cloudflared` daemon (system-installed), `FLUXORA_PUBLIC_URL` / `FLUXORA_TRUST_CF_HEADERS` / `FLUXORA_BLOCK_HLS_OVER_TUNNEL` env vars.
- **Plan:** [`docs/05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md) (v1 single-tenant + v2 multi-tenant track)

### Group Service
- **Responsibility:** Manages client groups — logical bundles of paired clients that share streaming restrictions. CRUD for groups, membership, and per-group restriction records. Exposes `get_effective_restrictions(client_id)` which aggregates all active groups the client belongs to and returns the most-restrictive intersection (allowed libraries, time window, advisory bandwidth cap and max rating).
- **Interfaces:** `GET /api/v1/groups`, `POST /api/v1/groups` (localhost-only), `GET/PATCH/DELETE /api/v1/groups/{id}` (mutations localhost-only), `GET /api/v1/groups/{id}/members`, `POST /api/v1/groups/{id}/members` (localhost-only), `DELETE /api/v1/groups/{id}/members/{client_id}` (localhost-only). GETs accept bearer token or loopback auth.
- **Dependencies:** SQLite (`groups`, `group_members`, `group_restrictions` tables); consumed by `stream` router as a stream-gate hook.

### Profile Service
- **Responsibility:** Reads and writes operator profile metadata stored in the `user_settings` singleton (`display_name`, `email`, `avatar_path`, `profile_created_at`, `last_login_at`). Computes `avatar_letter` on every read — not stored in the DB. First non-whitespace char of `display_name`, else first char of `email` local-part, else `'F'`. Pass `""` to clear a field; pass `None` to leave it unchanged.
- **Interfaces:** `GET /api/v1/profile` (localhost-only), `PATCH /api/v1/profile` (localhost-only)
- **Dependencies:** SQLite `user_settings` table (profile columns added by migration 012)

### Flutter Client — Presentation Layer
- **Responsibility:** UI screens (Home, Connect, Browser, Player, Settings)
- **State Management:** BLoC or Riverpod
- **Dependencies:** Domain use cases

### Flutter Client — Domain Layer
- **Use Cases:** `StreamFileUseCase`, `BrowseFilesUseCase`, `DiscoverServerUseCase`, `AuthUseCase`
- **Pure Dart** — no framework dependencies

### Flutter Client — Data Layer
- **Repositories:** `FileRepository`, `StreamRepository`, `ServerDiscoveryRepository`
- **Sources:** HTTP (Dio), mDNS (Dart Zeroconf), WebRTC (flutter_webrtc)

### PC Control Panel (Flutter Desktop)
- **Responsibility:** Server-side dashboard — live system health, client pairing management, library + file upload, transcoding settings, license retrieval (Polar orders), live log viewer, active session monitor.
- **Screens implemented:** Dashboard (system stats + storage donut + client counts) · Clients (approve/reject/revoke + filter chips) · Library (create/scan/upload/filter) · Licenses (Polar orders + copyable license keys) · Activity (active stream sessions) · Logs (live server log viewer) · Settings (URL, tier, license key, transcoding encoder/preset/CRF). Transcoding screen scaffold pending dedicated cubit.
- **Interfaces:** Localhost HTTP to FastAPI server (no pairing — `validate_token_or_local` accepts loopback callers); WS `/ws/stats` for live dashboard updates.
- **State management:** BLoC (Cubit) with GetIt DI; `freezed` v3 for state types.
- **Routes:** `/` · `/clients` · `/library` · `/licenses` · `/activity` · `/settings` (Logs and Transcoding routes are implemented features but routing wiring depends on the redesign in progress).

---

## Communication Patterns

| From | To | Protocol | Pattern |
|------|----|----------|---------|
| Flutter Client (LAN) | FastAPI Server | HTTP REST + HLS | Request/Response, streaming |
| Flutter Client (WAN) | `fluxora-api.marshalx.dev` → home server | HTTPS via Cloudflare Tunnel | Control plane only — media stays P2P; `ApiClient` switches base URLs per request |
| Flutter Client | STUN Server | UDP | WebRTC ICE |
| Flutter Client | TURN Server | UDP/TCP | WebRTC relay (optional, see runbook) |
| Flutter Client ↔ Flutter Client / Server (P2P) | Direct or via TURN | WebRTC SCTP/data channels | Internet streaming |
| Flutter Client ↔ FastAPI Server | WebSocket | `/ws/status`, `/ws/signal`, `/ws/stats` | Bidirectional events |
| FastAPI Server | FFmpeg | Subprocess pipe | Internal process |
| FastAPI Server | SQLite | aiosqlite (WAL) | Query/Write |
| FastAPI Server | TMDB API | HTTPS REST | Request/Response (best-effort enrichment) |
| FastAPI Server | Zeroconf | UDP multicast | LAN broadcast |
| Polar.sh | FastAPI Server `/webhook/polar` | HTTPS POST + Standard Webhooks signature | Inbound webhook |
| PC Control Panel | FastAPI Server | HTTP + WS (loopback) | Request/Response, live stats |
| FastAPI Server | Cloudflare edge | Outbound WSS | Tunnel registration via `cloudflared` daemon (live as `fluxora-home`) |

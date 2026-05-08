# Component Architecture

> **Category:** Architecture  
> **Status:** Active — Updated 2026-05-07 (Group Service rewritten for v2 content-spaces redesign — additive semantic + Public group + PIN-gate + per-client enrollment + activity-feed aggregation + bulk grants reset.  Earlier 2026-05-02 round added system stats / license / webhook / orders / Profile / Notification / Activity / Transcoding / Log services + desktop screen list refresh.)

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
│  │  Notification Service (in-process        │   │
│  │  pub/sub + SQLite persistence; fans out  │   │
│  │  to WS /ws/notifications subscribers)   │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Activity Service (append-only audit     │   │
│  │  log; producer call sites in auth,       │   │
│  │  stream, library; polled by desktop      │   │
│  │  Activity screen + Dashboard widget)     │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Transcoding Service (encoder discovery  │   │
│  │  via ffmpeg -encoders; GPU probe via     │   │
│  │  nvidia-smi; backs GET /transcoding/     │   │
│  │  status — encoder loads + active         │   │
│  │  sessions with per-session metadata)     │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Log Service (reads JSON-line log file;  │   │
│  │  filters + paginates for GET /logs;      │   │
│  │  BroadcastHandler on root logger fans   │   │
│  │  live records to WS /ws/logs queues;    │   │
│  │  slow consumers drop frames)            │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  SQLite DB (metadata, library, sessions, │   │
│  │  user_settings [+ profile fields],       │   │
│  │  polar_orders, groups, group_members,    │   │
│  │  group_restrictions, group_pin_grants,   │   │
│  │  group_pin_attempts, group_member_pins,  │   │
│  │  notifications, activity_events,         │   │
│  │  benchmark_runs)                         │   │
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
- **Responsibility:** Owner-only retrieval of issued Polar license keys for manual customer delivery. Reads from `polar_orders`. Supports cursor-based pagination. Returns the Polar customer-portal URL when configured.
- **Interfaces:** `GET /api/v1/orders?limit=&cursor=` (localhost-only, paginated); `GET /api/v1/orders/portal-url` (localhost-only — returns `FLUXORA_POLAR_PORTAL_URL` or 404)
- **Dependencies:** SQLite `polar_orders` table; `FLUXORA_POLAR_PORTAL_URL` env var (optional)

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
- **Responsibility:** v2 content-spaces redesign (2026-05-07) — manages client groups as additive content-spaces.  Groups GRANT library access from a default-nothing baseline; multi-group composition is UNION (every group the client belongs to contributes its `allowed_libraries`).  Mandatory Public group auto-joined by every paired client at `auth_service.approve_client` time.  Optional PIN-gate per group with shared / per-client modes (M8).  Exposes `get_visible_libraries(client_id, *, now)` returning `VisibleLibraries(library_ids, groups_contributing, pin_locked_groups, enrollment_required_groups, time_locked_groups, groups)` — single source of truth consumed by every list endpoint AND the stream-gate via `reason_to_deny_stream`.  PIN flow helpers: `enter_pin_grant`, `enroll_pin`, `change_member_pin`, `clear_member_pin`, `revoke_pin_grant`, `revoke_all_grants_for_group`, `housekeep_pin_state`.  Activity-feed aggregation via `_emit_group_activity` + `_maybe_emit_failed_burst`.
- **Interfaces:** `GET /api/v1/groups`, `POST /api/v1/groups` (localhost-only), `GET/PATCH/DELETE /api/v1/groups/{id}` (mutations localhost-only), `GET /api/v1/groups/{id}/members` (with optional `?include=pin_state` for desktop Members-tab badges), `POST /api/v1/groups/{id}/members` (localhost-only), `PATCH /api/v1/groups/{id}/members/{cid}` (M5 — per-member time_window_override; localhost), `DELETE /api/v1/groups/{id}/members/{client_id}` (localhost-only), `DELETE /api/v1/groups/{id}/members/{cid}/pin` (M8 — clear per-client PIN; localhost), `POST /api/v1/groups/{id}/enter` (bearer — submit PIN), `POST /api/v1/groups/{id}/enroll` + `/enroll/change` (M8 bearer — per-client enrollment), `DELETE /api/v1/groups/{id}/grant` (bearer — lock), `GET /api/v1/groups/{id}/grant-status` (bearer — pin_model + enrollment_state for mobile UX routing), `POST /api/v1/groups/{id}/grants/reset` (M7 — bulk drop grants for shared-mode Reset PINs; localhost), `POST /api/v1/groups/{id}/master-override?client_id=` (localhost — operator recovery, no PIN).  Mobile bearer-twin: `GET /api/v1/auth/clients/me/visible-libraries`.  GETs accept bearer token or loopback auth.
- **Dependencies:** SQLite (`groups`, `group_members`, `group_restrictions`, `group_pin_grants`, `group_pin_attempts`, `group_member_pins` tables; migrations 011 + 025 + 026); `auth_service.approve_client` for the Public auto-membership hook; `activity_service.record` for audit-trail emit (lazy import to avoid cycle); consumed by every list endpoint (`library`, `files`, `auth/me/continue-watching`) for visibility filtering AND by the `stream` router for the gate hook.
- **Plans:** [`docs/10_planning/13_groups_v2_content_spaces.md`](../10_planning/13_groups_v2_content_spaces.md) (semantic redesign + Public + PIN gate + M8) + [`docs/10_planning/14_groups_management_page.md`](../10_planning/14_groups_management_page.md) (dedicated desktop edit page).  ADRs: ADR-018 / ADR-019 / ADR-020 in [`docs/10_planning/02_decisions.md`](../10_planning/02_decisions.md).

### Profile Service
- **Responsibility:** Reads and writes operator profile metadata stored in the `user_settings` singleton (`display_name`, `email`, `avatar_path`, `profile_created_at`, `last_login_at`). Computes `avatar_letter` on every read — not stored in the DB. First non-whitespace char of `display_name`, else first char of `email` local-part, else `'F'`. Pass `""` to clear a field; pass `None` to leave it unchanged.
- **Interfaces:** `GET /api/v1/profile` (localhost-only), `PATCH /api/v1/profile` (localhost-only)
- **Dependencies:** SQLite `user_settings` table (profile columns added by migration 012)

### Notification Service
- **Responsibility:** Creates and persists in-app notifications, then broadcasts each new notification to all active WebSocket subscribers via an in-process asyncio pub/sub bus. `create()` inserts the row and fans out to every subscribed queue. `subscribe()` / `unsubscribe()` manage the queue registry. Slow consumers drop frames — the queue is capped at 100 items — so producer paths are never blocked. CRUD: `list_notifications()` (with optional `only_unread` filter), `mark_read()`, `mark_all_read()`, `dismiss()` (soft-delete via `dismissed_at`). Four built-in emitters call `notification_service.create()` asynchronously from their normal flows; each emitter wraps the call in `try/except` so notification failures are non-fatal.
- **Interfaces:** `GET /api/v1/notifications`, `POST /api/v1/notifications/{id}/read`, `POST /api/v1/notifications/read-all`, `DELETE /api/v1/notifications/{id}` (all `validate_token_or_local`); `WS /api/v1/ws/notifications` (loopback-or-token auth, same pattern as `/ws/stats`)
- **Dependencies:** SQLite `notifications` table (migration 013); consumed as a producer by `auth_service`, `license_service`, `routers/stream.py`, and `library_service`

### Activity Service
- **Responsibility:** Append-only audit trail of notable server actions. `record()` inserts one event row into `activity_events`; each producer call site wraps the call in `try/except` so a missing audit row never breaks the underlying flow. `list_events()` returns events most-recent-first, with optional `since` (ISO-8601 cutoff) and `type_prefix` (`LIKE 'prefix%'`) filters. Invalid `payload` JSON is silently coerced to `null` rather than raising. The desktop Activity screen and Dashboard "Recent Activity" widget poll this endpoint.
- **Interfaces:** `GET /api/v1/activity?limit=&since=&type=` (`validate_token_or_local`; limit 1–200, default 50)
- **Dependencies:** SQLite `activity_events` table (migration 014); produced by `routers/stream.py` (`stream.start`, `stream.end`), `services/auth_service.py` (`client.pair`, `client.approve`, `client.reject`, `client.revoke` — emitted from BOTH operator-driven `DELETE /auth/revoke/{id}` AND mobile self-revoke `DELETE /auth/clients/me`, distinguished via `actor_kind='operator'` vs `'client'`; `client.profile_updated` — emitted from mobile self-rename `PATCH /auth/clients/me` with `actor_kind='client'`, settings remediation M2.5), and `services/library_service.py` (`library.scan`)

### Transcoding Service
- **Responsibility:** Provides a live view of transcoding load across all FFmpeg encoders. Discovers available encoders by parsing `ffmpeg -encoders` output once and caching the result. Probes NVENC GPU utilization via `nvidia-smi` (best-effort — returns `None` if unavailable or on non-NVIDIA hardware). Builds the `TranscodingStatusResponse` by joining active stream sessions from SQLite with the encoder load data.
- **Interfaces:** `GET /api/v1/transcoding/status` (localhost-only); internal `TranscodingService.get_transcoding_status(db)`
- **Dependencies:** FFmpeg binary (for encoder discovery), `nvidia-smi` (optional, NVENC only), SQLite `stream_sessions` table

### Log Service
- **Responsibility:** Reads `~/.fluxora/logs/server.log` (JSON-line format written by `python-json-logger`) and provides filtered, cursor-paginated access via REST. Also manages an in-process pub/sub bus via a `BroadcastHandler` (a custom Python `logging.Handler`) attached to the root logger at server startup. Every log record emitted by any logger is forwarded to subscribed asyncio queues; slow consumers drop frames rather than blocking the logging path.
- **Interfaces:** `GET /api/v1/logs?level=&source=&since=&until=&q=&limit=&cursor=` (`validate_token_or_local`); `WS /api/v1/ws/logs` (loopback-or-token auth, same pattern as `/ws/stats`); internal `log_service.list_logs()`, `subscribe()`, `unsubscribe(q)`
- **Dependencies:** JSON log file (`~/.fluxora/logs/server.log`); `python-json-logger` (for structured file output)

### Flutter Client — Presentation Layer
- **Responsibility:** UI screens (Home, Connect, Browser, Player, Settings, plus the M2–M8 redesign surfaces — Discover/Library/Search/Notifications/Detail/Episodes/Downloads/Profile + the M5–M7 player chrome + mini-player)
- **State Management:** BLoC (Cubit / Bloc) — no Riverpod
- **Singleton cubits (mobile, post-M7+M8):** `PlayerCubit` (doubles as the `PlaybackProvider` per mobile redesign plan §9.2 — fullscreen player + mini-player consume the same instance) and `NotificationsCubit` (live-tail must survive screen back-pops to feed the Home tab bell badge). Registered as `GetIt.lazySingleton`s; consumed via `BlocProvider.value`.
- **Dependencies:** Domain use cases

### Flutter Client — Domain Layer
- **Use Cases:** `StreamFileUseCase`, `BrowseFilesUseCase`, `DiscoverServerUseCase`, `AuthUseCase`
- **Repositories:** `LibraryRepository`, `PlayerRepository`, `AuthRepository`, `ServerDiscoveryRepository`, `NotificationsRepository` (M8 — added on mobile to mirror the existing desktop pattern; both clients call `/api/v1/notifications` via 5-second REST polling. WS migration deferred until a shared HMAC-bearer `WebSocketClient` wrapper lands in `fluxora_core` — both repos carry `// TODO(WS):` markers.)
- **Pure Dart** — no framework dependencies

### Flutter Client — Data Layer
- **Repositories:** `FileRepository`, `StreamRepository`, `ServerDiscoveryRepository`, `NotificationsRepositoryImpl` (5-second poll loop yielding previously-unseen `AppNotification` IDs)
- **Sources:** HTTP (Dio via `fluxora_core/network/api_client.dart`), mDNS (Dart `multicast_dns`), WebRTC (`flutter_webrtc`)

### PC Control Panel (Flutter Desktop)
- **Responsibility:** Server-side dashboard — live system health, client pairing management, library + file upload, transcoding settings, license retrieval (Polar orders), live log viewer, active session monitor.
- **Screens implemented:** Dashboard · Clients · Library · Groups · Activity · Transcoding (+ Encoder Settings) · Logs · Settings (6 tabs — General/Network/Streaming/Security/Advanced/About) · Subscription (Plans/Billing/Manage — replaces the retired Licenses screen) · Profile · Help. M3-M10 of the desktop redesign covers all of these; see [`docs/11_design/desktop_redesign_plan.md`](../11_design/desktop_redesign_plan.md).
- **Interfaces:** Localhost HTTP to FastAPI server (no pairing — `validate_token_or_local` accepts loopback callers); WS `/ws/stats` and `/ws/notifications` for live dashboard / notifications updates.
- **State management:** BLoC (Cubit) with GetIt DI; `freezed` v3 for state types.
- **Routes:** `/` · `/clients` · `/library` · `/groups` · `/activity` · `/transcoding` (+ `/transcoding/encoder`) · `/logs` · `/settings` · `/subscription` · `/profile` · `/help` (the legacy `/licenses` route was deleted at M9 cleanup; license display lives on the Subscription → Billing tab now).

---

## Communication Patterns

| From | To | Protocol | Pattern |
|------|----|----------|---------|
| Flutter Client (LAN) | FastAPI Server | HTTP REST + HLS | Request/Response, streaming |
| Flutter Client (WAN) | `fluxora-api.marshalx.dev` → home server | HTTPS via Cloudflare Tunnel | Control plane only — media stays P2P; `ApiClient` switches base URLs per request |
| Flutter Client | STUN Server | UDP | WebRTC ICE |
| Flutter Client | TURN Server | UDP/TCP | WebRTC relay (optional, see runbook) |
| Flutter Client ↔ Flutter Client / Server (P2P) | Direct or via TURN | WebRTC SCTP/data channels | Internet streaming |
| Flutter Client ↔ FastAPI Server | WebSocket | `/ws/status`, `/ws/signal`, `/ws/stats`, `/ws/logs` | Bidirectional events |
| FastAPI Server | FFmpeg | Subprocess pipe | Internal process |
| FastAPI Server | SQLite | aiosqlite (WAL) | Query/Write |
| FastAPI Server | TMDB API | HTTPS REST | Request/Response (best-effort enrichment) |
| FastAPI Server | Zeroconf | UDP multicast | LAN broadcast |
| Polar.sh | FastAPI Server `/webhook/polar` | HTTPS POST + Standard Webhooks signature | Inbound webhook |
| PC Control Panel | FastAPI Server | HTTP + WS (loopback) | Request/Response, live stats |
| FastAPI Server | Cloudflare edge | Outbound WSS | Tunnel registration via `cloudflared` daemon (live as `fluxora-home`) |

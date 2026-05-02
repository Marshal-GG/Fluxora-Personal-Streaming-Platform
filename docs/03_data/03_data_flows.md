# Data Flow Diagrams

> **Category:** Data  
> **Status:** Active - Updated 2026-05-02 (Polar payment webhook flow added; stream-gate group enforcement flow added; Notification fan-out flow added; Activity event log flow added; §7.9 Log Pipeline flow added)

---

## Flow 1 — Client Connects to Server

```
[Flutter Client] 
    │
    ├──▶ mDNS Query broadcast (LAN)
    │       │
    │       ├── Server found on LAN ──▶ Direct HTTP connection ──▶ [FastAPI Server]
    │       │
    │       └── No LAN response ──▶ WebRTC Handshake via STUN
    │                                   │
    │                                   ├── P2P possible ──▶ WebRTC stream
    │                                   │
    │                                   └── P2P blocked ──▶ TURN relay ──▶ [FastAPI Server]
    │
    └──▶ [Connection established → Auth token exchange → Session created]
```

---

## Flow 2 — File Streaming

```
[Flutter Client]
    │
    ├──▶ GET /stream/{file_id}
    │
[FastAPI Server]
    │
    ├──▶ Validate auth token (SQLite: clients table)
    ├──▶ Lookup file path (SQLite: media_files)
    ├──▶ Spawn FFmpeg subprocess
    │       │
    │       └──▶ Transcode → HLS segments (.ts) + playlist (.m3u8)
    │                │
    │                └──▶ Serve via HTTP
    │
    └──▶ Write StreamSession record (SQLite: stream_sessions)
    
[Flutter Client]
    │
    └──▶ video_player / better_player loads .m3u8
            │
            └──▶ Requests .ts segments sequentially ──▶ Playback
```

---

## Flow 3 — Library Scan

```
[PC Control Panel] or [Server startup]
    │
    └──▶ POST /library/scan
    
[FastAPI Server]
    │
    ├──▶ Walk root_paths (file system)
    ├──▶ For each media file:
    │       ├──▶ Check if already in SQLite (skip if up-to-date)
    │       ├──▶ Extract metadata (FFprobe / file stats)
    │       ├──▶ Query TMDB API for match (if library type = movies/tv)
    │       └──▶ INSERT / UPDATE media_files in SQLite
    │
    └──▶ Update library.last_scanned timestamp
```

---

## Flow 4 — Client Auth / Pairing

```
[Flutter Client]
    │
    └──▶ GET /info (discovers server, gets server name)
    
[Flutter Client] ──▶ POST /auth/request-pair { device_name, platform }
    │
[FastAPI Server]
    │
    └──▶ Creates client record, is_trusted = false
    └──▶ Sends notification to PC Control Panel
    
[PC Control Panel] ──▶ User approves pairing
    │
[FastAPI Server]
    │
    └──▶ Updates clients.is_trusted = true
    └──▶ Returns auth_token to Flutter Client
    
[Flutter Client] ──▶ GET /info (re-fetched post-pair to read remote_url)
    │
    └──▶ Stores auth_token + serverUrl + clientId + remoteUrl atomically
         via SecureStorage.savePairing()
    └──▶ Configures ApiClient with localBaseUrl + remoteBaseUrl;
         all future requests are routed via NetworkPathDetector
         (LAN → local, WAN → remote)
```

The post-pair `/info` fetch is wrapped in a try/catch — if it fails the
client persists with `remoteUrl = null` and operates LAN-direct. See
`docs/05_infrastructure/03_public_routing.md` Phase 4.

---

## Flow 5 - Polar Paid Order to License Key

```
[Polar]
    |
    |---> POST /api/v1/webhook/polar
          Headers: webhook-id, webhook-timestamp, webhook-signature

[FastAPI Server]
    |
    |---> Verify Standard Webhooks signature before JSON parsing
    |---> Reject replayed deliveries outside timestamp tolerance
    |---> For order.paid:
          |
          |---> Read product.metadata.tier
          |---> Check polar_orders for existing order_id
          |---> Generate FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG> key (nonce = order_id)
          |---> INSERT polar_orders(order_id, tier, license_key, processed_at)
          |---> Return 200 with issued=true, without echoing the key
```

Notes:
- `order.created` is processed only when the payload is already marked paid.
- Duplicate deliveries return `200` with `status: "skipped"` to stop retry loops.
- Customer email is not stored; license keys are not logged.

---

---

## Flow 6 — Stream-Gate Group Enforcement

When a client requests `POST /api/v1/stream/start/{file_id}`, the stream router
performs a group-restriction check before the existing tier-concurrency check:

```
[Flutter Client]
    │
    └──▶ POST /api/v1/stream/start/{file_id}

[FastAPI Server — routers/stream.py]
    │
    ├──▶ Validate bearer token → resolve client_id
    ├──▶ Fetch media_file row → get library_id
    │
    ├──▶ group_service.get_effective_restrictions(client_id)
    │       │
    │       └──▶ Query: JOIN group_members → groups → group_restrictions
    │                   WHERE g.status = 'active' AND m.client_id = ?
    │
    │           Combine across all matching rows:
    │             allowed_libraries  → set intersection (most restrictive)
    │             bandwidth_cap_mbps → minimum (most restrictive)
    │             time_windows       → collected as a list (AND-combined)
    │             max_rating         → last non-null value (advisory)
    │
    │           Returns: EffectiveRestrictions(
    │             allowed_libraries: frozenset | None,
    │             bandwidth_cap_mbps: int | None,
    │             time_windows: tuple[dict, ...],
    │             max_rating: str | None
    │           )
    │
    ├──▶ group_service.reason_to_deny(restrictions, library_id=file.library_id)
    │       │
    │       ├── If allowed_libraries is not None AND library_id not in set
    │       │       → return "Library not allowed for this client's group(s)"
    │       │
    │       ├── For each time_window in time_windows:
    │       │       if current server-local time is NOT inside the window
    │       │           → return "Outside the allowed streaming time window"
    │       │
    │       └── Return None  ← stream is allowed to proceed
    │
    ├── reason_to_deny returns a string → 403 Forbidden with the reason string
    │
    └── reason_to_deny returns None
            │
            └──▶ [Existing tier-concurrency check → FFmpeg spawn → session creation]
```

### Multi-group intersection semantics

A client can be in multiple groups. The effective restriction is the
**most restrictive** combination across every active group:

| Field | Combine rule | Example |
|-------|-------------|---------|
| `allowed_libraries` | Set intersection — library must be in *every* group's allow-list | Group A allows `[lib-1, lib-2]`; Group B allows `[lib-2, lib-3]` → effective = `{lib-2}` |
| `bandwidth_cap_mbps` | Minimum — lowest cap wins | Group A caps at 20 Mbps; Group B caps at 10 Mbps → effective = 10 Mbps |
| `time_windows` | AND-combined — stream must satisfy *every* group's window | Group A: 15:00–21:00; Group B: 08:00–22:00 → must be within both windows simultaneously |
| `max_rating` | Advisory only in v1 — recorded but not enforced | `media_files` has no rating column; enforcement deferred |

Inactive groups (`status = 'inactive'`) are completely ignored — they contribute no restrictions and their members are treated as if unrestricted.

---

---

## Flow 7 — Notification Fan-out

When any producer service calls `notification_service.create()`, the notification is persisted
and immediately broadcast to every active WebSocket subscriber:

```
[Producer service]
    │
    │  (e.g. auth_service.create_pair_request,
    │        license_service.emit_license_expiry_warnings,
    │        routers/stream.py start_stream FFmpeg-failure block,
    │        library_service.get_storage_breakdown)
    │
    └──▶ notification_service.create(db, type, category, title, message, ...)

[notification_service.create()]
    │
    ├──▶ INSERT INTO notifications (...) → row persisted in SQLite
    │
    └──▶ Broadcast NotificationResponse to every subscriber's asyncio.Queue
            │
            ├── Queue max size: 100 items per subscriber
            ├── If queue is full → frame DROPPED (slow consumer policy)
            └── Producer continues without blocking

[WS /api/v1/ws/notifications — one coroutine per connected client]
    │
    ├── On connect: call subscribe() → receive a dedicated asyncio.Queue
    │
    ├── Drain loop: await queue.get() → send_text({"type":"notification","data":<payload>})
    │
    └── On disconnect: call unsubscribe(queue) → queue removed from registry

[Desktop sidebar bell]
    │
    └── WS frame received → bell badge increments; panel re-fetches
        GET /api/v1/notifications?unread=true to populate the list
```

### Emitter catalogue and de-dupe rules

| Emitter | Trigger | Type | Category | De-dupe |
|---------|---------|------|----------|---------|
| `auth_service.create_pair_request` | New device sends pair request | `info` | `client` | None — every new pairing creates a notification |
| `license_service.emit_license_expiry_warnings` | Server startup, after `init_db` | `error` (expired) / `warning` (≤30 days) | `license` | 1-day cooldown: skipped if a notification with the same type + category was created within the last 24 hours |
| `routers/stream.py start_stream` (FFmpeg failure) | FFmpeg process fails to start or crashes during a stream session | `error` | `transcode` | None — every failure creates a notification; `related_id` = session UUID |
| `library_service.get_storage_breakdown` | After computing storage usage, if >90% | `warning` | `storage` | 1-day cooldown: same as license warnings |

All emitters are wrapped in `try/except` with logging only — a notification write failure must never break the underlying flow.

---

---

## Flow 8 — Activity Event Recording

Activity events are written by producer call sites and polled by the desktop
Activity screen and Dashboard "Recent Activity" widget:

```
[Producer service / router]
    │
    │  (auth_service.create_pair_request   → type="client.pair"
    │   auth_service.approve_client        → type="client.approve"
    │   auth_service.reject_client         → type="client.reject"
    │   routers/stream.py start_stream     → type="stream.start"
    │   routers/stream.py stop_stream      → type="stream.end"
    │   library_service.scan_library       → type="library.scan"  [only if added > 0])
    │
    └──▶ activity_service.record(db, type, summary, actor_kind?, actor_id?,
                                  target_kind?, target_id?, payload?)
         │  (wrapped in try/except — failures are logged but never re-raised)
         │
         ├──▶ uuid.uuid4() → event id
         ├──▶ datetime.now(UTC).isoformat() → created_at
         ├──▶ json.dumps(payload) if payload else None → payload_json
         └──▶ INSERT INTO activity_events (...) + await db.commit()

[Desktop Activity Screen / Dashboard widget]
    │
    └──▶ GET /api/v1/activity?limit=N&since=<ts>&type=<prefix>
         │
         ├── validate_token_or_local → passes for loopback or valid bearer
         │
         └──▶ activity_service.list_events(db, limit, since, type_prefix)
                 │
                 ├── SELECT * FROM activity_events [WHERE ...] ORDER BY created_at DESC LIMIT ?
                 ├── For each row: json.loads(payload) if payload else None
                 │       (invalid JSON → null, warning logged, no exception)
                 └── Returns list[ActivityEventResponse]
```

### Producer call sites and payloads

| Call site | type | actor_kind | target_kind | payload fields |
|-----------|------|-----------|------------|----------------|
| `auth_service.create_pair_request` | `client.pair` | `client` | `client` | `device_name`, `platform` |
| `auth_service.approve_client` | `client.approve` | `operator` | `client` | — |
| `auth_service.reject_client` | `client.reject` | `operator` | `client` | — |
| `routers/stream.py start_stream` | `stream.start` | `client` | `session` | `file_id`, `connection_type` |
| `routers/stream.py stop_stream` | `stream.end` | `client` | `session` | — |
| `library_service.scan_library` (added > 0) | `library.scan` | `system` | `library` | `files_added` |

---

---

## Flow 9 — Log Pipeline (§7.9 Structured Logs)

Every log record emitted by any Python logger in the server is:
1. Written to the rotating JSON-line file (file handler)
2. Forwarded live to all WebSocket subscribers (BroadcastHandler)
3. Available for historical retrieval with filtering (REST endpoint)

```
[Python logger.log(level, message)]
    │
    ├──▶ FileHandler (python-json-logger)
    │       │
    │       └──▶ ~/.fluxora/logs/server.log (rotating, JSON-line)
    │                 Each line: {"asctime": "...", "levelname": "INFO",
    │                             "name": "fluxora.stream", "message": "..."}
    │
    └──▶ BroadcastHandler (attached to root logger at startup)
            │
            └──▶ fan-out to all subscribed asyncio.Queue instances
                    │
                    ├── Queue max size: 100 items per subscriber
                    ├── If queue is full → frame DROPPED (slow consumer policy)
                    └── Logger continues without blocking

[WS /api/v1/ws/logs — one coroutine per connected client]
    │
    ├── On connect: log_service.subscribe() → dedicated asyncio.Queue
    ├── Drain loop: await queue.get() → send_text({"type":"log","data":<payload>})
    └── On disconnect: log_service.unsubscribe(queue) → removed from registry

[REST GET /api/v1/logs?level=&source=&since=&until=&q=&limit=&cursor=]
    │
    └──▶ log_service.list_logs(...)
            │
            ├── Open ~/.fluxora/logs/server.log
            ├── Seek to line offset `cursor`
            ├── Parse each line as JSON → LogRecord(ts, level, source, message)
            ├── Apply filters: level ≥ threshold, source prefix match,
            │                  ts in [since, until], q in message (case-insensitive)
            ├── Collect up to `limit` records
            └── Return LogListResponse(items=[...], next_cursor=<offset|null>)
```

### Console vs file formatter

| Handler | Formatter | When |
|---------|-----------|------|
| `StreamHandler` (stdout) | Human-readable string | Always (dev and prod) |
| `RotatingFileHandler` | JSON (`python-json-logger`) | Always — `log_service` depends on JSON format |

---

## Event Flows

| Event | Trigger | Action |
|-------|---------|--------|
| `stream.started` | Client begins HLS playback | Create `StreamSession` record |
| `stream.progress` | Client WebSocket heartbeat | Update `progress_sec` |
| `stream.ended` | Client disconnects / stops | Set `ended_at` on session |
| `library.scan_complete` | Scan finishes | Update `last_scanned`; notify panel |
| `client.pair_request` | New client connects | Notify control panel for approval |
| `license.issued` | Polar paid order webhook | Store idempotent license issuance row in `polar_orders` |
| `stream.denied` | Client in a restricted group attempts to stream outside policy | Return `403` with reason string; no session or FFmpeg process created |

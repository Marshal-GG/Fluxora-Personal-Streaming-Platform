# Data Flow Diagrams

> **Category:** Data  
> **Status:** Active - Updated 2026-05-08 (Flow 4 gains a Sign-out / self-revoke sub-flow — mobile sign-out now calls `DELETE /auth/clients/me` before clearing local state so the bearer can't outlive the user's tap; mobile redesign audit §17.3 #3).  Earlier 2026-05-07: Flow 6 stream-gate flow rewritten for v2 content-spaces redesign — `get_visible_libraries` + `reason_to_deny_stream` replace v1 intersection logic; multi-group composition is now UNION not intersection; new Flow 6b for the PIN-flow + per-client enrollment.  Earlier 2026-05-02: Polar payment webhook flow + Notification fan-out + Activity event log + §7.9 Log Pipeline flow.

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

### Sign-out (self-revoke) — added 2026-05-08

```
[Flutter Client] ──▶ User taps Sign out → confirm dialog
    │
    ├──▶ DELETE /auth/clients/me  (bearer-validated)
    │       │
    │   [FastAPI Server]
    │       └──▶ auth_service.revoke_client(client_id)
    │             • status → 'rejected'
    │             • auth_token zeroed
    │             • is_trusted = 0
    │       └──▶ activity_events INSERT (type=client.revoke,
    │            actor_kind='client', actor_id=target_id=client_id)
    │       └──▶ 204 No Content
    │
    ├──▶ apiClient.clearBearerToken()
    ├──▶ secureStorage.deleteAll()
    └──▶ context.go(/splash)   ← was /connect pre-M12; auth-gate
                                  redirects to /splash when no token,
                                  so the explicit nav matches the
                                  post-M12 onboarding entry point.
```

Server-side revoke fires **first** so a stolen-and-not-yet-cleared token
on the same device can't authenticate after the user taps.  Network
failure on the DELETE is non-fatal — the local teardown still runs so
a dead network can't trap the user on the screen (audit §17.3 #3 of
the mobile redesign plan).

### Display-name self-rename — added 2026-05-08

Mobile-settings remediation plan M2.5 added a bearer-only PATCH so
paired clients can update their own display name from the new Account
screen.

```
[Flutter Client] ──▶ User opens Profile → Account → Display name
                     → FluxBottomSheet → types new name → Save
    │
    ├──▶ PATCH /auth/clients/me  body { display_name }
    │       │
    │   [FastAPI Server]
    │       └──▶ UpdateClientMeRequest validates body
    │             • trims whitespace; rejects blank-after-trim, >50,
    │               control chars \x00-\x1f → 422
    │       └──▶ auth_service.update_client_display_name(client_id, name)
    │             • UPDATE clients SET name = ?, last_seen = ? WHERE id = ?
    │       └──▶ activity_events INSERT (type=client.profile_updated,
    │            actor_kind='client', actor_id=target_id=client_id)
    │       └──▶ 200 OK + ClientMeResponse (re-fetched row)
    │
    └──▶ ProfileCubit.refresh()   → next Profile-tab paint reflects
                                    the new name in the Identity card
                                    + the settings list's Account row
                                    sub-text (which carries email).
```

The endpoint is bearer-only by design — the target `client_id` is
resolved from the token, so the request can't be spoofed to rename a
different client's row. The operator-driven rename path is a separate
concern (when added) on a localhost-gated route.

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

## Flow 6 — Stream-Gate Visibility Resolution (v2 content-spaces)

**v2 redesign 2026-05-07** — replaces the v1 subtractive `get_effective_restrictions` + `reason_to_deny` flow.  Plan: [`docs/10_planning/13_groups_v2_content_spaces.md`](../10_planning/13_groups_v2_content_spaces.md).  ADR-018 captures the semantic flip.

Every list endpoint (`/library`, `/files`, `/files/recent`, `/files/search`, `/files/{id}`, `/auth/clients/me/continue-watching`) AND the stream-gate consume the same `get_visible_libraries(client_id, *, now)` function — single source of truth so the surfaces a client sees can never disagree with what they can play.

```
[Flutter Client]
    │
    └──▶ POST /api/v1/stream/start/{file_id}

[FastAPI Server — routers/stream.py]
    │
    ├──▶ Validate bearer token → resolve client_id
    ├──▶ Fetch media_file row → get library_id (may be NULL for legacy uploads)
    │
    ├──▶ group_service.reason_to_deny_stream(
    │       db, client_id, library_id=file.library_id, now=...
    │    )
    │       │
    │       └──▶ _resolve_membership(db, client_id, now=...)
    │             │
    │             └──▶ ONE SQL query joins group_members → groups
    │                  → group_restrictions LEFT JOINs grant + enrollment +
    │                  attempt-count subqueries.  Returns _MembershipState
    │                  per group: { name, is_active, requires_pin, pin_model,
    │                  pin_mode, is_enrolled, is_pin_unlocked, in_time_window,
    │                  libraries (JSON-decoded set), icon, color,
    │                  grant_expires_at }.  The per-member time_window_override
    │                  (M5) wins over the group's window when present.
    │
    │       For each membership state, picks the most-informative deny reason:
    │         1. If at least one group exposes the library but is currently
    │            time-locked → "Outside the allowed streaming time window"
    │         2. Otherwise → "Library not allowed for this client's group(s)"
    │            — covers PIN-locked AND missing-from-allowlist; deny is
    │            generic so the surface doesn't leak the existence of
    │            gated content the client hasn't unlocked.
    │
    │       Returns:
    │         None      → stream allowed to proceed
    │         <reason>  → string for the 403 response body
    │
    ├── reason_to_deny_stream returns a string → 403 Forbidden + reason
    │
    └── reason_to_deny_stream returns None
            │
            └──▶ [Tier-concurrency check → per-group concurrent-stream-cap
                  check (M7 Tier-2; checks active sessions among group
                  members; 503 with retry-after when exceeded) → FFmpeg
                  spawn → session creation]
```

`media_files.library_id IS NULL` (uploaded outside any library) is an explicit passthrough — those files stay universally visible so legacy uploads don't disappear post-migration-025.

### Multi-group composition — UNION (additive content-spaces)

v2 flips the v1 intersection rule (ADR-015 → superseded by ADR-018).  A client in multiple groups now sees the **union** of every active group's `allowed_libraries`:

| Field | v2 combine rule | Example |
|---|---|---|
| `allowed_libraries` | **UNION** — library is visible if ANY group exposes it (additive content-spaces) | Public exposes `[lib-movies]`; Kids exposes `[lib-cartoons]` → kid in Public+Kids sees `{lib-movies, lib-cartoons}` |
| `time_window` | per-group; group is filtered out at "now" if outside its window | Public always-on; Kids 18:00–22:00 → outside that window the kid sees only Public's libraries.  Member's `time_window_override` (M5) wins over the group's window. |
| `bandwidth_cap_mbps` | min-wins per group (advisory in v2 — recorded, not enforced) | Group A caps 20 Mbps; B caps 10 → effective 10 Mbps |
| `max_concurrent_streams` (M7 Tier-2) | per-group; checked at stream-start by counting active sessions among the group's members; 503 when exceeded | Adults caps at 2; if 2 Adults members streaming, the third's stream-start returns 503 |
| `max_rating` | advisory in v2 — recorded, not enforced | `media_files` has no rating column; enforcement deferred |

Inactive groups (`status = 'inactive'`) are skipped entirely — they contribute nothing to visibility.  The mandatory Public group every paired client auto-joins (via `auth_service.approve_client`) provides the household-shared baseline so a client in zero groups is impossible by construction.

PIN-gated groups (M4 + M8) only contribute when the client has a non-expired `group_pin_grants` row.  Per-client mode (M8) additionally requires a `group_member_pins` enrollment row before the client can even attempt `/enter`.

---

## Flow 6b — PIN unlock (M4) + Per-client enrollment (M8)

```
Mobile / desktop client wants to access a gated group's libraries
    │
    ├──▶ GET /api/v1/groups/{id}/grant-status
    │       Returns { unlocked, expires_at, pin_model, enrollment_state }
    │
    ├── enrollment_state = 'enrollment_required'  (M8 per-client mode + no enrollment)
    │       │
    │       └──▶ POST /api/v1/groups/{id}/enroll  body: {pin}
    │              → server validates strength; HMAC-hashes; inserts
    │                group_member_pins row + immediate session-length grant
    │              → mobile renders PinEnrollmentSheet (set + confirm)
    │
    ├── enrollment_state = 'enrolled' OR 'not_required'
    │       │
    │       └──▶ POST /api/v1/groups/{id}/enter  body: {pin}
    │              → server branches on pin_model: shared reads
    │                groups.pin_hash; per-client reads
    │                group_member_pins(group_id, client_id).pin_hash
    │              → success: insert grant_pin_grants row with TTL by
    │                pin_mode (session=12h, per-entry=5min);
    │                fire activity_event 'group.pin.unlock'
    │              → failure: write group_pin_attempts(success=0); rate
    │                limit 5 fails / 60 s / (client, group) → 429;
    │                burst aggregator (M7 follow-up) emits one
    │                activity_event 'group.pin.failed-burst' per 5
    │                fails / 10 min window
    │              → mobile renders PinEntrySheet (label adapts to
    │                pin_model: "Group PIN" vs "Your PIN")
    │
    ├──▶ Operator-side recovery
    │       │
    │       ├── POST /api/v1/groups/{id}/master-override?client_id=
    │       │     (localhost only — auth = network proximity to server,
    │       │      no stored secret; ADR-020).  Issues 12 h grant
    │       │      without PIN; logs success=1 attempt for audit.
    │       │
    │       ├── DELETE /api/v1/groups/{id}/members/{cid}/pin
    │       │     (M8 per-client recovery — clears one member's
    │       │      enrollment + grant; re-enrolls on next access)
    │       │
    │       └── POST /api/v1/groups/{id}/grants/reset
    │             (M7 shared-mode bulk drop; emits
    │              'group.pin.grants-reset' event)
    │
    └──▶ DELETE /api/v1/groups/{id}/grant
            (mobile "Lock" button; idempotent)
```

`housekeep_pin_state(db)` is called from the existing `main.py` startup background task — prunes expired `group_pin_grants` and 24 h-old `group_pin_attempts`.

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

### Client consumers (REST polling, not WS — transitional)

Both the desktop slide-over panel and the mobile notifications screen consume notifications via **REST polling** of `/api/v1/notifications` every 5 seconds, not via the WS endpoint. Each client's repository carries an explicit `// TODO(WS):` comment for the eventual migration. The blocker is that mobile + desktop need a **shared `WebSocketClient` wrapper** in `fluxora_core` that handles HMAC-bearer auth the same way the server's `get_current_user_ws` dependency expects (the existing `WebRtcSignalingService` covers signaling but isn't generic). Until that wrapper lands, both clients sit on REST polling.

| Client | File | Pattern |
|--------|------|---------|
| Desktop | `apps/desktop/lib/features/notifications/data/repositories/notifications_repository_impl.dart` | `liveStream()` — `Future.delayed(5s)` loop yielding new IDs not seen by client |
| Mobile (M8) | `apps/mobile/lib/features/notifications/data/repositories/notifications_repository_impl.dart` | Same shape, mirrored from desktop. Both carry `// TODO(WS):` markers. |

When the shared WS wrapper lands, both repos cut over together; the cubit + screen layers don't change because they only consume `Stream<AppNotification>` from `liveStream()`.

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

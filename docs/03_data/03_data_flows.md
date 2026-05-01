# Data Flow Diagrams

> **Category:** Data  
> **Status:** Active - Updated 2026-05-01 (Polar payment webhook flow added; stream-gate group enforcement flow added)

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

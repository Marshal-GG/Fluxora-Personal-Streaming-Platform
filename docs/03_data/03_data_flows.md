# Data Flow Diagrams

> **Category:** Data  
> **Status:** Active - Updated 2026-04-29 (Polar payment webhook flow added)

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

## Event Flows

| Event | Trigger | Action |
|-------|---------|--------|
| `stream.started` | Client begins HLS playback | Create `StreamSession` record |
| `stream.progress` | Client WebSocket heartbeat | Update `progress_sec` |
| `stream.ended` | Client disconnects / stops | Set `ended_at` on session |
| `library.scan_complete` | Scan finishes | Update `last_scanned`; notify panel |
| `client.pair_request` | New client connects | Notify control panel for approval |
| `license.issued` | Polar paid order webhook | Store idempotent license issuance row in `polar_orders` |

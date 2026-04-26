# Data Flow Diagrams

> **Category:** Data  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

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
    
[Flutter Client] ──▶ Stores token securely ──▶ All future requests include token
```

---

## Event Flows

| Event | Trigger | Action |
|-------|---------|--------|
| `stream.started` | Client begins HLS playback | Create `StreamSession` record |
| `stream.progress` | Client WebSocket heartbeat | Update `progress_sec` |
| `stream.ended` | Client disconnects / stops | Set `ended_at` on session |
| `library.scan_complete` | Scan finishes | Update `last_scanned`; notify panel |
| `client.pair_request` | New client connects | Notify control panel for approval |

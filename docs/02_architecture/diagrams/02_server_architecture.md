# 02 — Server Architecture

> Python FastAPI backend at `apps/server/`. Single-process, async, SQLite-backed.

---

## Layer view

```mermaid
graph TB
  classDef router fill:#7c3aed,stroke:#fff,color:#fff
  classDef service fill:#a78bfa,stroke:#000,color:#000
  classDef model fill:#fde68a,stroke:#000,color:#000
  classDef store fill:#1f2937,stroke:#7c3aed,color:#fff
  classDef ext fill:#f59e0b,stroke:#000,color:#000

  Client[Flutter client] -- HTTP/WS --> Routers

  subgraph Routers["routers/ (18 routers)"]
    direction LR
    R1[auth]:::router
    R2[stream]:::router
    R3[library]:::router
    R4[files]:::router
    R5[groups]:::router
    R6[transcode]:::router
    R7[transcoding]:::router
    R8[settings]:::router
    R9[profile]:::router
    R10[notifications]:::router
    R11[activity]:::router
    R12[logs]:::router
    R13[info]:::router
    R14[signal]:::router
    R15[webhook]:::router
    R16[orders]:::router
    R17[ws]:::router
    R18[deps]:::router
  end

  Routers --> Services
  Routers --> Models

  subgraph Services["services/ (25 services)"]
    direction LR
    S1[auth_service]:::service
    S2[ffmpeg_service]:::service
    S3[library_service]:::service
    S4[group_service]:::service
    S5[transcode_service]:::service
    S6[transcoding_service]:::service
    S7[session_router]:::service
    S8[encoder_registry]:::service
    S9[encoder_advisor]:::service
    S10[ffmpeg_capabilities]:::service
    S11[thumbnail_service]:::service
    S12[discovery_service]:::service
    S13[webrtc_service]:::service
    S14[notification_service]:::service
    S15[activity_service]:::service
    S16[log_service]:::service
    S17[license_service]:::service
    S18[webhook_service]:::service
    S19[tmdb_service]:::service
    S20[settings_service]:::service
    S21[profile_service]:::service
    S22[benchmark_service]:::service
    S23[system_stats_service]:::service
    S24[hardware_probe]:::service
    S25[support_bundle_service]:::service
  end

  subgraph Models["models/ (Pydantic)"]
    M1[stream_session]:::model
    M2[media_file]:::model
    M3[client]:::model
    M4[group]:::model
    M5[library]:::model
    M6[settings]:::model
    M7[profile]:::model
    M8[notification]:::model
    M9[activity]:::model
    M10[log_record]:::model
    M11[transcode]:::model
    M12[transcoding]:::model
    M13[order]:::model
  end

  Services --> DB[("database/db.py<br/>SQLite + WAL")]:::store
  S2 --> FFmpeg([FFmpeg subprocess]):::ext
  S5 --> FFmpeg
  S11 --> FFmpeg
  S19 -. HTTPS .-> TMDB([TMDB]):::ext
  S18 -. webhook .-> Polar([Polar]):::ext
  S12 -. mDNS .-> LAN([LAN multicast]):::ext
  S13 -. signalling .-> WebRTC([WebRTC stack]):::ext
```

---

## Request flow — typical authenticated endpoint

```mermaid
sequenceDiagram
  autonumber
  participant C as Client (mobile/desktop)
  participant U as Uvicorn (ASGI)
  participant D as routers/deps.py
  participant R as Router handler
  participant S as Service layer
  participant DB as SQLite
  C->>U: HTTP request<br/>Authorization: Bearer ...
  U->>R: dispatch
  R->>D: Depends(validate_token)
  D->>DB: SELECT FROM clients<br/>WHERE auth_token=HMAC(raw)
  DB-->>D: client row or 401
  D->>DB: UPDATE clients SET last_seen, last_ip
  D-->>R: client_id
  R->>S: business logic call
  S->>DB: queries / writes
  DB-->>S: rows
  S-->>R: domain object
  R-->>C: Pydantic model JSON
```

---

## Streaming-specific subsystem

```mermaid
graph LR
  classDef hot fill:#7c3aed,stroke:#fff,color:#fff
  classDef cool fill:#a78bfa,stroke:#000,color:#000

  StreamReq[POST /stream/start/file_id<br/>?seek_sec=&tonemap=]:::hot
  --> SR[session_router<br/>pick_encoder]:::cool
  SR --> FC[ffmpeg_capabilities<br/>version + flags]:::cool
  SR --> ER[encoder_registry<br/>10 encoders]:::cool
  SR --> FS[ffmpeg_service<br/>build args + spawn]:::hot
  FS --> Decision{Source codec<br/>vs client allowlist}
  Decision -- compatible --> Copy["Stream-copy<br/>-c:v copy<br/>~95% less CPU"]:::cool
  Decision -- needs encode --> Trans["Transcode<br/>cuvid hint + readrate"]:::cool
  Decision -- HDR + tonemap --> Tone["Transcode + zscale Hable"]:::cool
  Copy --> HLS[(HLS playlist<br/>+ segments)]
  Trans --> HLS
  Tone --> HLS
  HLS --> Client[Client GET segments]
```

---

## Background workers

| Worker | Source file | Trigger | What it does |
|---|---|---|---|
| Thumbnail worker | `services/thumbnail_worker.py` | `media_thumbnails` rows where status=pending | FFmpeg / PyMuPDF extract; concurrency=4 |
| Transcode worker | `services/transcode_service.py` | `transcode_jobs` queue rows | Single-worker FIFO; AV1/VP9 → H.264 sidecars |
| TMDB enrichment | `services/library_service.py` | After scan finds an unenriched file | Best-effort title/poster fetch |
| Activity emitter | `services/activity_service.py` | Every mutating router call | Records `activity_events` row |
| Notification fan-out | `services/notification_service.py` | Persistent notif written | WS broadcast to `/ws/notifications` subscribers |
| Event fan-out | `notification_service.broadcast_event` | After library/storage mutations | Ephemeral `{kind:"library_changed"}` over same WS |
| Discovery | `services/discovery_service.py` | App startup | Zeroconf service registration on LAN |
| System stats | `services/system_stats_service.py` | WS `/ws/stats` subscriber | CPU / RAM / network samples |
| Log pubsub | `services/log_service.py` | Every log line written | Fan out to `/ws/logs` |

---

## Hard prohibitions enforced in code

| Rule | Where it's enforced |
|---|---|
| No `print()` — use `logger` | Module-level `logger = logging.getLogger(__name__)` in every file |
| No silent excepts | Every `except` logs + re-raises or handles explicitly |
| Bearer tokens stored as HMAC-SHA256 | `services/auth_service.py` |
| API keys / TMDB key via `BaseSettings` | `config.py` — no magic strings |
| Migrations append-only | `database/migrations/` — never edit past files |
| Parameterised SQL only | All queries use `?` placeholders |
| No PII in logs | `support_bundle_service.py` scrubs before bundling |

See [CLAUDE.md → Hard Prohibitions](../../../CLAUDE.md).

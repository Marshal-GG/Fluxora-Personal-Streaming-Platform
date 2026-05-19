# 01 — System Landscape

> Top-level view of every Fluxora component and how they connect. Start here.

---

## The whole system, one diagram

```mermaid
graph TB
  classDef fluxora fill:#7c3aed,stroke:#fff,color:#fff
  classDef external fill:#f59e0b,stroke:#000,color:#000
  classDef store fill:#1f2937,stroke:#7c3aed,color:#fff
  classDef deprecated fill:#6b7280,stroke:#374151,color:#fff,stroke-dasharray: 4 4

  subgraph UserMachine["User's home machine"]
    Server["Fluxora Server<br/>FastAPI + FFmpeg<br/>(PyInstaller .exe)"]:::fluxora
    SQLite[("SQLite<br/>~/.fluxora/fluxora.db")]:::store
    MediaDisk[("Media files<br/>on disk")]:::store
    ThumbCache[("Thumbnail cache<br/>~/.fluxora/thumbnails")]:::store
    SidecarCache[("Transcode sidecars<br/>(plan 18)")]:::store
    Server --> SQLite
    Server --> MediaDisk
    Server --> ThumbCache
    Server --> SidecarCache
  end

  subgraph UserDevices["User's devices"]
    Mobile["Mobile app<br/>Flutter (Android + iOS)"]:::fluxora
    Desktop["Desktop control panel<br/>Flutter (Win/macOS/Linux)"]:::fluxora
  end

  subgraph Internet["External services"]
    TMDB["TMDB<br/>metadata API"]:::external
    Polar["Polar<br/>webhook + checkout"]:::external
    STUN["STUN/TURN<br/>NAT traversal"]:::external
    Firebase["Firebase<br/>WebRTC signalling<br/>(Phase 3+, optional)"]:::external
    WebLanding["fluxora.marshalx.dev<br/>Next.js static<br/>(CF Pages)"]:::fluxora
  end

  Mobile -- "LAN: HTTP+HLS<br/>(mDNS discover)" --> Server
  Mobile -. "Internet: WebRTC<br/>(STUN/TURN)" .-> Server
  Desktop -- "LAN: HTTP+WS" --> Server

  Server -- "HTTPS metadata fetch" --> TMDB
  Polar -- "POST /webhook/polar<br/>(HMAC sig)" --> Server
  Mobile -. signalling .-> Firebase
  Server -. signalling .-> Firebase
  Mobile -. relay .-> STUN
  Server -. relay .-> STUN
```

---

## Connection paths — LAN vs Internet

```mermaid
flowchart LR
  classDef ok fill:#16a34a,stroke:#000,color:#fff
  classDef fb fill:#f59e0b,stroke:#000,color:#000
  classDef relay fill:#ef4444,stroke:#000,color:#fff

  Start([Client wants to stream]) --> Q1{mDNS finds server<br/>on same LAN?}
  Q1 -- yes --> LAN["Direct LAN HTTP+HLS<br/>fastest, no cloud"]:::ok
  Q1 -- no --> Q2{WebRTC P2P<br/>handshake succeeds?}
  Q2 -- yes --> P2P["WebRTC P2P stream<br/>good"]:::fb
  Q2 -- no --> Relay["TURN relay stream<br/>fallback, slowest"]:::relay
  LAN --> Monitor[Monitor path quality]
  P2P --> Monitor
  Relay --> Monitor
  Monitor -. degrades .-> Q1
```

---

## Data ownership

| Where it lives | What it holds |
|---|---|
| **`~/.fluxora/fluxora.db`** (server) | All library metadata, clients, sessions, settings, notifications, activity, transcode jobs, group access rules |
| **`~/.fluxora/thumbnails/`** (server) | Generated JPEG thumbnails for video / image / audio-art / PDF |
| **`~/.fluxora/transcoded/`** (server, opt-in path) | AV1/VP9 → H.264 sidecar files (plan 18) |
| **flutter_secure_storage** (each client) | Bearer token only — no library data |
| **No cloud** | The library catalogue. Ever. |
| **Firebase** (Phase 3+, optional) | Only WebRTC signalling messages — ephemeral, no media bytes |

---

## What is *out of scope*

- Multi-tenant cloud sync — v2 deferred (see [user-memory `project_v2_deferred`](../../../../../../../C:/Users/marsh/.claude/projects/f--AI-Models-Projects-Fluxora/memory/project_v2_deferred.md))
- Browser-based streaming client
- Subtitle / caption rendering (Phase 3+)
- AI recommendations (Phase 5)

See [system_overview.md](../01_system_overview.md) for prose-level architecture detail.

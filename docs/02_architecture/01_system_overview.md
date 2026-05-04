# System Architecture Overview

> **Category:** Architecture  
> **Status:** Active - Updated 2026-05-01 (Client Groups capability added)

---

## Architecture Style

**Hybrid Client-Server with P2P Fallback**

- A PC runs a persistent **FastAPI server** (the "Fluxora Server")
- **Flutter clients** (mobile + desktop) connect to it
- Connection path is dynamically selected: **LAN (direct)** or **Internet (WebRTC relay)**

---

## High-Level Diagram

```
┌────────────────────────────────────────────────────────────┐
│                      FLUXORA SYSTEM                        │
│                                                            │
│   ┌──────────────────────────────────────────────────┐     │
│   │               PC SERVER (FastAPI + FFmpeg)       │     │
│   │  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │     │
│   │  │ File API │  │ Stream   │  │ Library Mgmt  │  │     │
│   │  │ Browser  │  │ Engine   │  │ (SQLite+TMDB) │  │     │
│   │  └──────────┘  └──────────┘  └───────────────┘  │     │
│   └──────────────────────────────────────────────────┘     │
│                │                     │                     │
│         [LAN / mDNS]          [Internet / WebRTC]          │
│                │                     │                     │
│   ┌────────────┘             ┌───────┘                     │
│   │                          │                             │
│   ▼                          ▼                             │
│ ┌──────────────┐     ┌──────────────────┐                 │
│ │ Flutter      │     │ STUN/TURN Relay  │                 │
│ │ Client       │     │ Server           │                 │
│ │ (Mobile/     │     └──────────────────┘                 │
│ │  Desktop)    │                                           │
│ └──────────────┘                                           │
└────────────────────────────────────────────────────────────┘
```

---

## Core Components

| Component | Role | Technology |
|-----------|------|------------|
| FastAPI Server | Main backend, REST API, streaming engine | Python, FastAPI, Uvicorn |
| FFmpeg Pipeline | Video/audio remux + HLS packaging.  Picks **stream-copy** (`-c:v copy`) for h264 / hevc sources (~95% CPU drop vs. transcode) and full transcode for vp9 / av1 / mpeg4 / etc. — read from `media_files.codec_name` per migration 016, with a lazy ffprobe at stream-start as fallback for un-probed files. For transcode sessions on NVIDIA encoders, injects a cuvid hardware-decoder hint (`-c:v av1_cuvid` etc.) before `-i` via `_NVIDIA_CUVID_BY_CODEC`; auto-retries without the hint when cuvid rejects the source's chroma format. Stream-copy omits `independent_segments` and uses `hls_time=10` to handle long-GOP sources (game captures with 4–10 s GOPs). | FFmpeg |
| SQLite Database | Local metadata, library index, settings | SQLite |
| Zeroconf/mDNS | LAN device discovery and auto-pairing | Zeroconf (Python) |
| WebRTC Module | NAT traversal, P2P internet streaming | WebRTC + STUN/TURN |
| Flutter Client | Cross-platform UI (mobile + desktop) | Flutter/Dart |
| PC Control Panel | Desktop server management UI | Flutter Desktop |
| TMDB Integration | Metadata fetching for media libraries | TMDB REST API |
| Polar Webhook | Paid-order license key issuance | Standard Webhooks + HMAC-SHA256 |
| Client Groups | Bundle paired clients into groups; apply shared library-access and time-window restrictions | SQLite (`groups`, `group_members`, `group_restrictions`); enforced at stream-gate |

---

## Smart Switching Logic

The core innovation — network path selection:

```
Client attempts connection:
  1. Broadcast mDNS query on local network
  2. If server found on LAN → use direct LAN HTTP stream (fast, low latency)
  3. If NOT on same LAN → initiate WebRTC handshake via STUN/TURN
  4. If WebRTC succeeds → P2P internet stream
  5. If P2P fails → relay through TURN server
  6. Monitor path quality; switch if degraded
```

---

## Integration Points

| Integration | Direction | Protocol |
|------------|-----------|---------|
| Flutter Client ↔ FastAPI | Bidirectional | HTTP REST + HLS |
| Server ↔ FFmpeg | Internal | Subprocess / pipe |
| Server ↔ SQLite | Internal | SQLite3 driver |
| Server ↔ TMDB | Outbound | HTTPS REST |
| Client ↔ STUN/TURN | Outbound | WebRTC/UDP |
| Server ↔ mDNS | LAN broadcast | UDP multicast |
| Polar → Server | Inbound | HTTPS POST + Standard Webhooks signature |

---

## Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Backend language | Python + FastAPI | Rapid development, FFmpeg ecosystem, async support |
| Streaming protocol | HLS via FFmpeg, stream-copy when source codec is HLS-compatible | Wide client support; remuxing already-h264/hevc sources avoids the 95 % CPU cost of always-transcoding, while everything else falls through to the configured (HW or SW) encoder. `ActivityCubit` (desktop) polls `/stream/sessions` every 2 s so the Transcoding screen's active-sessions list and per-session progress refresh live. |
| Local discovery | Zeroconf/mDNS | Zero-config, no cloud dependency |
| Internet transport | WebRTC | NAT traversal without port forwarding |
| Client framework | Flutter | Single codebase for mobile + desktop |
| DB | SQLite | Local-first, no server needed, embedded |
| Payment provider | Polar webhook into self-hosted server | Merchant-of-record flow while preserving local license enforcement |
| Clean Architecture | Domain/Data/Presentation | Testable, scalable Flutter structure |

---

## Quality Attributes

| Attribute | Strategy |
|-----------|----------|
| Performance | HLS adaptive bitrate, local LAN path preference, stream-copy remux for h264/hevc sources (no encoder load) |
| Reliability | Automatic path failover (LAN → WebRTC → TURN) |
| Security | E2E encryption (Phase 5), auth tokens |
| Scalability | Multi-user support, permission system |
| Maintainability | Clean Architecture in Flutter, modular FastAPI routes |

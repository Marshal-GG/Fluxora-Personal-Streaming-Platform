# Requirements

> **Category:** Product  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

---

## Functional Requirements

### FR-001 — LAN Discovery
- **Description:** The Flutter client must automatically discover the Fluxora server on the local network without manual IP entry
- **Priority:** High
- **Acceptance Criteria:**
  - Client finds server within 5 seconds on same LAN
  - Works on Android, iOS, Windows, macOS
  - Falls back to manual IP entry if mDNS is blocked

### FR-002 — Internet Streaming via WebRTC
- **Description:** When not on LAN, client must connect via WebRTC (STUN/TURN) for streaming
- **Priority:** High
- **Acceptance Criteria:**
  - Connection established within 10 seconds
  - Falls back to TURN relay if P2P is blocked
  - Video playback starts within 3 seconds of connection

### FR-003 — HLS Adaptive Streaming
- **Description:** Server must transcode files to HLS using FFmpeg and serve to clients
- **Priority:** High
- **Acceptance Criteria:**
  - Supports MP4, MKV, AVI, MOV input formats
  - Produces valid `.m3u8` + `.ts` segments
  - Player loads within 5 seconds

### FR-004 — File Browser
- **Description:** Client can browse the server's file system and initiate streaming of any supported file
- **Priority:** High
- **Acceptance Criteria:**
  - Directory listing with file types and sizes
  - Tap to stream any video/audio/image file
  - Breadcrumb navigation

### FR-005 — Library Management
- **Description:** Server can index media directories and fetch metadata from TMDB
- **Priority:** Medium
- **Acceptance Criteria:**
  - Scan completes in < 60s for 1000 files
  - TMDB metadata correctly matched for > 80% of well-named files
  - Poster images cached locally

### FR-006 — Client Pairing & Auth
- **Description:** Clients must pair with the server (with server approval) before accessing any data
- **Priority:** High
- **Acceptance Criteria:**
  - PC Control Panel receives and can approve/reject pair requests
  - Approved clients receive a persistent auth token
  - Token validated on every request

### FR-007 — PC Control Panel
- **Description:** Flutter Desktop app to manage the server: start/stop, manage libraries and clients, monitor active streams
- **Priority:** Medium
- **Acceptance Criteria:**
  - Shows all active stream sessions with client info
  - Can approve/revoke client pairs
  - Can trigger library scans

### FR-008 — Tier-Based Feature Limits
- **Description:** Feature availability tied to subscription tier
- **Priority:** Medium
- **Acceptance Criteria:**
  - Free: 1 concurrent stream, basic file browser
  - Plus: 3 streams, library + metadata
  - Pro: 10 streams, AI features, hardware encode
  - Ultimate: unlimited

---

## Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-001 | LAN stream latency | < 500ms startup |
| NFR-002 | Internet stream startup | < 3s from connection established |
| NFR-003 | Library scan (1000 files) | < 60s |
| NFR-004 | Server CPU idle usage | < 5% |
| NFR-005 | FFmpeg concurrent streams | Limited by tier; no crash under limit |
| NFR-006 | SQLite reliability | WAL mode, no data loss on crash |
| NFR-007 | Cross-platform support | Android, iOS, Windows, macOS, Linux |
| NFR-008 | Server package size | < 150MB (including FFmpeg) |

---

## Constraints

- PC must always be the server (no peer-to-peer mobile-to-mobile)
- Files remain on user's PC — no cloud upload
- FFmpeg must be available on the server PC
- No internet required for LAN mode

---

## Assumptions

- Users have a reasonably powerful PC (4+ cores, 8GB+ RAM)
- FFmpeg installed and accessible in system PATH, or bundled
- TMDB API free tier is sufficient for metadata
- Public STUN servers (Google) are accessible to users

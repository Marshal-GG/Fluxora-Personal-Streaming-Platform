# User Stories & Epics

> **Category:** Product  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

---

## Epic Structure

| Epic | Title | Status |
|------|-------|--------|
| E-01 | Server Setup & Discovery | Planned |
| E-02 | File Streaming (LAN) | Planned |
| E-03 | Internet Streaming (WebRTC) | Planned |
| E-04 | Media Library & Metadata | Planned |
| E-05 | Client Pairing & Auth | Planned |
| E-06 | PC Control Panel | Planned |
| E-07 | Monetization & Tiers | Planned |
| E-08 | AI Features (Pro) | Future |

---

## E-01 — Server Setup & Discovery

### US-001 — Auto-discover server on LAN
> **As a** mobile user, **I want to** open the app and automatically find my home server, **so that** I don't have to manually enter an IP address.
- **Criteria:** Server appears in < 5s on same LAN; shows server name
- **Points:** 5 | **Priority:** Must-have

### US-002 — Manual server entry
> **As a** user, **I want to** manually enter a server IP/hostname, **so that** I can connect when mDNS is unavailable.
- **Criteria:** IP + port entry accepted; connection tested with feedback
- **Points:** 2 | **Priority:** Should-have

### US-003 — Server broadcast on startup
> **As a** server admin, **I want** the server to automatically start broadcasting on the LAN when it launches, **so that** clients can discover it immediately.
- **Criteria:** mDNS broadcast within 2s of server start; stops when server stops
- **Points:** 3 | **Priority:** Must-have

---

## E-02 — File Streaming (LAN)

### US-004 — Browse server files
> **As a** user, **I want to** browse the file system on my server, **so that** I can find any file to stream.
- **Criteria:** Directory listing, breadcrumbs, file size/type shown
- **Points:** 5 | **Priority:** Must-have

### US-005 — Stream a video file
> **As a** user, **I want to** tap a video file and have it play immediately, **so that** I can watch my content from my phone.
- **Criteria:** HLS stream starts within 5s; play/pause/seek work; fullscreen supported
- **Points:** 8 | **Priority:** Must-have

### US-006 — Resume playback
> **As a** user, **I want** the app to remember where I stopped watching, **so that** I can resume from the same position.
- **Criteria:** Progress saved on server; resume prompt shown on next open
- **Points:** 3 | **Priority:** Should-have

---

## E-03 — Internet Streaming (WebRTC)

### US-007 — Stream over internet
> **As a** user, **I want to** stream files from my home server when I'm away, **so that** I have access to my media anywhere.
- **Criteria:** WebRTC connection established; video plays within 3s; quality adapts to bandwidth
- **Points:** 13 | **Priority:** Must-have

### US-008 — Automatic path selection
> **As a** user, **I want** the app to automatically use the fastest path (LAN or internet), **so that** I always get the best quality without manual switching.
- **Criteria:** LAN preferred; internet fallback on no LAN; transparent to user
- **Points:** 8 | **Priority:** Must-have

---

## E-04 — Media Library & Metadata

### US-009 — Browse movie library
> **As a** user, **I want to** see my movies in a grid with posters and descriptions, **so that** browsing feels like Netflix/Plex.
- **Criteria:** TMDB metadata shown; poster images displayed; filter by genre
- **Points:** 8 | **Priority:** Should-have

### US-010 — Trigger library scan
> **As a** server admin, **I want to** trigger a library re-scan from the control panel, **so that** newly added files appear in the library.
- **Criteria:** Scan starts within 1s of request; progress shown; completion notified
- **Points:** 5 | **Priority:** Must-have

---

## E-05 — Client Pairing & Auth

### US-011 — Pair client device
> **As a** user, **I want to** pair my phone with the server once, **so that** I don't have to re-authenticate on every use.
- **Criteria:** Pair request sent; control panel shows request; approval grants token; token persists
- **Points:** 8 | **Priority:** Must-have

### US-012 — Revoke client access
> **As a** server admin, **I want to** remove a client device's access, **so that** I can control who can stream from my server.
- **Criteria:** Revoke from control panel; client token invalidated immediately
- **Points:** 3 | **Priority:** Must-have

---

## E-06 — PC Control Panel

### US-013 — Monitor active streams
> **As a** server admin, **I want to** see all active streaming sessions in real time, **so that** I know who is streaming what.
- **Criteria:** Client name, file name, connection type, duration shown; updates live
- **Points:** 5 | **Priority:** Should-have

### US-014 — Manage server settings
> **As a** server admin, **I want to** configure server settings (name, concurrency, transcoding), **so that** I can tune performance.
- **Criteria:** All settings saved to SQLite; changes take effect without restart
- **Points:** 3 | **Priority:** Should-have

---

## E-07 — Monetization

### US-015 — Free tier stream limit
> **As a** free user, **I want to** understand stream limits, **so that** I can decide whether to upgrade.
- **Criteria:** Upgrade prompt shown when limit hit; tier info visible in settings
- **Points:** 3 | **Priority:** Should-have

# Architecture Decision Records (ADR)

> **Category:** Planning  
> **Status:** Active — Sourced from Planning Session (2026-04-27)

---

### ADR-001 — Python + FastAPI as Backend
- **Date:** 2026-04-27
- **Status:** Accepted
- **Context:** Need a backend to serve files, manage FFmpeg subprocesses, and handle WebRTC signaling
- **Decision:** Python 3.11 + FastAPI with Uvicorn
- **Consequences:** Strong FFmpeg ecosystem, async support, fast to develop; not ideal for CPU-bound tasks at very high scale (acceptable for single-server home use)

---

### ADR-002 — SQLite as Local Database
- **Date:** 2026-04-27
- **Status:** Accepted
- **Context:** Need a database for metadata, sessions, settings. Must work without external server installation.
- **Decision:** SQLite with WAL mode + `aiosqlite` for async
- **Consequences:** Zero-config, local-first, fully embedded; WAL mode handles concurrent reads well; may need PostgreSQL migration if multi-user scale becomes a requirement

---

### ADR-003 — HLS via FFmpeg for Streaming
- **Date:** 2026-04-27
- **Status:** Accepted
- **Context:** Need a streaming protocol that works on all Flutter target platforms with wide codec support
- **Decision:** FFmpeg → HLS (`.m3u8` + `.ts`) served over HTTP
- **Consequences:** Excellent client compatibility; adaptive quality possible; CPU-intensive on weak hardware; hardware encoding (NVENC) planned for Phase 5

---

### ADR-004 — Zeroconf/mDNS for LAN Discovery
- **Date:** 2026-04-27
- **Status:** Accepted
- **Context:** LAN auto-discovery needed with zero configuration for end users
- **Decision:** Python `zeroconf` library on server; Dart `zeroconf` package on client
- **Consequences:** Zero-config pairing on LAN; mDNS can be blocked on some managed networks (fallback: manual IP entry)

---

### ADR-005 — WebRTC for Internet Streaming
- **Date:** 2026-04-27
- **Status:** Accepted
- **Context:** Need internet streaming without requiring port forwarding from the end user
- **Decision:** WebRTC with STUN (ICE) + TURN relay fallback
- **Consequences:** Solves NAT traversal cleanly; complex implementation; `flutter_webrtc` and `aiortc` add significant complexity; isolated in service layer

---

### ADR-006 — Flutter for All Client Surfaces
- **Date:** 2026-04-27
- **Status:** Accepted
- **Context:** Need mobile (Android/iOS) and desktop (PC control panel) clients
- **Decision:** Flutter/Dart for both — single framework, separate apps
- **Consequences:** Code sharing between client and control panel; strong ecosystem; some platform-specific plugins needed (mDNS, WebRTC, foreground services)

---

### ADR-007 — Clean Architecture in Flutter
- **Date:** 2026-04-27
- **Status:** Accepted
- **Context:** App will be feature-rich and long-lived; need testable, scalable structure
- **Decision:** Feature-first Clean Architecture (Domain / Data / Presentation per feature)
- **Consequences:** Clear separation of concerns; slightly more boilerplate vs. simple MVC; enables easy testing of use cases without UI

---

### ADR-008 — Tiered Monetization Model
- **Date:** 2026-04-27
- **Status:** Proposed
- **Context:** Project needs revenue model; hardware and infrastructure have costs
- **Decision:** Free / Plus ($4.99) / Pro ($9.99) / Ultimate ($19.99) tiers, differentiated by stream concurrency and features
- **Consequences:** Free tier drives adoption; upgrade path is natural; license enforcement must be robust server-side

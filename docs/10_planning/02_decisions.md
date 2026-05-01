# Architecture Decision Records (ADR)

> **Category:** Planning  
> **Status:** Active — Sourced from Planning Session (2026-04-27); ADR-013 added 2026-05-01

---

### ADR-013 — Public Routing via Cloudflare Tunnel; Media Plane stays Direct/P2P
- **Date:** 2026-05-01
- **Status:** Accepted
- **Context:** Mobile and desktop clients need a stable public address for the home Fluxora server when off LAN. Self-hosted servers behind NAT have neither static public IPs nor port-forwarding by default. Routing all traffic — including HLS media — through any cloud proxy would burn bandwidth budgets and contradict Fluxora's local-first principle.
- **Decision:** Three-plane routing.
  - **Control plane** (REST + WS): WAN traffic enters via `fluxora-api.marshalx.dev`, served by a Cloudflare Tunnel from the home PC's `cloudflared` daemon. Free, no port-forward, free TLS via Cloudflare. LAN keeps using the discovered local URL.
  - **Signaling plane** (WebRTC negotiation WS): same path as control plane.
  - **Media plane** (HLS, WebRTC media): never tunneled. LAN uses direct HLS; WAN uses WebRTC P2P with STUN/TURN. Server middleware blocks `/api/v1/hls/*` requests that arrive via the tunnel (`CF-Connecting-IP` present) to enforce this.
  - Server supplies its own remote URL via `GET /api/v1/info` so the client binary stays domain-agnostic. cloudflared is system-installed (not bundled) via a desktop wizard. v1 is single-tenant; multi-tenant via Cloudflare for SaaS is scoped for v2.
- **Consequences:**
  - Zero infrastructure cost on Fluxora's side for v1 — no servers to run.
  - Cloudflare can technically inspect request bodies via WAF, but Fluxora disables WAF inspection for the tunnel hostname; bearer tokens and license keys are never logged regardless.
  - Tunnel is a single point of failure — if Cloudflare is down, WAN access fails. Acceptable for v1; multi-region or DDNS fallback considered and rejected (would re-introduce port-forwarding requirement, defeating the purpose).
  - Full plan: [`docs/05_infrastructure/03_public_routing.md`](../05_infrastructure/03_public_routing.md). Domain inventory: [`docs/05_infrastructure/04_domains_and_subdomains.md`](../05_infrastructure/04_domains_and_subdomains.md).

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
- **Status:** Accepted
- **Context:** Project needs revenue model; hardware and infrastructure have costs
- **Decision:** Free / Plus ($4.99) / Pro ($9.99) / Ultimate ($19.99) tiers, differentiated by stream concurrency and features
- **Consequences:** Free tier drives adoption; upgrade path is natural; license enforcement must be robust server-side

---

### ADR-009 — LAN vs WAN Smart Path Selection via Subnet Check
- **Date:** 2026-04-28
- **Status:** Accepted
- **Context:** WebRTC negotiation (SDP + ICE) takes up to 8 seconds and drains mobile battery. On a home LAN the server is reachable over HLS directly with sub-100 ms latency. There is no benefit to WebRTC on LAN.
- **Decision:** Implement `NetworkPathDetector.isLan(serverUrl)` — a pure in-process check that compares the server IP against device IPv4 interfaces using a /24 subnet mask. If LAN: stream HLS directly. If WAN: attempt WebRTC with 8 s timeout, fallback to HLS.
- **Consequences:** Zero battery drain for the common case (home LAN). WAN users get WebRTC P2P. /24 is a pragmatic approximation; edge cases with non-/24 subnets route WAN→WebRTC (safe, not broken). No external network call.

---

### ADR-010 — Transport Badge on Player Screen
- **Date:** 2026-04-28
- **Status:** Accepted
- **Context:** Power users want to know which streaming path is active. Debugging reports are easier with a visible transport indicator.
- **Decision:** Show `_TransportBadge` chip (HLS / WebRTC) in the bottom-right player overlay. Auto-hides after 5 seconds. Not persistent — does not interfere with viewing.
- **Consequences:** Minimal code (single `StatelessWidget`). Auto-dismiss means it doesn't distract regular users. Can be promoted to a permanent Settings toggle later.

---

### ADR-012 — `validate_token_or_local` Auth Mode for Files and Library Endpoints
- **Date:** 2026-05-01
- **Status:** Accepted
- **Context:** The desktop control panel runs on the same machine as the server (`localhost:8080`). It needs to browse files and libraries without going through the mobile client pairing flow. However, mobile clients still need bearer token validation when accessing these endpoints remotely.
- **Decision:** Add a `validate_token_or_local` FastAPI dependency to `routers/deps.py`. If the request originates from a loopback address (`127.0.0.1` or `::1`), auth is skipped and `None` is returned. Otherwise, the standard `validate_token` logic runs.
- **Consequences:** Desktop control panel gets seamless access. Mobile clients are unaffected (they always send a token). Tests that previously asserted `401` on unauthenticated `/files` and `/library` requests are updated to assert `200` with a note that localhost access is intentionally auth-free.

---

### ADR-011 — DB-Driven Tier Concurrency Limits
- **Date:** 2026-04-28
- **Status:** Accepted
- **Context:** Tier enforcement requires `max_concurrent_streams` to reflect the current tier at all times. Hard-coding the limits in `config.py` would diverge from the DB row after a `PATCH /settings` tier change.
- **Decision:** `settings_service.py` maps each tier to its stream limit (`free=1, plus=3, pro=10, ultimate=9999`) and writes `max_concurrent_streams` to `user_settings` on every tier change. The stream router reads the limit from the DB row, not from config.
- **Consequences:** Single source of truth in the DB; `migration_007` back-fills any stale rows; correct concurrency enforced immediately after PATCH without server restart.

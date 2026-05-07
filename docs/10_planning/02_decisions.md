# Architecture Decision Records (ADR)

> **Category:** Planning  
> **Status:** Active — Sourced from Planning Session (2026-04-27); ADR-013 added 2026-05-01; ADR-014/015 added 2026-05-01; ADR-016/017 added 2026-05-03; ADR-018/019/020 added 2026-05-07

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

### ADR-015 — Multi-Group Restrictions Combine via Intersection (Most-Restrictive Wins)
- **Date:** 2026-05-01
- **Status:** **Superseded by ADR-018 (2026-05-07)** — flipped to UNION under the v2 content-spaces redesign.
- **Context:** A client can belong to multiple groups simultaneously (e.g., "Family" and "Kids"), each with its own restriction set. A policy must be chosen for how overlapping restrictions combine.
- **Decision:** `group_service.get_effective_restrictions(client_id)` computes the intersection of all active groups' `allowed_libraries` lists (only libraries present in every group are permitted) and the narrowest overlapping `time_window` (latest start, earliest end). For `bandwidth_cap_mbps` and `max_rating`, the lowest value wins. A client with no group membership has no restrictions applied.
- **Consequences:** The strictest applicable rule always prevails, which is the safe default for parental controls and bandwidth management. Operators must be aware that adding a client to a more-permissive group does not loosen restrictions if a stricter group already applies.
- **Why superseded:** the intersection model surprised operators who expected union ("Kids in Family + Kids should see everything Kids OR Family expose"), and combined with the "no group = no restrictions" v1 default produced two incoherent surfaces ("zero groups = full access; one strict group = subset; two strict groups = even smaller subset"). v2 flips both: a default Public group manufactures a sane baseline, and additional group memberships UNION more access on top.

---

### ADR-014 — Group Restrictions Enforced at Stream-Gate, Not in Transport Layer
- **Date:** 2026-05-01
- **Status:** Accepted (still valid post-v2; the gate moved from `reason_to_deny` to `reason_to_deny_stream` but the architecture rule — enforce in the stream handler, not middleware — is unchanged).
- **Context:** Client group restrictions (library allowlist, time window) could be enforced at the network/transport layer (e.g., middleware) or at the application layer within the stream-start handler.
- **Decision:** Enforcement is a hook inside `routers/stream.py:start_stream`. Before spawning FFmpeg, the handler calls `group_service.reason_to_deny_stream(client_id, library_id=...)` (v2; previously `get_effective_restrictions` + `reason_to_deny`) and returns HTTP 403 with a reason string if denied. `bandwidth_cap_mbps` and `max_rating` are recorded on the session row but are advisory in v1/v2 — not actively enforced in the transport layer yet.
- **Consequences:** The restriction logic is co-located with the stream lifecycle, making it easy to test in isolation and extend. Middleware-level enforcement (e.g., rate-limiting by cap) can be layered on top in a later phase without changing the gate logic. v2 additionally extends list endpoints (library/files/recent/search/by-id/continue-watching) with the same `get_visible_libraries` filter so visibility and playability stay aligned.

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
- **Context:** The desktop control panel runs on the same machine as the server (`localhost:8000`). It needs to browse files and libraries without going through the mobile client pairing flow. However, mobile clients still need bearer token validation when accessing these endpoints remotely.
- **Decision:** Add a `validate_token_or_local` FastAPI dependency to `routers/deps.py`. If the request originates from a loopback address (`127.0.0.1` or `::1`), auth is skipped and `None` is returned. Otherwise, the standard `validate_token` logic runs.
- **Consequences:** Desktop control panel gets seamless access. Mobile clients are unaffected (they always send a token). Tests that previously asserted `401` on unauthenticated `/files` and `/library` requests are updated to assert `200` with a note that localhost access is intentionally auth-free.

---

### ADR-011 — DB-Driven Tier Concurrency Limits
- **Date:** 2026-04-28
- **Status:** Accepted
- **Context:** Tier enforcement requires `max_concurrent_streams` to reflect the current tier at all times. Hard-coding the limits in `config.py` would diverge from the DB row after a `PATCH /settings` tier change.
- **Decision:** `settings_service.py` maps each tier to its stream limit (`free=1, plus=3, pro=10, ultimate=9999`) and writes `max_concurrent_streams` to `user_settings` on every tier change. The stream router reads the limit from the DB row, not from config.
- **Consequences:** Single source of truth in the DB; `migration_007` back-fills any stale rows; correct concurrency enforced immediately after PATCH without server restart.

---

### ADR-016 — Library Type is Immutable Post-Creation
- **Date:** 2026-05-03
- **Status:** Accepted
- **Context:** The library `PATCH /library/{id}` route lets operators rename a library and change its `root_paths`. Allowing the `type` field (`movies` / `tv` / `music` / `files`) to change too was considered.
- **Decision:** Type is **immutable**. The `UpdateLibraryBody` Pydantic model accepts only `name` and `root_paths`. To switch a library's type, the operator must delete it and recreate.
- **Consequences:** Type-specific metadata already attached to scanned files (movie posters, episode counts, music tags) cannot be silently invalidated by a PATCH. The trade-off is that `delete + recreate` loses scan history — an acceptable cost since type changes are rare and the workflow is unambiguous. UI: the Edit dialog hides the type selector when editing (passes `typeEditable: false`).

---

### ADR-017 — Files on Disk are NEVER Deleted by Fluxora
- **Date:** 2026-05-03
- **Status:** Accepted (Hard Lock — does not change without a follow-up ADR)
- **Context:** When deleting a library or removing files from the index, an operator might reasonably expect the option to also delete the files from disk. Plex famously ships this as an opt-in dialog. The question was whether to follow Plex's pattern or stay strictly read-only on the filesystem.
- **Decision:** **Fluxora never deletes files from disk.** `DELETE /library/{id}` removes only the library entry and its file index from the database. `DELETE /file/{id}` removes only the database row. The server has no `os.remove` / `Path.unlink` / `shutil.rmtree` calls on the library track (verified). The Delete confirm dialog says explicitly: _"This removes only the library entry and its file index from Fluxora. Your files on disk are never deleted by this app."_
- **Consequences:** Operators trust Fluxora as a read-mostly surface over their media. A buggy delete handler can never lose user data. The trade-off is some duplicate-cleanup tooling has to live outside Fluxora — operators use their OS file manager. Defense in depth: the rule is enforced at code (no deletion calls), at UI copy, in [`docs/10_planning/07_library_screen_plan.md`](07_library_screen_plan.md) decision D7, and in this ADR. Reverting requires a fresh ADR.

---

### ADR-018 — Groups are Additive Content-Spaces, Not Subtractive Restrictions
- **Date:** 2026-05-07
- **Status:** Accepted (supersedes ADR-015 intersection rule)
- **Context:** v1 modeled groups as subtractive — a client in zero groups got full access; adding to a group narrowed visibility; multiple groups intersected to the strictest overlap. After the v1 remediation milestones shipped, owner-side review found the model produced three friction points: (1) "no group = full access" was a trap when pairing a new device, (2) intersection semantics surprised operators who expected adding "Family" + "Kids" to expand a kid's view to whatever EITHER group exposed, (3) there was no story for genuinely shared libraries (everyone sees Movies) vs gated content (Adults library should disappear from the Library list, not just deny at play-time).
- **Decision:** Flip the model to additive content-spaces. Every paired client is a member of a mandatory `Public` group manufactured at first-run; that group's `allowed_libraries` is the household-shared baseline. Additional group memberships UNION more libraries on top — adding "Adults" to the operator's tablet adds the Adults library without affecting Movies (Public). The subtractive default ("zero groups = unrestricted") is impossible by construction. The wire format of `group_restrictions.allowed_libraries` is unchanged (JSON array of library ids); only the *interpretation* flips. Migration 025 manufactures Public + back-fills with every existing library so v1 deployments don't lose visibility on the upgrade. The strictly-most-restrictive properties from ADR-015 (`bandwidth_cap_mbps`, `time_window`, `max_rating`) keep min-wins semantics where they apply per-group; multi-group composition is union for *visibility*, intersection for *advisory caps*.
- **Consequences:**
  - Cleaner mental model — "what's in this group's content space?" replaces "what restrictions does this group apply?"
  - Migration is *more permissive* than v1 for clients in groups: Kids who saw only Movies pre-migration will see Movies UNION Public (= TV + everything else if the operator hasn't curated Public yet). Operator audit banner + checklist documented in [`docs/10_planning/13_groups_v2_content_spaces.md`](13_groups_v2_content_spaces.md) §M5.
  - The v1 stream-gate (`get_effective_restrictions` + `reason_to_deny`) is replaced by `get_visible_libraries` (single source of truth consumed by every list endpoint AND the stream-gate via `reason_to_deny_stream`). The `'[]'` JSON empty-array edge case had to be handled with `NULLIF(json_group_array(id), '[]')` in the migration because v1's intersect logic reads `'[]'` as "block everything" — a fresh install with no libraries would 403 every stream-start otherwise. Documented in [`gotchas.md`](../12_guidelines/03_gotchas.md).
  - Public can never be deleted (`is_public = 1` → API returns 400 on delete; UNIQUE partial index enforces the singleton at the schema level).
  - Reverting to v1 semantic requires a fresh ADR + a down-migration that's intentionally not provided. Backups are the operator's recovery path if the flip turns out wrong for their setup.

---

### ADR-019 — PIN-Gated Groups Have a Hybrid Model: Shared (Default) or Per-Client (Opt-In)
- **Date:** 2026-05-07
- **Status:** Accepted
- **Context:** With v2 content-spaces, sensitive libraries (adult content, household-private documents, work files) need a way to stay invisible-until-unlocked rather than visible-but-blocked-at-play. The first cut shipped a single shared PIN per group (M4) — operator sets `8472`, every member uses the same PIN. Owner raised a concern: if a kid watches a parent type the household PIN, the leak is whole-household and forces a rotation that everyone has to memorize again. Two alternative models were considered: (a) per-client enrollment only (each device picks its own PIN on first access), (b) shared as default + per-client as an opt-in toggle.
- **Decision:** Ship the hybrid (b). `groups.pin_model TEXT NOT NULL DEFAULT 'shared' CHECK(pin_model IN ('shared','per-client'))` — shared mode (M4 ship) is the default because it's the lower-friction setup; per-client (M8 ship, migration 026 + `group_member_pins(group_id, client_id, pin_hash, enrolled_at)` ledger) is operator-selectable per group. In per-client mode the operator never sees member PINs; members enroll on first access via `POST /groups/{id}/enroll`; recovery is `DELETE /groups/{id}/members/{cid}/pin` (operator-side, localhost) which clears the enrollment row and forces re-enrollment, NOT a PIN reveal.
- **Consequences:**
  - Compromise blast radius scales with the operator's choice. Shared = whole household on PIN leak, force-rotate household. Per-client = one device, force-rotate that device only.
  - Per-client adds enrollment friction (each device must `/enroll` before its first `/enter`); the mobile UI distinguishes via the `enrollment_required` field on `/grant-status`. Worth it for sensitive content; overkill for "everyone in the house knows this PIN" cases.
  - Mode-switch semantics are documented and tested: shared → per-client clears `pin_hash` + keeps existing grants (members aren't kicked off mid-session; they re-enroll on grant expiry); per-client → shared requires a new shared `pin` in the same call (otherwise the group ends up gated with no enterable secret), drops all `group_member_pins` rows. Server raises `ValueError` for the no-PIN case so the desktop CP can surface it as a 400 + amber banner before save.
  - `change_member_pin` charges wrong-old-PIN attempts against the same brute-force ledger as `/enter` so the change endpoint can't be a brute-force bypass. Same 5-fails-in-60s rate limit per (client, group) tuple.
  - PIN format: 4-8 numeric digits, server-authoritative obvious-PIN blocklist (`0000`, `1234`, …, `2580` etc). HMAC-SHA256 with `settings.pin_hmac_key` (re-uses the bearer-token HMAC key + rotation discipline). Plaintext PINs never persisted.

---

### ADR-020 — Master Override is Localhost-Only with No Stored Secret
- **Date:** 2026-05-07
- **Status:** Accepted
- **Context:** Any access-control system needs a recovery path. With PIN-gated groups, the obvious failure modes are (a) operator forgets the household PIN, (b) member's device locked out by failed-attempt rate limiter, (c) operator distributed PIN to a kid by accident and wants to revoke without rotating. Three designs were considered: (1) localhost-only override endpoint with no credential, (2) operator-set recovery passphrase required by override + localhost, (3) no override — force operator to `sqlite3 fluxora.db` + `UPDATE groups SET pin_hash = NULL`.
- **Decision:** Ship (1). `POST /api/v1/groups/{id}/master-override?client_id=` is gated by `require_local_caller` only — no PIN body, no recovery passphrase. Issues a 12 h grant on the target client, logs an `attempts` row with `success=1` for audit, doesn't reveal or modify the underlying PIN.
- **Consequences:**
  - There is no master credential to leak. Ever. The auth boundary is "is the caller running on the server's loopback interface?" — same trust boundary as the SQLite database itself (an attacker with localhost access can already `sqlite3 fluxora.db` to bypass everything; the override endpoint just gives the desktop CP a clean recovery action without dropping to a SQL CLI).
  - Adding a recovery passphrase (option 2) was explicitly rejected: it would create a second secret to protect, with no improvement to the threat model (an attacker who reaches loopback already has DB write access). The passphrase would be operator self-harm theater.
  - For compliance-sensitive content where even localhost trust is too broad, the legitimate escalation is OS-level (full-disk encryption + locked screen), not a server-level credential layer. Documented in [`gotchas.md`](../12_guidelines/03_gotchas.md) + the API contract.
  - Override is documented to log every use to `group_pin_attempts` with `success=1` so the operator's audit feed shows the bypass; future Tier-2 work surfaces this in the desktop activity feed (`docs/10_planning/13_groups_v2_content_spaces.md` §M7).

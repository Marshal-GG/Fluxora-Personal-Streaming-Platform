# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_05.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 04)
**Archived:** 2026-05-02
**Contents:** Public-routing v1 close-out (Phases 1–5) · Dart 3.9 floor bump · M0 desktop-redesign backend chunks §7.5–§7.7 · M1 Foundation tokens + primitives + brand widgets · Web landing page redesign + SEO push · Doc sweeps after each.

* **Public routing v1 (Phases 1–5):** Cloudflare Tunnel topology live (`fluxora-api.marshalx.dev`); `RealIPMiddleware`, `HLSBlockOverTunnelMiddleware`, `/healthz`, `remote_url` on `/info`, dual-base `ApiClient` (LAN + remote routing via `NetworkPathDetector`), mobile pairing persists `remote_url`, desktop Dashboard "Remote: on/off" pill + Settings Remote Access section with on-demand `/healthz` probe. Phase 6 hardening (TURN, Cloudflare Access, WAF, tunnel-health alerts) folded into operator-driven manual tasks.
* **Dart 3.9 floor bump:** SDK floor `>=3.8.0` → `>=3.9.0` in all three pubspecs; CI Flutter pinned 3.32 → 3.41.3; dropped `json_annotation`, `json_serializable`, `build_runner`, `go_router` ceilings. `.devcontainer/Dockerfile` updated.
* **M0 backend chunks §7.5–§7.7:** library storage breakdown (`/library/storage-breakdown`), live system stats (`/info/stats` REST + `/ws/stats`), restart/stop endpoints (`/info/restart`, `/info/stop`).
* **Desktop redesign M1 Foundation:** v2 design tokens (`bgRoot=#08061A`, `primary=#A855F7`, glassmorphic surfaces, 7-pill semantics) + 11 primitive widgets in `apps/desktop/lib/shared/widgets/` + brand widgets (FluxoraMark, FluxoraWordmark, BrandLoader, EmptyState) in `fluxora_core` + 4 animated SMIL SVGs + hi-fi logo PNGs. `/showcase` route renders every primitive. `flutter_svg 2.2.4` added.
* **M2 Shell:** redesigned 232px `flux_sidebar.dart` (logo + 9 nav items + System Status block + Upgrade card + user footer), 28px `flux_status_bar.dart` strip, new routes (`/dashboard`, `/library`, `/clients`, `/groups`, `/activity`, `/transcoding`, `/logs`, `/settings`, `/subscription`, `/profile`, `/help`), `SystemStatsCubit` consuming `/ws/stats`.
* **Web landing redesign:** full v2 violet brand on `apps/web_landing/`; 6 new components (PopularMovies, LibraryTiles, TierComparison, FAQ, AboutStrip, FinalCta); 7 modified (Navbar, Hero, Features, HowItWorks, Pricing, Platforms, Footer); SEO push (JSON-LD `Organization` + `WebSite` + `SoftwareApplication` + `FAQPage`, OpenGraph, Twitter card, robots.ts + sitemap.ts + manifest.json). Production build green; 7 routes prerendered for Cloudflare Pages.

**Next Immediate Steps:**
1. **M0 backend §7.1–§7.4 + §7.8–§7.11** — six remaining chunks (groups, profile, notifications, activity, transcoding-status, logs-structured, settings-extension, orders-pagination).
2. **Desktop redesign M3 Dashboard** — pixel-verified Dashboard with live-tick wiring, sparkline, donut.
3. **Operator tasks** for Phase 6 routing hardening (Cloudflare Access on `/orders` + `/info/logs`, WAF rules, tunnel-health alerts, TURN evaluation) — track in `docs/10_planning/04_manual_tasks.md`.

---

## Entry Template

```
---
## [YYYY-MM-DD] — Brief title
**Phase:** Phase N (description)
**Status:** Complete | Partial | Blocked

### What Was Done
- bullet list

### Files Created / Modified
| Action | Path |
|--------|------|
| Created | path |
| Modified | path |

### Docs Updated
- list

### Decisions Made
- list

### Blockers / Open Issues
- list

### Next Agent Should
1. step
2. step

### Hard Rules Checklist
- [x] No `git commit` / `git push` without explicit per-action OK
- [x] No agent branding anywhere
- [x] No `print()` / `debugPrint()` introduced
- [x] No exceptions swallowed
- [x] No secrets / hardcoded paths added
- [x] All new third-party deps version-checked
---
```

---

## [2026-05-02] — M0 backend close-out (§7.1–§7.4, §7.8–§7.11) + URL inventory
**Phase:** Phase 5 — Desktop redesign M0 (backend prerequisites)
**Status:** Complete — M0 backend milestone fully shipped; only desktop UI work remains for the redesign.

### What Was Done

Eight M0 chunks shipped end-to-end (code + tests + docs). Server suite **149 → 240 passing**. Migrations **001–010 → 001–015**. Routers added: `groups`, `profile`, `notifications`, `activity`, `transcoding`, `logs`. New URL inventory doc.

#### §7.1 Client groups + stream-gate restriction enforcement (commit `44f9948`)
- Migration 011: 3 tables (`groups`, `group_members`, `group_restrictions`) + cascading FKs + `idx_group_members_client`.
- 8 endpoints under `/api/v1/groups/`. GETs allow LAN-with-token; mutations are localhost-only.
- `services/group_service.py` — CRUD + members + `get_effective_restrictions()` (intersects across every active group: allowed-libraries → set intersection, time-windows → AND-combined, bandwidth → min, rating → advisory).
- Stream-gate hook in `routers/stream.py:start_stream` calls `reason_to_deny(restrictions, library_id, now)` before the tier check; 403s on library-not-allowed or outside-time-window. Bandwidth and rating advisory in v1.
- 16 tests in `tests/test_groups.py`.

#### §7.2 Operator profile (commit `4026f3c`)
- Migration 012: 5 nullable columns on `user_settings` (display_name, email, avatar_path, profile_created_at, last_login_at).
- `GET /PATCH /api/v1/profile` — localhost only.
- `avatar_letter` computed server-side: first non-whitespace of display_name, else first char of email local-part, else `'F'`.
- `update_profile` semantics: empty string clears, None preserves.
- POST /password and POST /avatar deferred (Fluxora has no operator-password concept; multipart deferred).
- 9 tests in `tests/test_profile.py`.

#### §7.3 Notifications (commits `f742b3d` + `72662b2`)
- Migration 013: `notifications` table (type/category CHECKs, read_at/dismissed_at, idx_notifications_unread).
- 4 REST endpoints under `/api/v1/notifications/` + WS route `/api/v1/ws/notifications`.
- In-process pub/sub (`subscribe()`/`unsubscribe()`/`broadcast()`) — slow consumers drop frames, 100-frame queue cap.
- 4 emitter integrations wired with try/except logging-only (so notification-write never breaks underlying flow): auth.create_pair_request → `client/info`; license.emit_license_expiry_warnings (called from main.py lifespan, 1-day cooldown de-dupe) → `license/error|warning`; stream.start_stream FFmpeg-fail → `transcode/error`; library.get_storage_breakdown >90% → `storage/warning`.
- 12 tests in `tests/test_notifications.py`.

#### §7.4 Activity event log (commit `958ce20`)
- Migration 014: `activity_events` table + 2 indexes (created DESC, type+created DESC).
- `GET /api/v1/activity?limit=&since=&type=` — token or localhost. type is a prefix (`stream.` matches start + end).
- 6 producer call sites wired: stream.start_stream → `stream.start`; stream.stop_stream → `stream.end`; auth.create_pair_request → `client.pair`; auth.approve_client → `client.approve`; auth.reject_client → `client.reject`; library.scan_library → `library.scan` (only when added > 0).
- All emitters try/except logging-only.
- 12 tests in `tests/test_activity.py`.

#### §7.8 Transcoding status (commit `7bd85d5`)
- `GET /api/v1/transcoding/status` — localhost only. Returns active_encoder, available_encoders (intersection of known × `ffmpeg -encoders`), encoder_loads (per-encoder active sessions + GPU probe for active encoder), active_sessions (joined with media_files + clients + clamped progress).
- `_detect_available_encoders()` runs `ffmpeg -encoders` once per process, caches.
- `_probe_nvidia()` — best-effort `nvidia-smi --query-gpu=utilization.gpu,memory.used`. Returns (None, None) on any failure (binary missing / timeout / parse fail). 1.5s timeout. QSV/VAAPI probes skipped — too distro-specific.
- 6 tests in `tests/test_transcoding.py`.

#### §7.9 Structured /logs + WS live tail (commit `76ca854`)
- File handler in `main.py` switched to JSON-line format (python-json-logger). Console formatter unchanged in dev; unchanged in prod (was already JSON).
- `GET /api/v1/logs?level=&source=&since=&until=&q=&limit=&cursor=` — localhost only. Returns `{items, next_cursor}`. limit 1..1000 default 200; source is prefix; q is case-insensitive.
- WS `/api/v1/ws/logs` — frame format `{"type":"log","data":{ts,level,source,message}}`.
- `BroadcastHandler` attached at startup fans every record out to subscribed asyncio queues.
- Legacy `/api/v1/info/logs` stays — DEPRECATED.
- 15 tests in `tests/test_logs.py`.

#### §7.10 Settings extension (commit `5438a33`)
- Migration 015: 18 ALTER COLUMN on `user_settings` (skipped `max_concurrent_streams` — already in 001). General (8) / Network (4) / Streaming (2) / Security (2) / Advanced (2). `theme_accent` nullable / no default — locked brand to violet by Decision #4 of redesign plan, kept as forward-compat.
- Models extended with all 18 fields. `Literal[]` guards on `default_library_view`, `preferred_mode`, `default_quality`. Bounds on `session_timeout_minutes` (1..1440) and `ai_segment_duration_seconds`.
- `update_settings` refactored to dynamic SET-list (only kwargs explicitly passed touch the DB). Tier→`max_concurrent_streams` side-effect preserved.
- Router PATCH does `**body.model_dump(exclude_none=True)` so adding fields requires no handler change.
- 16 tests in `tests/test_settings_extended.py`.

#### §7.11 Orders pagination + Polar customer-portal URL (commit `823d6a8`)
- `GET /api/v1/orders?limit=&cursor=` — limit 1..200 default 20, cursor 0-based row offset. Response gains `total_all` + `next_cursor`.
- `GET /api/v1/orders/portal-url` — localhost only. Returns `{"url": <FLUXORA_POLAR_PORTAL_URL>}` or 404 when env unset. Polar authorises portal session via magic-link email — no per-customer token.
- New config: `polar_portal_url` (env: `FLUXORA_POLAR_PORTAL_URL`).
- 5 tests added to `tests/test_orders.py`.

#### Doc sweeps (commits `93ec4aa`, `6a13a50`, `0654f95`)
- Three documentation sync commits — paired feature commits with their data-models / schema / API-contracts / backend-arch / component-arch / public-routing / security / data-flows / roadmap / folder-structure / CLAUDE.md / README.md updates.
- **New canonical URL inventory** at `docs/05_infrastructure/02_url_inventory.md` (created this session): 6 sections covering every server REST endpoint (48), all WS routes (5), hosted public URLs (5), third-party URLs we depend on (8), future / TBD URLs (10) with trigger conditions, and cross-references.

#### Sub-agent leverage
~6 Sonnet 4.6 sub-agents handled the doc sweeps + the §7.10 settings extension implementation + the §7.4 activity emitters + tests. Main thread retained schema design, service interface design, integration-point identification, subprocess mocking (transcoding tests), and the bug-fix in §7.3 lifespan license-key query (Sonnet had treated `user_settings` as key/value when it's actually singleton). Saved feedback memory tightening the delegation rule: "quality first, delegation second".

### Files Created / Modified

**Server — code (new):**
| Action | Path |
|--------|------|
| Created | `apps/server/database/migrations/011_groups.sql`, `012_profile_fields.sql`, `013_notifications.sql`, `014_activity_events.sql`, `015_extended_settings.sql` |
| Created | `apps/server/models/group.py`, `profile.py`, `notification.py`, `activity.py`, `transcoding.py`, `log_record.py` |
| Created | `apps/server/services/group_service.py`, `profile_service.py`, `notification_service.py`, `activity_service.py`, `transcoding_service.py`, `log_service.py` |
| Created | `apps/server/routers/groups.py`, `profile.py`, `notifications.py`, `activity.py`, `transcoding.py`, `logs.py` |
| Created | `apps/server/tests/test_groups.py` (16), `test_profile.py` (9), `test_notifications.py` (12), `test_activity.py` (12), `test_transcoding.py` (6), `test_logs.py` (15), `test_settings_extended.py` (16) |

**Server — code (modified):**
| Action | Path |
|--------|------|
| Modified | `apps/server/main.py` — registered 6 new routers; `_setup_logging` attaches `BroadcastHandler`; lifespan step 8a calls `emit_license_expiry_warnings`; file handler swapped to `json` formatter |
| Modified | `apps/server/config.py` — `polar_portal_url` |
| Modified | `apps/server/routers/stream.py` — group-restriction gate hook + transcode-fail notification + stream.start/stream.end activity emitters |
| Modified | `apps/server/routers/orders.py` — pagination + portal-url endpoint |
| Modified | `apps/server/routers/settings.py` — dynamic field-list update via `**body.model_dump(exclude_none=True)`; `_to_response` rebuilt as field-driven dict comprehension |
| Modified | `apps/server/routers/ws.py` — `/notifications` and `/logs` WS routes |
| Modified | `apps/server/services/auth_service.py` — pair-request notification + 3 client.* activity emitters |
| Modified | `apps/server/services/library_service.py` — storage-warning notification + library.scan activity emitter |
| Modified | `apps/server/services/license_service.py` — `emit_license_expiry_warnings()` |
| Modified | `apps/server/services/settings_service.py` — refactored to dynamic SET; `_defaults` covers all 18 new columns |
| Modified | `apps/server/models/settings.py` — 18 new fields; `Literal[]` guards |
| Modified | `apps/server/models/order.py` — `total_all`, `next_cursor`, `PortalUrlResponse` |
| Modified | `apps/server/tests/test_orders.py` — 5 new pagination + portal-url tests |

### Docs Updated

| Action | Path |
|--------|------|
| Created | `docs/05_infrastructure/02_url_inventory.md` (new canonical URL reference) |
| Modified | `docs/03_data/01_data_models.md` — Group, GroupMember, GroupRestrictions, Notification, ActivityEvent, LogRecord; 18 new UserSettings columns; 3 new enums |
| Modified | `docs/03_data/02_database_schema.md` — migrations 011–015, 5 new tables / 18 columns + indexes |
| Modified | `docs/03_data/03_data_flows.md` — Stream-Gate Group Enforcement (Flow 6), Notification Fan-out (Flow 7), Activity Recording (Flow 8), Log Pipeline (Flow 9) |
| Modified | `docs/04_api/01_api_contracts.md` — 8 group + 2 profile + 4 notification REST + 1 notification WS + 1 activity + 1 transcoding-status + 1 logs REST + 1 logs WS + 1 portal-url + paginated orders + 18 PATCH /settings fields. `/info/logs` marked DEPRECATED |
| Modified | `docs/05_infrastructure/03_public_routing.md` — routing matrix updated for every new endpoint |
| Modified | `docs/06_security/01_security.md` — auth matrix rows for every new endpoint; ADR-014 + ADR-015 referenced; auth-relevant settings (`enable_pairing_required`, `session_timeout_minutes`) documented |
| Modified | `docs/02_architecture/03_component_architecture.md` — Group / Profile / Notification / Activity / Transcoding / Log service blocks |
| Modified | `docs/02_architecture/01_system_overview.md` — Client Groups capability |
| Modified | `docs/09_backend/01_backend_architecture.md` — full project tree + service map updates; test count 120 → 240; logging strategy section updated for JSON-line file format |
| Modified | `docs/10_planning/01_roadmap.md` — M0 §7.1/§7.2/§7.3/§7.4/§7.8/§7.9/§7.10/§7.11 marked done; M0 milestone closed |
| Modified | `docs/10_planning/02_decisions.md` — ADR-014 (stream-gate enforcement location), ADR-015 (multi-group restriction intersection) |
| Modified | `docs/00_overview/folder_structure.md` — every new file added to `apps/server/` tree |
| Modified | `docs/00_overview/README.md` — Quick Link to URL inventory |
| Modified | `CLAUDE.md` — Current Status server line bumped 149 → 240 tests, 001–010 → 001–015 migrations, 6 new routers / 6 new services listed; `polar_portal_url` env var noted |
| Modified | `README.md` — FastAPI server status row similarly bumped; new feature list |

### Commits This Session
- `44f9948` feat(server): client groups + stream-gate restriction enforcement
- `4026f3c` feat(server): operator profile endpoints
- `93ec4aa` docs: sync to client groups + operator profile (M0 §7.1 + §7.2)
- `f742b3d` feat(server): notification service + REST + WS pubsub
- `72662b2` feat(server): wire notification emitters from auth, license, ffmpeg, library
- `958ce20` feat(server): activity event log + emitter wirings
- `6a13a50` docs: sync to notifications + activity event log (M0 §7.3 + §7.4)
- `7bd85d5` feat(server): transcoding status endpoint with NVIDIA GPU probe
- `76ca854` feat(server): structured /api/v1/logs + WS live tail (JSON-line format)
- `5438a33` feat(server): extend user_settings with 18 operator-tunable fields
- `823d6a8` feat(server): orders pagination + Polar customer portal URL
- `0654f95` docs: M0 close-out — sync §7.8/§7.9/§7.10/§7.11 + URL inventory

### Decisions Made

- **Three-commit pattern per feature pair:** code-only commits keep `git bisect` clean (each commit's tests pass, each commit is self-coherent), then a paired doc-sync commit ships the full doc protocol. Adapted from the existing project history (`c63c5ab`, `56fdae3`).
- **Notification emitters wrap try/except logging-only.** A failed audit row must never break the underlying flow (pair, transcode, scan, license-validate). Same rule applies to activity emitters.
- **Notification pubsub is in-process only.** Single-server install — Redis/NATS adds operational weight not worth paying. A clustered deployment would need real pubsub.
- **Group restrictions intersect across active groups.** Most-restrictive wins on Booleans/lists/numbers; advisory on max_rating (no rating column on `media_files` yet).
- **Bandwidth cap and max-rating recorded but advisory in v1.** FFmpeg-side throttling and rating metadata are out of scope; columns persist for forward-compat.
- **Operator-password concept rejected.** Single-owner localhost admin model has no login; POST /password from the redesign plan deferred indefinitely.
- **Activity feed is its own log, not derived from notifications.** Notifications are user-actionable alerts; activity is the audit trail of everything the server did. Different lifecycles (notifications dismiss; activity is append-only).
- **Log file format switched to JSON-line.** Enables structured filtering without a parsing layer per query. Legacy `/info/logs` deprecated rather than removed — backwards-compat for v1.
- **NVIDIA-only GPU probe in §7.8.** QSV (`intel_gpu_top`) and VAAPI (`radeontop`) probes vary too much by distro; deferred until a user reports they need them.
- **Settings PATCH refactor to dynamic SET-list.** Going from 7 explicit kwargs to 25 (with §7.10's 18 additions) made the static-kwarg approach unwieldy. Now adding a column requires only a model field — no service or router change.
- **Polar portal URL is a configured landing page, not an SDK call.** Polar customer portal authorises sessions via magic-link email; no per-customer token to encode. `FLUXORA_POLAR_PORTAL_URL` config is sufficient.
- **URL inventory is a new canonical doc.** `04_domains_and_subdomains.md` covers hostnames, `03_public_routing.md` covers Cloudflare topology, `01_api_contracts.md` covers contracts — but no doc enumerates every URL surface (REST + WS + third-party + future TBDs) in one place. New `02_url_inventory.md` fills that gap.

### Issues Discovered / Reported to User

- **`legacy /info/logs` lacks `require_local_caller`** — pre-existing condition, not introduced this session. The endpoint returns the raw log file contents to any caller (token or not). Marked DEPRECATED in this session's doc updates and the new `/api/v1/logs` is correctly localhost-only. Recommend adding `require_local_caller` to the legacy endpoint as a one-line follow-up before the public URL is announced externally.
- **§7.3 lifespan license-key query bug (caught and fixed):** Sonnet sub-agent had emitted `SELECT value FROM user_settings WHERE key = 'license_key'` — but `user_settings` is a singleton with `license_key` as a column, not a key/value table. Fixed in main thread before commit. Documents the importance of the "quality first, delegation second" review pattern.
- **`test_endpoint_since_filter` URL-encoding bug:** `+` in the timezone offset was being decoded as a space when passed via `f"...?since={ts}"`. Fixed by switching to httpx `params=` which URL-encodes properly. Saved as a gotcha; pattern is "always use `params=` for query params containing `+` or other reserved chars".
- **Date-boundary flake in `test_stream_blocked_outside_time_window`:** my service's `_in_window` was falling back to all-week when `days=[]` because `or` truthiness substituted the empty list. Fixed by checking explicitly `is not None`.

### Blockers / Open Issues

- **M0 backend complete but desktop UI not yet consuming it.** All 11 chunks shipped server-side; the redesigned Settings / Activity / Logs / Transcoding / Subscription / Notifications screens still need to wire up to these APIs as part of M3+ desktop work.
- **`FLUXORA_POLAR_PORTAL_URL` unset by default** — `/orders/portal-url` returns 404 until configured. Tracked in `docs/10_planning/04_manual_tasks.md` as an operator follow-up.
- **`_in_window` could improve.** Time-window comparison is hour-precision, not minute. Fine for v1 (operator gates streams to "evenings only") but if a use case needs `start_h=18.5`, the column type and parser need to change.
- **§7.4 activity-feed surface area is small in v1.** Covers stream + client + library only; doesn't include `file.upload` or `settings.change` events from the redesign plan. Easy to extend — pattern is established.
- **Legacy `/info/logs` should grow `require_local_caller`** before the public URL is announced. Currently any tunneled caller could fetch the raw log file. Tracked here.
- **Test runtime is climbing.** 240 tests in 28–35s on Windows; not yet a problem but the SQLite-backed `test_db` fixture is the bottleneck. If we cross 400 tests we should evaluate parallel pytest-xdist.

### Next Agent Should

1. **Add `require_local_caller` to legacy `/info/logs`** — one-line patch, zero behavioural risk for the desktop (it already only calls from localhost), closes a real attack surface before the public URL is announced.
2. **Resume desktop redesign M3 — Dashboard.** All M0 backend dependencies are now in place. Pixel-verify the Dashboard against `docs/11_design/desktop_prototype/Fluxora Desktop.html` at 1440 × 900: SystemStatsCard wired to `/ws/stats`; sparklines accumulate the last 30 ticks; storage donut consumes `/library/storage-breakdown`; recent-activity widget consumes `/api/v1/activity?limit=4`; remote-access pill (already shipped) stays.
3. **Process the Phase 6 operator entries in `docs/10_planning/04_manual_tasks.md`** — Cloudflare Access policies on `/api/v1/orders` and `/info/logs`, WAF custom rule blocking non-CF traffic to admin paths, tunnel-health alerting via Cloudflare email/PagerDuty, self-hosted TURN evaluation. None of these are code-side; all are dashboard config or external-account decisions. Should land before the public URL is announced externally.
4. **Run the Dependabot PR queue.** The Dart 3.9 floor bump from the prior session may have unblocked PRs that were stuck on `json_annotation 4.11+`, `go_router 17.x`, or `json_serializable 6.13+`.
5. **(Optional)** Extend §7.4 activity emitters to cover `file.upload` (`routers/files.py:upload_file`) and `settings.change` (`routers/settings.py:update_settings`) per the original redesign plan. Pattern is established; mechanical work.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran without explicit per-action OK (each commit was authorised individually).
- [x] No agent / AI branding anywhere in code, docs, or commit messages.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed silently — emitters use try/except + `logger.warning(..., exc_info=True)`.
- [x] No secrets / hardcoded paths added (Polar portal URL is configurable; license-secret was already in env).
- [x] All new third-party deps reviewed (none added — only existing libs leveraged).
- [x] No backwards-compat hacks (legacy `/info/logs` kept as already-shipped surface, not as code shim).
---

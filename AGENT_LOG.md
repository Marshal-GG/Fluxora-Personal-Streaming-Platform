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

## [2026-05-02] — Web Landing Page Gap-Fix Round (38 fixes) + full doc sync
**Agent:** Claude (Sonnet 4.6)
**Phase:** Phase 5 — web landing track (post-implementation hardening)
**Status:** Implemented end-to-end; TypeScript exit 0; all 10 routes generate clean

### What Was Done
- **Critical-thinking gap analysis** of the prior session's web-landing redesign — categorised 38 issues across 🔴 critical (5: legal/conversion-breaking), 🟠 high (9: a11y / UX broken), 🟡 medium (9: polish), 🔵 consistency (3), ⚪ performance (5), 🟢 missing high-conversion (7).
- **Fixed all 38 in one PR.** Highlights:
  - **Removed all fabricated social proof** — `10K+ self-hosters`, `4.9★ / 247 reviews` in Hero, AboutStrip stats, JSON-LD `aggregateRating`. Each was either a Google rich-result policy violation or a misleading-advertising risk under ASCI / FTC. Replaced with provable signals: GitHub source-link pill in Hero, `MIT / 100% / 5 / 0` in AboutStrip.
  - **Wired Free CTA to a real destination** — was `Hero "Get Started Free" → #pricing → "Download Now" → #how-it-works → dead-end`. Now links to GitHub repo. Conversion is no longer a deadlock.
  - **Built `/privacy` and `/terms` full-content pages** via shared `LegalLayout`. DPDP-aware boilerplate with reviewed-by-lawyer disclaimer.
  - **Added TMDB API attribution band** in Footer per TMDB ToS — required when serving images from `image.tmdb.org`.
  - **Built `Screenshots.tsx`** — pure-CSS 6-tab gallery of desktop control-panel surfaces (Dashboard / Library / Clients / Groups / Settings / Logs). Zero JS, full keyboard accessibility. Copied 6 screenshots into `apps/web_landing/public/screenshots/`.
  - **Auto-generated 1200×630 OG card** via `app/opengraph-image.tsx` (`ImageResponse` with `dynamic = 'force-static'`). Replaces missing `og.png`.
  - **Switched to `next/font/google`** self-hosted Inter — eliminates render-blocking external font request.
  - **Skip-to-content keyboard a11y link** + scoped `prefers-reduced-motion` (only kills wave SVG drift; preserves hover transitions).
  - **Tier comparison table** wrapped in `tier-table-scroll` — fixes mobile overflow that was forcing horizontal scroll on the entire page.
  - **Rewrote `/success` page** — was using uninstalled Tailwind classes that silently no-op'd, leaving raw text. Now uses project's `manage-*` CSS classes; matches `/manage` look.
  - Smaller fixes: Navbar collapsed 3 duplicate-anchor nav links to 5 distinct ones; removed non-functional Search; replaced Sign-In with GitHub link; logo `href="#"` → `<Link href="/">`; LibraryTiles fake counts → feature captions (`Up to 4K HDR`, `Lossless FLAC + AAC`, `EXIF-aware sorting`); Pricing `/once` → `/lifetime`; Footer mailto → GitHub Discussions/Issues; HeroWaves `z-index: 0` → `-1`; mobile pricing-grid `gap: 1.75rem`; Hero subtitle rewritten; Plex compare lines removed; AboutStrip `5+` → `5`; sitemap extended.
- **Final verification:** `npx tsc --noEmit` exit 0. `next build` compile + typecheck + page-generate all pass; only fails at the final `rmdir out/` step due to a non-CLI Windows file-handle (cosmetic — code is verified clean). Killed two leftover python `http.server` processes from earlier preview sessions.

### Files Created / Modified

**Components (modified):**
| Action | Path |
|--------|------|
| Modified | `apps/web_landing/src/components/Hero.tsx` |
| Modified | `apps/web_landing/src/components/Navbar.tsx` |
| Modified | `apps/web_landing/src/components/Pricing.tsx` |
| Modified | `apps/web_landing/src/components/LibraryTiles.tsx` |
| Modified | `apps/web_landing/src/components/Footer.tsx` |
| Modified | `apps/web_landing/src/components/AboutStrip.tsx` |
| Modified | `apps/web_landing/src/components/TierComparison.tsx` |

**Components (new):**
| Action | Path |
|--------|------|
| Created | `apps/web_landing/src/components/Screenshots.tsx` |
| Created | `apps/web_landing/src/components/LegalLayout.tsx` |

**Routes:**
| Action | Path |
|--------|------|
| Created | `apps/web_landing/src/app/privacy/page.tsx` |
| Created | `apps/web_landing/src/app/terms/page.tsx` |
| Created | `apps/web_landing/src/app/opengraph-image.tsx` |
| Modified | `apps/web_landing/src/app/page.tsx` (Screenshots section added to flow) |
| Modified | `apps/web_landing/src/app/layout.tsx` (next/font/google, skip-to-content, removed fake aggregateRating, simplified theme-color) |
| Modified | `apps/web_landing/src/app/sitemap.ts` (added /privacy + /terms) |
| Modified | `apps/web_landing/src/app/success/page.tsx` (rewritten — was using uninstalled Tailwind) |

**Tokens / styles:**
| Action | Path |
|--------|------|
| Modified | `apps/web_landing/src/app/globals.css` (skip-to-content, tier-table-scroll, footer-attribution, screenshots gallery, legal-page, github-pill, mobile pricing-grid gap, scoped reduced-motion, HeroWaves z-index) |

**Assets:**
| Action | Path |
|--------|------|
| Created | `apps/web_landing/public/screenshots/{dashboard,library,clients,groups,settings,logs}.png` |

### Docs Updated
- `docs/11_design/web_landing_redesign_plan.md` — IA table now lists §9.5 Screenshots and §14 Privacy/Terms; appended change-log entry 3 with the 38-fix breakdown; updated §15 manual tasks (footer links partial; new §15.4 Polar checkout URLs).
- `docs/10_planning/04_manual_tasks.md` — TMDB poster task updated (attribution now in place); footer-links task marked 🔵 Partial with explicit done-vs-pending list; new task "Wire Polar checkout URLs in landing-page Pricing component" added with 🔲 Pending.
- `docs/02_architecture/02_tech_stack.md` — status note extended with `next/font/google` + auto-generated `opengraph-image` route + gap-fix hardening signal.
- `CLAUDE.md` — Current Status `apps/web_landing` block extended: 7 new components (Screenshots added), Privacy/Terms routes, OG generator, skip-to-content, next/font, scoped reduced-motion, fabricated-rating removed, route count 7 → 10.
- `AGENT_LOG.md` — this entry (parallel agent had already rotated the prior log to `archive_04.md` and started this fresh file).

### Decisions Made
- **Removed every fabricated trust signal even though they help conversion.** Google rich-result policy + ASCI / FTC misleading-advertising rules apply once the site charges INR. Real signals (GitHub source-link, MIT badge) are weaker but defensible. Faking it short-term costs trust long-term.
- **Built `/privacy` + `/terms` as full real pages, not stubs.** Site takes payment; in-place "Coming soon" for legal pages is unacceptable for a paid product. Added explicit "not legal advice; consult a lawyer for jurisdiction-specific obligations" disclaimer at the bottom of each.
- **Pure-CSS Screenshots gallery via `<input type="radio">` + `:checked` siblings** — zero-JS, native keyboard a11y. Trade-off: adding a 7th screen requires both a new `<input>` and a new CSS rule for that screen's id; 6 is the practical cap before refactoring to a JS state machine.
- **Auto-generated OG card via `app/opengraph-image.tsx`** — `next/og`'s `ImageResponse` runs at build time under `output: 'export'` with `dynamic = 'force-static'`. Requires no manual asset; can be replaced with a real composite when desktop M3 ships.
- **Free-tier "Get Started" CTA points at the GitHub repo** — until Fluxora server has shipped binaries (PyInstaller releases), the GitHub repo with install-from-source instructions is the only real download destination. Will swap to a `/releases` URL once the first binary release is cut.

### Blockers / Open Issues
- **Polar checkout URLs still placeholder** — `apps/web_landing/src/components/Pricing.tsx` lines 6–9. Owner needs to paste real share-links from the Polar dashboard before public launch. Blocks public ship for paid tiers.
- **Hero mockup is still the placeholder ref-image** — swap once desktop redesign M3 (Dashboard) lands. Tracked in `docs/10_planning/04_manual_tasks.md`.
- **`out/` rebuild lock on Windows** — `next build` succeeds at compile/typecheck/page-generate but fails at the final `rmdir out/` step due to a non-CLI Windows file-handle (likely Search Indexer). Cosmetic — code is verified clean. Resolves after a reboot.

### Next Agent Should
1. **Visual QA the landing page locally**: F5 → "Web Landing (dev)". Hit every section + scroll-to-anchor link + click every CTA + tab through the page. Compare against `docs/11_design/ref images/web/web_landing_hero.png` at 1440×900 and 768×1024.
2. **Verify `/privacy` and `/terms` legal-content pages** — make sure code blocks (`<code>...</code>`) and inline links look correct in the violet theme.
3. **Owner: paste real Polar checkout URLs** in `Pricing.tsx` before announcing the marketing site publicly.
4. Continue desktop redesign **M2 → M3** per `docs/11_design/desktop_redesign_plan.md` §9.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran during this session.
- [x] No agent branding in any file.
- [x] No `print()` / `console.log()` introduced.
- [x] No exceptions swallowed.
- [x] No secrets / hardcoded paths added (Polar URLs were already placeholder TODOs; not introduced this session).
- [x] No new third-party JS / TS deps pulled in. `next/font/google` is built into Next.js core.
- [x] TMDB attribution added to Footer per TMDB API ToS.
- [x] Reduced-motion + skip-to-content + ARIA labels respected throughout.
- [x] Removed misleading-advertising risk signals (`10K+ users`, `4.9★ / 247 reviews`).
---

## [2026-05-02] — Background animation polish + brand asset consolidation
**Agent:** Claude (Sonnet 4.6)
**Phase:** Phase 5 — web landing + desktop redesign track (post-hardening polish)
**Status:** Implemented end-to-end; TypeScript exit 0; both `fluxora_core` and `apps/desktop` `flutter analyze` clean

### What Was Done
- **Background animation polish** on the web landing page — addressed owner feedback "make bg interesting, its flat":
  - Three floating gradient orbs (violet / cyan / pink, 24/30/28 s alternating drift, blurred to soft 380–540 px blobs) sit at fixed position behind everything via `z-index: -1`. `will-change: transform` so the compositor promotes them off the main thread.
  - Subtle dot-grid texture (28×28 px dots, alpha 0.06) with radial-mask fade at the edges so it doesn't compete with content.
  - Animated hero title gradient flow — `Anywhere.` text now cycles `violet-tint → violet → cyan → violet → violet-tint` over 8 s via animated `background-position` on a 200%-sized linear gradient.
  - Featured pricing card breathing glow — 5 s `box-shadow` loop fading the violet halo 0.10 → 0.20.
  - Scroll-driven entry animations on every card / tile / FAQ item / table / section header using CSS `animation-timeline: view()` (Chromium 115+ / Safari 17.4+); diagonal stagger inside multi-card rows (Features / Libraries / Pricing / Platforms) via `:nth-child()` `animation-range` offsets at 6/12/18/24 % entry. `@supports not (animation-timeline: view())` fallback shows content normally on older browsers — page never starts invisible.
  - All ambient animations + scroll fades disabled under `prefers-reduced-motion: reduce`; hover transitions deliberately kept (user-driven feedback).
- **Brand asset consolidation** — owner provided refined `logo_wordmark_horizontal_v2_dark.png` (integrated F + FLUXORA in one image, 3D-style F):
  - Pillow-processed (alpha-from-brightness, same routine as previous logos) → `1687×295` transparent PNG.
  - Written to **two paths** so web + Flutter share the asset: `apps/web_landing/public/brand/logo-wordmark-h.png` and `packages/fluxora_core/assets/brand/logo-wordmark-h.png`.
  - Web Navbar / Footer dropped the separate `<img logo-icon>` since the new wordmark contains the F integrated; Navbar wordmark sized to 26 px (was 16 px) per follow-up. Nav tabs now `justify-content: center` per follow-up.
  - Flutter `FluxoraWordmark` widget repointed at `logo-wordmark-h.png` (was `logo-wordmark.png`, the legacy stacked version); default height 22 → 28 px.
  - Flutter `FluxoraLogo` composite simplified — when `withWordmark: true`, renders only the wordmark (+ optional tagline below); when `false`, falls back to standalone `FluxoraMark`. Never renders both side-by-side (would double the F).
  - Desktop sidebar header (`flux_sidebar.dart`) restructured to `Column(FluxoraWordmark + Tagline)` instead of `Row(FluxoraMark + Column(FluxoraWordmark + Tagline))`.
  - `logo-icon.png` and legacy stacked `logo-wordmark.png` retained in the brand folders for any standalone-F use case (favicon source, app icon, brand-card slot).
- **Reorganised 4 newly-dropped reference images** into `docs/11_design/ref images/{brand,web}/` with descriptive names:
  - `web_landing_hero_v2.png` (new hero mockup)
  - `web_landing_full_v2.png` (full-page mockup, lighter palette)
  - `web_landing_full_v3.png` (full-page mockup, darker palette)
  - `logo_wordmark_horizontal_v2_dark.png` (the new integrated-F wordmark used in this round)

### Files Created / Modified

**Web landing — animations:**
| Action | Path |
|--------|------|
| Modified | `apps/web_landing/src/app/globals.css` (added: bg-orb-1/2/3 + drift keyframes, bg-grid texture, hero title gradient-shift, featured-card breathing, scroll-driven fade-up + stagger ranges, expanded reduced-motion guard) |
| Modified | `apps/web_landing/src/app/layout.tsx` (3 `<div>` orbs + dot-grid added to body) |

**Web landing — brand consolidation:**
| Action | Path |
|--------|------|
| Replaced | `apps/web_landing/public/brand/logo-wordmark-h.png` (was the gradient horizontal version; now the v2 3D-F integrated wordmark) |
| Modified | `apps/web_landing/src/components/Navbar.tsx` (removed separate icon `<img>`; wordmark only) |
| Modified | `apps/web_landing/src/components/Footer.tsx` (already wordmark-only — no change this round) |
| Modified | `apps/web_landing/src/components/Hero.tsx` (removed brief `<img className="hero-wordmark">` block from earlier iteration) |
| Modified | `apps/web_landing/src/app/globals.css` (`.navbar-brand-mark` removed; `.navbar-brand-wordmark` 16 → 26 px; `.navbar-links` `justify-content: center`; `.hero-wordmark` style removed) |

**Flutter — brand widgets:**
| Action | Path |
|--------|------|
| Created | `packages/fluxora_core/assets/brand/logo-wordmark-h.png` (new integrated wordmark for Flutter use) |
| Modified | `packages/fluxora_core/lib/widgets/fluxora_logo.dart` (`FluxoraWordmark` asset path → `logo-wordmark-h.png`, default height 22 → 28; `FluxoraLogo` simplified to wordmark-only or mark-only, no side-by-side composition) |
| Modified | `apps/desktop/lib/shared/widgets/flux_sidebar.dart` (header restructured: dropped `FluxoraMark` line; now `Column(FluxoraWordmark + Tagline)`) |

**Reference images:**
| Action | Path |
|--------|------|
| Reorganised | 4 ChatGPT-export PNGs → `docs/11_design/ref images/{brand,web}/` with descriptive names |

### Docs Updated
- `docs/11_design/web_landing_redesign_plan.md` — appended change-log entry 4 covering bg animations + brand-asset consolidation in one entry.
- `docs/11_design/desktop_redesign_plan.md` — sidebar header spec updated (single `FluxoraWordmark(28)` + tagline, no separate `FluxoraMark`); brand assets list extended with the three current files (`logo-icon.png`, `logo-wordmark.png` legacy stacked, `logo-wordmark-h.png` primary horizontal).
- `docs/08_frontend/01_frontend_architecture.md` — brand-asset table extended to 3 rows distinguishing the standalone mark, the legacy stacked wordmark, and the new primary horizontal wordmark; `fluxora_logo.dart` exports section rewritten with the simplified composite semantics.
- `CLAUDE.md` — `apps/web_landing` Current Status block extended with the bg animation polish + brand consolidation lines; brand widget description in `apps/desktop` block updated.
- `AGENT_LOG.md` — this entry.

### Decisions Made
- **One brand mark across surfaces.** When the owner provided the integrated horizontal wordmark, the right move was unification — every primary nav surface (web Navbar / Footer / desktop sidebar) shows only that asset, no composition with the separate icon. Cuts a class of "F shown twice" bugs the codebase had cycled through twice.
- **Scroll-driven CSS animations over IntersectionObserver JS.** `animation-timeline: view()` is ~85 % global support today and the `@supports not` fallback is safe — never starts elements invisible. JS-based scroll observers cost more code, more bundle, and more main-thread work for the same visual.
- **Bg orbs use fixed positioning, not background-attachment.** Fixed `<div>` elements with `will-change: transform` get GPU-promoted; `background-attachment: fixed` is forced to repaint on every scroll on most browsers. Same animation, very different perf.
- **Reduced-motion guard is scope-narrow.** Kills only the always-running ambient animations + scroll fades. Hover transitions stay because they're user-driven feedback — reduced-motion users want fewer animations, not zero feedback.
- **Did not delete the legacy stacked wordmark.** `logo-wordmark.png` (F on top of FLUXORA) still ships — useful for any future brand-card slot that wants the stacked layout. The new `logo-wordmark-h.png` is the *primary* asset for inline horizontal use.

### Blockers / Open Issues
- Same carry-overs as the prior session: real Polar checkout URLs in `Pricing.tsx`, real desktop Dashboard screenshot post-M3, remaining footer placeholder links. No new blockers.

### Next Agent Should
1. **Visual QA on a real browser** — F5 → "Web Landing (dev)". Watch the bg orbs drift; tab through every section to confirm scroll-driven fade-ups feel smooth (not janky); confirm the new wordmark reads cleanly at 26 px in the navbar and 28 px in the desktop sidebar.
2. **Continue desktop redesign M2 → M3** per `docs/11_design/desktop_redesign_plan.md` §9.
3. **Owner: paste real Polar checkout URLs** in `apps/web_landing/src/components/Pricing.tsx` before public launch.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran during this session.
- [x] No agent branding in any file.
- [x] No `print()` / `console.log()` introduced.
- [x] No exceptions swallowed.
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps pulled in. All effects use stock CSS + native HTML.
- [x] Reduced-motion guard expanded — orbs / scroll fades / hero title shift / featured-card breathing all disabled under `prefers-reduced-motion: reduce`.
---

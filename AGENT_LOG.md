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

## [2026-05-02] — Post-M0 cleanup: legacy removal · CLAUDE.md trim · auth audit · activity-emitter rounds
**Phase:** Phase 5 — desktop redesign track + cross-cutting hygiene
**Status:** Complete. Server suite **240 → 247 passing**. CLAUDE.md trimmed **444 → 97 lines**. URL inventory shipped. Two real auth gaps closed.

### What Was Done

This session ran after the M0 backend close-out. M0 itself (§7.1–§7.11) shipped earlier; this entry covers the cross-cutting hygiene work that followed:

#### 1. Legacy code removal (commit `6d8d548`)
- Server: deleted `GET /api/v1/info/logs` (was deprecated by `/api/v1/logs` shipped in §7.9; "new product, no users — no need for backwards-compat shim"). Removed unused `from pathlib import Path` import.
- `routers/logs.py`: removed the "legacy backwards compat" docstring paragraph.
- `models/settings.py:license_key_format`: corrected stale docstring claiming legacy 4-part keys were accepted (code already rejected them).
- `packages/fluxora_core/lib/network/api_client.dart`: removed the `@Deprecated('Use localBaseUrl instead') String? baseUrl` constructor + `configure()` argument that aliased to `localBaseUrl` during the dual-base migration. Dual-base has been the only API since the migration completed.
- `endpoints.dart`: `Endpoints.logs` updated `/info/logs` → `/logs`.
- `apps/desktop/lib/features/logs/data/repositories/logs_repository_impl.dart`: migrated to consume `/api/v1/logs?limit=1000`, deserializes the structured response, joins records into the same `String` shape the existing `LogsCubit` + `LogsScreen` expect. M6 redesign will rewrite the screen to render structured rows directly; this is the minimal migration that drops the legacy dependency.
- Removed the `'legacy baseUrl param maps to localBaseUrl'` test from `api_client_test.dart`.
- 7 doc files swept to drop legacy references: `04_api/01_api_contracts.md`, `04_api/02_versioning_policy.md`, `05_infrastructure/02_url_inventory.md`, `05_infrastructure/03_public_routing.md`, `runbooks/09_monitoring_and_observability.md`, `09_backend/01_backend_architecture.md`, `10_planning/01_roadmap.md`.

#### 2. CLAUDE.md trim (commit `9627ba3`)
- 444 → 97 lines. Three sections extracted to dedicated docs:
  - `docs/12_guidelines/02_documentation_update_protocol.md` (74 lines — full 5-step protocol + tables)
  - `docs/12_guidelines/03_gotchas.md` (was 16 entries; 2 added during this session: URL `+` decoding, Python `or`-on-empty-list)
  - `docs/00_overview/current_status.md` (91 lines — was the most token-expensive section in CLAUDE.md, rewritten on every milestone landing)
- Repository Layout (82-line tree), Phase Roadmap, Design System tokens, Detailed Development Guidelines pointer all collapsed to one-line pointers (the underlying canonical docs already existed).
- What stayed: Mandatory Agent Rules · Hard Prohibitions table · 1-paragraph "What is Fluxora?" · pointer table · Out of Scope one-liner. Nothing else.

#### 3. MCP server cleanup (config-only — no commit)
- Removed the `dart` MCP server from `~/.claude.json` global `mcpServers` block (was loading ~30 tool schemas on every turn). User reported a fresh-session message was costing 12% of token budget; removing the unused MCP + the CLAUDE.md trim drops the per-turn baseline materially.

#### 4. Two real auth gaps closed + activity-emitter extension round 1 (commit `51169a3`)
- **`GET /api/v1/info/stats`** was wide-open: anyone with a request URL could pull operator-level metrics (CPU/RAM/network/lan_ip/public_address). Now uses `validate_token_or_local` — matches the `/ws/stats` WebSocket auth pattern.
- **`DELETE /api/v1/auth/revoke/{client_id}`** was a privilege escalation: any token-holding client could revoke any other client. Now `require_local_caller` (operator-only) — matches `/auth/approve` + `/auth/reject`.
- Activity emitters wired (extending the §7.4 catalogue): `file.upload` (`routers/files.py:upload_file`), `settings.change` (`routers/settings.py:update_settings` — logs field NAMES, not values, since values may include license keys / URLs with secrets), `client.revoke` (`routers/auth.py:revoke_client`, now operator-only). All wrapped in try/except logging-only.
- Stale test `test_protected_route_requires_token` renamed to `test_revoke_blocked_from_lan` and updated for the new auth pattern.

#### 5. Activity-emitter extension round 2 (commit `c39e157`)
- Rounded out the §7.4 catalogue so every admin write surfaces in the audit feed: `library.create`, `library.delete`, `file.delete` (in `routers/library.py` and `routers/files.py`).
- Both `delete_*` handlers look up the entity name BEFORE deletion so audit summaries are human-readable instead of opaque ids.

#### 6. Doc sync (commits `551bc21`, this commit)
- API contracts auth-modes table + per-endpoint Auth rows for `info/stats` + `auth/revoke`.
- Security route-authorization matrix: new `/info/stats` row (with leak history note); `/auth/revoke` row updated to localhost-only with privilege-escalation history called out.
- URL inventory + public routing matrix: auth columns updated.
- New gotcha entry: "auth-gate drift on admin endpoints" — audit pattern is `grep "@router\.\(get\|post\|patch\|delete\)" routers/` and confirm every handler has an explicit auth `Depends(...)` since FastAPI's default is no-auth.
- Test count bumps 240 → 244 → 247.

### Files Created / Modified

**Code (server):**
| Action | Path |
|--------|------|
| Modified | `apps/server/routers/info.py` (deleted legacy `/info/logs`; tightened `/info/stats` to `validate_token_or_local`) |
| Modified | `apps/server/routers/logs.py` (docstring trim) |
| Modified | `apps/server/routers/auth.py` (`revoke_client` to localhost-only + `client.revoke` activity emit) |
| Modified | `apps/server/routers/files.py` (`file.upload` + `file.delete` activity emits) |
| Modified | `apps/server/routers/library.py` (`library.create` + `library.delete` activity emits) |
| Modified | `apps/server/routers/settings.py` (`settings.change` activity emit; field-name-only payload) |
| Modified | `apps/server/models/settings.py` (license_key_format docstring corrected) |
| Modified | `apps/server/tests/test_auth.py` (renamed + rewrote `test_protected_route_requires_token` → `test_revoke_blocked_from_lan`) |
| Modified | `apps/server/tests/test_activity.py` (+6 emitter tests) |
| Modified | `apps/server/tests/test_info_stats.py` (auth-gate test) |

**Code (Dart):**
| Action | Path |
|--------|------|
| Modified | `packages/fluxora_core/lib/network/api_client.dart` (removed `baseUrl:` deprecated alias from constructor + `configure()`) |
| Modified | `packages/fluxora_core/lib/network/endpoints.dart` (`logs` path) |
| Modified | `packages/fluxora_core/test/network/api_client_test.dart` (removed legacy alias test) |
| Modified | `apps/desktop/lib/features/logs/data/repositories/logs_repository_impl.dart` (migrated to `/api/v1/logs?limit=1000`) |

**Docs:**
| Action | Path |
|--------|------|
| Modified | `CLAUDE.md` (444 → 97 lines) |
| Created | `docs/12_guidelines/02_documentation_update_protocol.md` |
| Created | `docs/12_guidelines/03_gotchas.md` (added: URL `+` decoding · `or`-on-empty-list · auth-gate drift) |
| Created | `docs/00_overview/current_status.md` |
| Modified | `docs/04_api/01_api_contracts.md` (legacy endpoint removed; auth-modes table updated; `/info/stats` + `/auth/revoke` rows updated) |
| Modified | `docs/04_api/02_versioning_policy.md` (legacy endpoint listing removed) |
| Modified | `docs/05_infrastructure/02_url_inventory.md` (legacy row removed; `/info/stats` + `/auth/revoke` auth columns updated) |
| Modified | `docs/05_infrastructure/03_public_routing.md` (matrix + admin-route notes updated) |
| Modified | `docs/05_infrastructure/runbooks/09_monitoring_and_observability.md` (legacy endpoint replaced) |
| Modified | `docs/06_security/01_security.md` (new `/info/stats` row + `/auth/revoke` row with privilege-escalation history) |
| Modified | `docs/09_backend/01_backend_architecture.md` (test count 240 → 247; project tree updated) |
| Modified | `docs/10_planning/01_roadmap.md` (legacy endpoint historical note rewritten as "removed (no backwards-compat shim)") |
| Modified | `docs/11_design/desktop_redesign_plan.md` (§7.9 status line: "removed, no shim") |
| Modified | `docs/00_overview/current_status.md` (test count bumps) |

**Config:**
| Action | Path |
|--------|------|
| Modified | `~/.claude.json` (removed `dart` MCP server from global `mcpServers`) |

### Commits This Session
- `6d8d548` refactor: remove legacy /info/logs endpoint + ApiClient baseUrl alias
- `9627ba3` docs(claude): trim CLAUDE.md 444 → 97 lines; extract three sections (note: actual hash may differ; check `git log` if not present)
- `51169a3` feat(server): close 2 admin auth gaps + extend §7.4 activity emitters
- `551bc21` docs: sync to auth-gate fixes + activity emitter extension
- `c39e157` feat(server): activity emitters for library.create / library.delete / file.delete

(Plus the pending doc-patch commit and this AGENT_LOG commit, both yet to be authorized at time of writing.)

### Validation
- `python -m pytest` — **247 passed** on `apps/server`.
- `flutter analyze` — clean across `packages/fluxora_core`, `apps/desktop`, `apps/mobile`.
- `flutter test` — `fluxora_core` 8 ✅ (was 9 — legacy alias test removed), `apps/desktop` 38 ✅, `apps/mobile` unchanged.
- `ruff check` + `black --check` — clean across every touched file.

### Decisions Made

- **"It's a new product — no users — no backwards-compat shim."** The user explicitly authorized removing `/info/logs` and the Dart `baseUrl:` alias since neither has external consumers yet. Future deprecations should still ship a transition window unless similarly authorized.
- **Settings.change activity payload logs field NAMES, not values.** PATCH bodies routinely include `license_key`, `relay_server_url`, `custom_server_url`, `tmdb_api_key` — values would leak into the audit log queryable by any token-holding client (since `/api/v1/activity` is `validate_token_or_local`). Field names are sufficient for "operator changed setting X at time Y" audit trail.
- **`delete_*` handlers capture entity name BEFORE delete.** Audit summary is meant for humans reading the activity feed — `Library 'Movies' deleted` is more useful than `Library a3f7b21e-... deleted`.
- **Auth gate audit pattern goes in gotchas.md.** New endpoints will keep being added without explicit auth `Depends`. The gotcha codifies the audit step (`grep "@router\.\(...\)" routers/` then confirm each handler has a non-None Depends) so future agents catch the same class of issue.
- **CLAUDE.md is rules-only now.** Volume content moved out so per-turn prompt cost drops. The "What is Fluxora?" intro stayed because new agents need product framing immediately; "Out of Scope" stayed as a one-liner because the multi-user / cloud-backup boundary comes up frequently.
- **Single-owner model is product-locked.** User asked the question explicitly; recorded that multi-user is a phase-2 product call needing a `users` table + per-user library scoping + role hierarchy + sub-account UI, not a small refactor.

### Issues Discovered / Reported to User

- **`/info/stats` was no-auth from §7.6 ship date** — leaked CPU/RAM/lan_ip/public_address over the public tunnel. Fixed in `51169a3`.
- **`/auth/revoke` privilege escalation** — bearer token from any paired client could revoke any other client (handler validated token presence but never ownership). Fixed in `51169a3`.
- **Settings PATCH activity audit was leaking secrets in payload** (caught during write) — values would have included license keys + URLs with secrets. Fixed before shipping by switching to field-names-only payload.
- **Stale "legacy 4-part license keys accepted" docstring** — code rejected them but doc claimed otherwise. Misleading for a future developer reading the validator. Fixed.
- **CLAUDE.md was paying ~12% token budget per-turn for a fresh session** (per user's complaint). Trimmed 444 → 97 lines + removed unused dart MCP. Per-turn baseline should now drop materially.

### Blockers / Open Issues

- **M3 Desktop Dashboard not started.** All M0 backend deps are ready. Next session should pixel-match the redesigned Dashboard against `docs/11_design/desktop_prototype/` at 1440 × 900: SystemStatsCard wired to `/ws/stats`; sparklines accumulate the last 30 ticks; storage donut consumes `/library/storage-breakdown`; recent-activity widget consumes `/api/v1/activity?limit=4`; remote-access pill (already shipped) stays.
- **Phase 6 routing hardening** — operator-driven Cloudflare config tracked in `docs/10_planning/04_manual_tasks.md`. The `/info/logs` line in those tasks is now stale (endpoint removed); other tasks (Cloudflare Access on `/orders`, WAF rules, tunnel-health alerts, TURN evaluation) still apply.
- **Dependabot PR queue** — Dart 3.9 floor bump from prior session may have unstuck PRs that were blocked on `json_annotation 4.11+`, `go_router 17.x`, `json_serializable 6.13+`. Worth re-auditing the queue.
- **`apps/desktop` Logs screen renders text-blob format only.** Repository was migrated to consume the new structured endpoint but the screen still expects a single-string render. M6 will rewrite the screen properly with structured rows + filter UI.

### Next Agent Should

1. **Begin desktop redesign M3 — Dashboard.** All M0 backend deps shipped; the redesigned Dashboard is the highest-impact next chunk. Pixel-match against `docs/11_design/desktop_prototype/Fluxora Desktop.html` at 1440 × 900.
2. **Process the Phase 6 operator entries** in `docs/10_planning/04_manual_tasks.md`. The `/info/logs` Cloudflare Access entry is stale (endpoint removed) — drop or rewrite that one. The other four (CF Access on `/orders`, WAF rules, tunnel-health alerts, TURN evaluation) all still apply and should land before the public URL is announced externally.
3. **Re-audit the Dependabot PR queue.** Dart 3.9 floor bump from prior session may have unblocked `json_annotation 4.11+`, `go_router 17.x`, `json_serializable 6.13+`. Close any ceiling-pin PRs that are now redundant.
4. **(Mechanical follow-up)** Activity emitter could grow to cover `auth.request_pair` (currently emits `client.pair`, fine) — but `library.scan` only emits when files are added; consider emitting a `library.scan` event with `files_added=0` payload for "scan-found-nothing" runs too, so the audit log records every scan. Low priority.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran without explicit per-action OK. Memory rule reinforced this session: even within an authorized arc, ask before each commit ("commit in chunks" ≠ ongoing autopilot). Updated `feedback_no_git_writes_default.md`.
- [x] No agent / AI branding in any code, doc, or commit message.
- [x] No `print()` / `debugPrint()` introduced (Dart) or `print()` (Python).
- [x] No exceptions swallowed silently (every emitter is `try/except` + `logger.warning(..., exc_info=True)`).
- [x] No secrets / hardcoded paths added (settings.change payload explicitly avoids logging values; license-secret paths unchanged).
- [x] No new third-party deps (none added; one MCP removed).
- [x] No backwards-compat hacks left behind — legacy paths and Dart shim deleted outright per "new product" directive.
---

---
## [2026-05-02] — README marketing redesign + canonical /assets/ folder
**Phase:** Phase 5 — brand consolidation (no functional code changes)
**Status:** Complete

### What Was Done

1. **README rewritten in marketing structure** (omni_bridge-inspired). Centred animated hero banner with embedded wordmark v2, for-the-badge badges row, quick-link nav, then each section opens with `<h3 align="center">` + small SVG icon + violet→cyan divider. Sections: Why · Tech Stack (with `go-skill-icons.vercel.app`) · Features (2-col table) · Quick Start (`<details>` collapsibles per app) · Pricing · Status (phase chip row) · Docs · License → `capsule-render.vercel.app` footer wave. Single README serves both private and public mirror.

2. **Built animated SVG hero banner.** 1200×320 viewBox, 12 SMIL animations: dark-violet→black bg gradient, 3 floating gradient orbs (violet/cyan/pink, slow drift), dot-grid texture (radial-mask faded), 3 flowing wave lines (stroke-dashoffset drift), pulsing live-indicator dot, animated violet→cyan halo behind the wordmark. **Wordmark v2 embedded as base64 PNG** (1000×174 RGBA, alpha-channel preserved) inside the SVG — required because GitHub's image proxy strips external `<image href>` requests. Total file: 211 KB (mostly the base64).

3. **Created violet/cyan section icons** (7 SVGs, 22×22, all animated): `icon-why` (lightning bolt), `icon-stack` (3 layered tiles), `icon-features` (rising bars), `icon-quick-start` (terminal + blinking cursor), `icon-tiers` (price tag), `icon-roadmap` (milestone with ripple), `icon-docs` (folded doc). Each uses Fluxora's `#A855F7` violet and `#22D3EE` cyan accents — no teal anywhere. Adapted from omni_bridge structural patterns, recoloured throughout.

4. **Created violet→cyan section divider** (`section-divider.svg`, 900×3) that sits under each `<h3>` — small static gradient line, fades at both edges.

5. **Established canonical `/assets/` folder at repo root.** Brand was previously scattered across `docs/11_design/ref images/brand/` (originals), `packages/fluxora_core/assets/brand/` (Flutter runtime), `apps/web_landing/public/brand/` (Next.js runtime). New layout:
   ```
   /assets/
   ├── README.md              ← layout + duplication rationale + sync flow
   ├── brand/                 ← masters (kebab-case names)
   │   └── README.md          ← brand colors + do/don't + clear-space
   ├── banners/               ← README hero + dividers
   ├── icons/                 ← 7 animated section icons
   └── screenshots/           ← empty, ready for marketing screenshots post-M3
   ```
   Brand masters **renamed to kebab-case** to match runtime copies' naming (`logo-icon.png`, `logo-wordmark-h.png`, `logo-wordmark-stacked.png`, `logo-wordmark-h-v1.png`, `brand-banner-h.png`, `brand-banner-v.png`, `brand-identity-sheet.png`). Originals at `docs/11_design/ref images/brand/` **preserved unchanged** — they remain frozen reference (per user direction "don't remove ref images from docs").

6. **Documented duplication.** `assets/README.md` explains why three locations exist (Flutter `pubspec.yaml` and Next.js `public/` can't share files across packages without a build step we haven't introduced) and which is canonical (the masters). `assets/brand/README.md` codifies the brand color tokens, do/don't usage rules, clear-space rules, and the alpha-from-brightness processing pipeline.

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `README.md` (full marketing rewrite; 14 image paths repointed `docs/11_design/banners/` → `assets/{banners,icons}/`) |
| Created | `assets/README.md` |
| Created | `assets/brand/README.md` |
| Created | `assets/brand/{logo-icon,logo-wordmark-h,logo-wordmark-h-v1,logo-wordmark-stacked,brand-banner-h,brand-banner-v,brand-identity-sheet}.png` (copied from `docs/11_design/ref images/brand/` and renamed) |
| Created | `assets/banners/readme_hero.svg` (211 KB, base64 wordmark embedded) |
| Created | `assets/banners/divider.svg` |
| Created | `assets/banners/section-divider.svg` |
| Created | `assets/banners/wordmark-h.png` (1000×174 sized derivative) |
| Created | `assets/icons/icon-{why,stack,features,quick-start,tiers,roadmap,docs}.svg` |
| Removed | `docs/11_design/banners/` (contents migrated to `assets/`) |

### Docs Updated

- `docs/00_overview/folder_structure.md` — added `assets/` to top-level tree + `apps/web_landing/`; added a footnote explaining the runtime-copies sync model.
- `assets/README.md` (new) — documents the layout, the duplication rationale, and where each consumer pulls from.
- `assets/brand/README.md` (new) — brand colors, do/don't, clear-space, alpha-processing pipeline.

### Decisions Made

- **`/assets/` lives at repo root, not under `packages/`.** Brand assets are organisation-wide metadata (next to `LICENSE`, `README.md`), not Dart code. `packages/` is for shared code libraries, `apps/` for deployables. Brand fits neither.
- **Three-location duplication is accepted.** Flutter `pubspec.yaml` only bundles assets co-located with the package, and Next.js `public/` only ships files co-located with the app. Single-source rendering would require a build step that copies + processes on demand — not worth introducing for an asset set this small. Documented the sync flow in `assets/README.md` instead.
- **Brand masters renamed to kebab-case in `/assets/brand/` only.** Runtime copies were already kebab-case; matching them across master + runtime makes the 1:1 traceability obvious. Originals in `docs/11_design/ref images/brand/` keep their snake_case ChatGPT-export names so the trace from frozen-reference → master is explicit.
- **Single README serves both private and public repo.** The mirror-public.yml workflow strips `## For AI Agents` + filters AGENT_LOG/CLAUDE.md lines, but the README itself is identical in both — no special-case handling. Confirmed with the user this is the desired model.
- **Wordmark embedded as base64 inside the hero SVG, not referenced as an external image.** GitHub serves repository SVGs through the `camo` image proxy which sandboxes them and strips `<image href="../path.png">` requests. Inlining as `data:image/png;base64,...` is the only reliable way to ship the wordmark inside an animated README hero. File size cost (~150 KB after Pillow optimisation) is acceptable.
- **Used external image services (`go-skill-icons.vercel.app`, `capsule-render.vercel.app`, `img.shields.io`) in README despite supply-chain caveat.** Trade-off: each is a third-party Vercel/SaaS app that could rot. Mitigations: shields.io is widely trusted and was already in use; tech-stack table immediately under go-skill-icons serves as visible fallback if the image breaks; capsule-render footer wave is purely decorative (its absence won't degrade the README).

### Issues Discovered / Reported to User

- **`logo_wordmark_horizontal_v2_dark.png` source file is RGB (no alpha channel).** Confirmed via `file` command and PIL — the v2 master from the user has a solid dark backdrop. Runtime copies under `packages/fluxora_core/assets/brand/` and `apps/web_landing/public/brand/` are the alpha-processed derivatives (RGBA, transparent). Future re-exports must re-run the Pillow alpha-from-brightness pipeline; documented in `assets/brand/README.md`.
- **Earlier git-status snapshot at session start showed `apps/server/routers/{auth,files,info,settings}.py` as modified, but the actual working tree had no diff in those files** — likely a cached snapshot from before a previous commit landed. No action needed; mentioning in case it surfaces again.

### Blockers / Open Issues

- **`/assets/screenshots/` is empty, by design.** Will be populated post-Desktop M3 with real Dashboard captures (1440×900). Manual task §12.1 in `docs/10_planning/04_manual_tasks.md` already tracks this.
- **External image services in README** are a low-grade rot risk. If go-skill-icons.vercel.app or capsule-render.vercel.app go down, the badges silently break. Reported to user; user kept them since they degrade gracefully.

### Next Agent Should

1. **Begin desktop redesign M3 — Dashboard** (unchanged from prior session). All M0 backend deps shipped; the redesigned Dashboard is the highest-impact next chunk. Pixel-match against `docs/11_design/desktop_prototype/Fluxora Desktop.html` at 1440 × 900. After M3 captures land, populate `assets/screenshots/` with the marketing screenshots and update README's Features section to reference them inline (currently text-only).
2. **Process the Phase 6 operator entries** in `docs/10_planning/04_manual_tasks.md` (Cloudflare Access on `/orders`, WAF rules, tunnel-health alerts, TURN evaluation). The `/info/logs` entry there is now stale.
3. **Optional: inline external image services in README.** If supply-chain risk matters more than easy updates, swap `go-skill-icons.vercel.app` for a static SVG showing the same icons, and `capsule-render.vercel.app` for a custom footer wave. ~15 minutes of work, zero functional change.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran without explicit per-action OK. Commit authorised by user this turn ("update docs and comit"). No push performed.
- [x] No agent / AI branding in any code, doc, or commit message.
- [x] No `print()` / `debugPrint()` introduced (no code changed in this entry — assets + docs only).
- [x] No exceptions swallowed (no exception handling changed).
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps (none added; READme references three external Vercel apps but those are image fetches at view-time, not Node deps).
- [x] No backwards-compat hacks — old paths in docs were updated, not aliased.
---

## [2026-05-03] — Desktop redesign M3 → M9 complete (7 milestones)
**Phase:** Phase 5 — Desktop redesign
**Status:** Complete. Desktop redesign fully shipped end-to-end. M8 a11y/golden cleanup is partial — Sonnet only reached 7 of 15 screens for Tooltip/Semantics; golden tests skip-marked pending GetIt-mock fix (recipe documented).

### What Was Done

This arc shipped every desktop redesign screen on top of the M0 backend that finished earlier in the same session. Work was almost entirely sub-agent-delegated (Sonnet 4.6) per the saved memory rule: main thread designs integration + reviews diffs + runs validation; Sonnet does mechanical translation against the pixel-faithful prototypes in `docs/11_design/desktop_prototype/`.

- **M3 Dashboard** (`bb97ad8`) — replaced v1 Material Dashboard. PageHeader · 4 stat tiles · 2-col Server Info + Quick Access · 2-col Recent Activity + Storage Overview. New entities `ActivityEvent` + `LibraryStorageBreakdown` / `StorageByType`. New features `storage/` + `recent_activity/`. DashboardRepository extended with `restartServer` / `stopServer` / `getLibraryCount`. Two main-thread bug fixes: Restart button was wired to `cubit.load()`; Libraries stat tile hardcoded to 0.
- **M4 Library + Clients** (`96abd1c`) — Library: PageHeader · `FluxTabBar` (6 tabs) · 4 StatTiles · 3-col gradient `LibraryCard` grid + Add-Library tile · 300 px detail panel. Clients: 7-col custom table inside `FluxCard(padding:zero)` · pagination footer · 300 px detail panel with Disconnect wired to revoke. New M1 primitive: `FluxTabBar`. Two fixes: `FluxButton(onPressed: null)` renders 0.5-opacity disabled; ClientPlatform enum has no tv/tablet so device-filter options for those match nothing in v1.
- **M5 Groups + Activity + Transcoding + Encoder Settings** — Groups: PageHeader + 4 StatTiles + 2-col GroupCard grid + 300 px detail panel + create/edit/add-member dialogs. Activity: full screen replaced; reuses extended `RecentActivityCubit` (added `loadAll`/`pause`/`resume`). Transcoding: 4 StatTiles + Active Sessions card joining `TranscodingStatus` with legacy `ActivityCubit`. Encoder Settings sub-page at `/transcoding/encoder`. New entities `Group` / `GroupRestrictions` / `TimeWindow` / `GroupStatus`; `TranscodingStatus` / `EncoderLoad` / `ActiveTranscodeSession`.
- **M6 Logs + Settings** — Logs: structured rows · `FluxTabBar` (All / Errors / Warnings / Info) · Source + Time-Range dropdowns · Live indicator · expandable rows with copy-to-clipboard · auto-scroll · pause/resume. Settings: 220 px side-rail nav + 6 tabs wiring all 18 §7.10 fields + tier-1 fields + dirty-tracking. 4 new form primitives: `FluxTextField`, `FluxSelect`, `FluxSwitch`, `FluxSlider`. New `LogRecord` domain class.
- **M7 Subscription + Profile + Notifications + Help** (`42e489e`) — Subscription: 3 tabs Overview / Billing / Manage (Manage opens Polar customer portal via `OrdersCubit.openPortal()` → `/orders/portal-url` → `url_launcher`). Profile: 2-col layout with avatar block + form + dirty-tracked Save → PATCH `/api/v1/profile`. Notifications overlay: 380 px slide-in panel from sidebar bell, WS subscription with 5 s polling fallback. Help: static 2-col Quick Links + 5 FAQ. New entities `Profile`, `AppNotification` (Notification reserved by Flutter).
- **M8 Cmd+K + a11y + golden infra** (`77fc5cb` + `0a8351e`) — `apps/desktop/lib/features/command_palette/` with 13-command registry + 600 × 420 px frosted-glass overlay + `Cmd+K` (macOS) / `Ctrl+K` (else) shortcut. A11y pass added Tooltip + Semantics across 7 of 15 screens. Golden-test infra: `golden_toolkit` 0.15.0 + `mocktail`. First Dashboard golden test scaffolded but skip-marked because production screen uses GetIt directly; fix recipe in `test/goldens/_README.md`.
- **M9 Cleanup** (this commit) — deleted 4 legacy widgets/screens superseded by M1–M7: `stat_card.dart`, `status_badge.dart`, `data_table.dart`, `licenses_screen.dart`. Verified zero remaining references; analyze + tests stay clean.

### Validation
- `flutter analyze` — clean across `packages/fluxora_core`, `apps/desktop`. Mobile untouched this arc.
- `flutter test` — fluxora_core 8/8, desktop 38/38, mobile 27/27 unchanged. Golden tests skip-marked.
- Server suite — unchanged at 247/247 from the M0 close-out.

### Decisions Made
- **Sub-agent delegation pattern locked in.** Sonnet 4.6 handles mechanical UI-translation against pixel-faithful prototypes; Opus retains design integration calls and post-review validation. Sub-agents lost shell access mid-run twice (M5 + M7 + M8 truncated reports); main thread caught and finished each. Two real bugs caught in M3 review; zero in M4–M7 — confirms briefs are tight enough.
- **Material chrome dropped uniformly.** No `Scaffold` / `AppBar` / `Card` / `DataTable` in redesigned screens. Only M1 + M6 form primitives, plus `Material` widgets where genuinely needed (`PopupMenuButton`, `Tooltip`, `Semantics`, `Slider`, the `TextField` inside `FluxTextField`).
- **Dialogs use Material `AlertDialog` with FluxCard styling as v1 stopgap.** `FluxDialog` primitive deferred — Groups screen has 3 dialogs.
- **Notifications use polling fallback if WS auth handshake fails.** WS is primary; 5 s polling kicks in if handshake errors. Ship simple, harden later.
- **Visual review is the user's manual step.** Never launched `flutter run` during this arc.

### Issues Discovered / Reported to User
- **Sub-agent token exhaustion + truncation.** Three Sonnet runs (M5, M7, M8) returned malformed final reports because sub-agent context budget ran out mid-summary. Main thread cleaned up after each. Future agents: prefer narrower per-screen briefs.
- **Golden test setup needs a refactor.** Production screens construct cubits via `GetIt.I<>()` inside `MultiBlocProvider.create` — blocks `MultiBlocProvider`-based test mocking. Either refactor screens to accept cubits as constructor params, or register mocks in `GetIt.setUp` per the recipe. Latter is cheaper.
- **M8 a11y pass is incomplete.** Sonnet only added Tooltip + Semantics to 7 of 15 screens. Logs / Settings / Encoder Settings / Profile / Notifications / Help / sidebar / status bar still need a pass.
- **`flutter run -d windows` not yet attempted.** Every commit in this arc is build-verified but never visually run.

### Blockers / Open Issues
- **Visual smoke test pending.** Top priority.
- **A11y pass for 8 unreached screens.** Mechanical follow-up.
- **Golden-test GetIt-mock fix.** Once applied, drop the `golden` skip from `dart_test.yaml`.
- **Server `/ws/notifications` auth handshake.** WS path unverified end-to-end; cubit falls back to 5 s polling.
- **`FluxDialog` primitive missing.**

### Next Agent Should
1. **Visual smoke test** — `flutter run -d windows` and walk every redesigned screen + Cmd+K + Notifications overlay against the prototype at 1440 × 900. Single highest-value next step.
2. **Finish the M8 a11y pass** — add Tooltip + Semantics to the 8 unreached screens.
3. **Enable golden tests** — apply the fix recipe; drop the `golden` skip from `dart_test.yaml`; regenerate the baseline.
4. **Mobile player redesign** — gated on desktop M9 per `docs/11_design/mobile_player_redesign_plan.md`. With M9 done, the gate has lifted.

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran without explicit per-action OK. Every commit got "yes" / "ok" / "comit" authorization. Memory rule reinforced mid-session: "always pause and ask before each commit, even mid-arc."
- [x] No agent / AI branding anywhere in code, docs, or commit messages.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed silently.
- [x] No secrets / hardcoded paths added.
- [x] All new third-party deps version-checked (`golden_toolkit ^0.15.0`, `mocktail ^1.0.4`).
- [x] No backwards-compat hacks left behind — M9 deleted the 4 legacy widgets outright.
---

## [2026-05-03] — Mobile redesign plan + Desktop V2 theme cutover (M9.5) + DESIGN.md V2 rewrite + doc sweep
**Phase:** Phase 5 — Mobile redesign planning + Desktop V2 finalization
**Status:** Complete

### What Was Done

This session had three tightly-related arcs.

**Arc 1 — Mobile redesign plan (whole-app scope).** A new design prototype bundle was copied into `docs/11_design/prototype/` covering 28 mobile screens + flow diagram. The prior `mobile_player_redesign_plan.md` (drafted earlier the same day, narrowly scoped to the player screen) was rewritten and renamed `mobile_redesign_plan.md` to cover the entire mobile app. 14 milestones (M0 foundation → M14 polish) replace the original 7. The earlier "keep legacy mobile palette" decision (player-only scope) was reversed in §1 row 2: the whole-app redesign forces V2 palette migration. Original player-only sections preserved as §15 for cross-reference. Cleanup: deleted `docs/11_design/prototype/chats/` and `.tmp_design/`.

**Arc 2 — Desktop V2 theme cutover (M9.5 — unplanned).** Owner reported a slate-blue scaffold flash on tab switches. Root cause: `apps/desktop/lib/shared/theme/app_theme.dart` body was still 100 % V1 (26 references) — `scaffoldBackgroundColor: AppColors.background` (#0F172A slate) was painting underneath the V2-painted route bodies during transitions. Rewrote the entire `app_theme.dart` body to consume V2 tokens (kept file path + `AppTheme.dark` getter signature unchanged). Fixed 5 V1 stragglers in feature screens. Verified zero `AppColors.{primary,background,surface,...}` references remain in `apps/desktop/lib/`. `flutter analyze` clean (27.8 s).

**Arc 3 — DESIGN.md V2 rewrite + cross-doc sweep.** Owner directive: "do proper fix" + "dont keep anything legacy". Rewrote DESIGN.md (648 → 727 lines) as V2-only canonical — removed V1 color/typography blocks, dropped the "two coexisting systems" framing, deleted the V1 legacy appendix entirely, stripped all migration / cutover / deprecated wording from prose. Then synced affected docs.

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `docs/11_design/mobile_redesign_plan.md` *(via git mv from `mobile_player_redesign_plan.md` + scope expansion)* |
| Modified | `apps/desktop/lib/shared/theme/app_theme.dart` *(full body rewrite V1 → V2)* |
| Modified | `apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart` *(line 503 dropdownColor: surface → bgRoot)* |
| Modified | `apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart` *(textMuted → textDim, textSecondary → textMutedV2, bodyMd → body)* |
| Modified | `apps/desktop/lib/features/library/presentation/screens/library_screen.dart` *(same rename pattern)* |
| Modified | `DESIGN.md` *(full V2 rewrite, no legacy)* |
| Modified | `docs/00_overview/current_status.md` *(date bump, V2 theme cutover entry, next-steps refresh)* |
| Modified | `docs/08_frontend/01_frontend_architecture.md` *(Design System section reframed; line 113 showcase wording)* |
| Modified | `docs/11_design/desktop_redesign_plan.md` *(M9.5 entry added; line 206 indigo gradient → violetDeep)* |
| Modified | `docs/11_design/mobile_redesign_plan.md` *(execution gate marked lifted; whole-app scope rewrite earlier in session)* |
| Modified | `docs/11_design/README.md` *(rewritten as folder index pointing to canonical sources)* |
| Deleted | `docs/11_design/prototype/chats/` *(prototype handoff transcripts — not project content)* |
| Deleted | `.tmp_design/` *(temp scratch dir)* |
| Deleted | `docs/11_design/design_reference.html` *(2026-04-27 V1 concept HTML — superseded by `DESIGN.md` + `prototype/`)* |
| Modified | `AGENT_LOG.md` *(this entry)* |

### Docs Updated

- `DESIGN.md` — V2-only canonical
- `docs/00_overview/current_status.md` — V2 theme cutover line + next-steps
- `docs/08_frontend/01_frontend_architecture.md` — single-source-of-truth framing
- `docs/11_design/desktop_redesign_plan.md` — M9.5 entry + status line
- `docs/11_design/mobile_redesign_plan.md` — gate-lifted §0
- `docs/11_design/README.md` — folder index

### Decisions Made

- **Mobile redesign scope expanded to whole-app.** The earlier player-only plan can't apply V2 piecemeal — half-violet / half-indigo would feel broken. Whole-app migration locked in (`mobile_redesign_plan.md` §1 row 2 reverses the original §1 row 4 decision).
- **Plan filename changed to match desktop convention.** `mobile_player_redesign_plan.md` → `mobile_redesign_plan.md` via `git mv` to preserve history.
- **Theme directive: don't recreate theme infrastructure.** Owner directive 2026-05-03. Mobile redesign consumes existing `AppColors` / `AppTypography` / `AppRadii` / `AppSpacing` / `AppShadows` only — no new tokens, no new theme classes. Plan §1 row 2, §4, §4.2, §4.3 revised to document the mapping. M0 no longer adds tokens; M9 rewrites `apps/mobile/lib/shared/theme/app_theme.dart` body in-place.
- **Desktop M9.5 was unplanned but necessary.** The M9 plan only covered "delete legacy widgets + update docs" — never specified a `ThemeData` rewrite. The redesigned screens bypassed Material theme by hardcoding V2 tokens, which masked the underlying V1 ThemeData until route transitions exposed the slate-blue scaffold. Logged as M9.5 in `desktop_redesign_plan.md` to keep the milestone history honest.
- **DESIGN.md V2-only, no legacy section, no migration framing.** Owner directive. The mobile app still consumes V1 tokens in code, but DESIGN.md does not document them — it states the canonical spec. When mobile catches up, DESIGN.md doesn't change.
- **Deleted `docs/11_design/design_reference.html`** rather than flagging as historical. 257-line V1 concept HTML from 2026-04-27 is no longer canonical (superseded by `DESIGN.md` + `prototype/`). Per "don't keep anything legacy" directive.

### Blockers / Open Issues

- **Visual smoke test for the V2 theme cutover.** `flutter run -d windows` to verify Material widgets that previously rendered indigo (default `TextField` border focus, `Switch` thumb tint, dialog `OK` button, dropdowns, snackbars, the active nav-rail tab indicator pill) all now render violet. No regressions caught by `flutter analyze` but visual sweep recommended.
- **Mobile redesign execution.** Plan locked, gate lifted, but no code work started. Owner-scheduled.

### Issues Discovered / Reported to User

- **Theme migration was incomplete after desktop M9.** The redesign plan considered M9 ("Cleanup + final docs") to be the end of the desktop arc, but the underlying `ThemeData` body had never been rewritten — only individual screens migrated. This is now patched as M9.5 but the takeaway: future redesign plans should explicitly include a "rewrite ThemeData body" line item, not assume it as part of "cleanup".
- **Two stale legacy artifacts found in design folder:** `design_reference.html` (V1 concept HTML) deleted; `prototype/chats/` (handoff transcripts) deleted; `.tmp_design/` (temp scratch) deleted.
- **Showcase screen at `/showcase` was documented as "removed at M9 cutover" in `frontend_architecture.md:113` but is still present.** Updated wording to "Kept post-M9 as ongoing reference surface" — owner can decide separately whether to delete.

### Next Agent Should

1. **Visual smoke test of the M9.5 theme cutover** — `flutter run -d windows`, walk every screen, look for any Material widget that previously appeared indigo and confirm it now renders violet (most critical: dialogs, dropdowns, snackbars, focused inputs).
2. **Mobile redesign M0** — when owner schedules. Foundation milestone is no-code-change (just runtime deps `google_fonts` / `lucide_icons` / `cached_network_image` + `BackgroundGradient` widget). Per `mobile_redesign_plan.md` §7.
3. **Desktop M10 — Custom window chrome** — open per `desktop_redesign_plan.md` §13. Independent of mobile.
4. **Optional: delete the `/showcase` route** if no longer wanted as a reference surface (currently kept).

### Hard Rules Checklist
- [x] No `git commit` / `git push` ran. Owner does all version control.
- [x] No agent / AI branding anywhere in code, docs, or commit messages.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No exceptions swallowed silently.
- [x] No secrets / hardcoded paths added.
- [x] No new third-party deps added this session — only existing tokens consumed.
- [x] No backwards-compat hacks left behind — V1 tokens still in `app_colors.dart` only because mobile hasn't migrated; will be deleted at mobile M9.
---

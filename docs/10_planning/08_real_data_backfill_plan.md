# Real-Data Backfill Plan — Mobile

> **Category:** Planning
> **Status:** Decisions locked 2026-05-03 — Phase A starts after the §8 pre-flight.
> **Goal:** Replace every `MockData` reference in `apps/mobile/lib/` with real backend-driven data, then delete `apps/mobile/lib/shared/data/mock_data.dart`.
> **Scope:** Mobile only (desktop already uses real data; web landing has no consumer surface). Server endpoints listed here are net-new or extensions of existing ones.

---

## 1. Why this exists

The mobile redesign (M0–M9) shipped UI-first with mock fixtures so screens could be designed and tested without waiting on backend work. Every screen except Library + Notifications currently consumes `MockData`. Shipping v1 with mock data is dishonest — the user's first scan won't populate the Home rails, Detail screens won't show their library's metadata, etc.

This plan inventories every mock surface, defines the real-data path, phases the work, and locks the cutover steps that delete `mock_data.dart` for good.

**Cross-references:**
- [`docs/11_design/mobile_redesign_plan.md`](../11_design/mobile_redesign_plan.md) §6.1 already deferred Quality + Episodes + Cast as backend tickets.
- [`docs/04_api/01_api_contracts.md`](../04_api/01_api_contracts.md) is the canonical API contract — every new endpoint here lands there.
- [`docs/03_data/02_database_schema.md`](../03_data/02_database_schema.md) — schema additions land there.
- [`05_ship_readiness.md`](./05_ship_readiness.md) lists "Mobile UI redesign" under polish gaps but treats real-data as its own concern (this doc).

---

## 2. Inventory — every mock surface

| Surface | Mock entry | Real-data path | Server work | Mobile work | Phase |
|---------|-----------|----------------|-------------|-------------|-------|
| Pairing flow — display name + email + UX hardening | n/a (currently no display_name capture; bearer-token-clear → no graceful re-pair) | Pairing flow accepts `display_name` (defaulted to platform-derived "iPhone 15 Pro" / "Pixel 8") + optional `email`. Re-pair from the same `client_id` should update fields + reissue token, not duplicate the row. Polling UX shows live status (Requested → Approved / Rejected / Timed out) with retry on network drop. Lost-token-recovery: if user opens app and `secureStorage.getAuthToken()` returns null but `client_id` exists, kick to a "Reconnect to your server" screen instead of full re-discovery. | Schema migration (add `display_name` + `email` columns to `clients` table). `POST /auth/request-pair` accepts the new fields. Re-pair handling: same `client_id` updates the row instead of insert; new `client_id` creates a new row. Optional: `POST /auth/heartbeat/{client_id}` for last-active surfacing on the desktop Clients screen. | Pairing screen captures `display_name` (editable, defaulted), optional `email` with skip. Polling UI surfaces `PairCubit` state machine clearly — Requested / Pending / Approved / Rejected / TimedOut / NetworkError; retry button on the last three. Lost-token-recovery path: app boot detects `client_id` present + token absent → routes to a "Reconnect" screen that re-uses the same `client_id` with a new pair request. | A |
| Library tab — grid + filter chips | `MockMediaItem` (in screen) | Existing `LibraryRepository.getLibraries()` returns library *containers*, not flat media. Reverts to the legacy real-data flow with V2 chrome on top. | None | Rewire `library_screen.dart` to consume `LibraryBloc`; keep V2 filter chips + grid/list toggle. | A |
| Detail screen — basic fields (title, year, rating, duration, poster) | `MockData.findById` returns rich `MockMediaItem` | Existing `GET /api/v1/files/{id}` returns title, year, duration, poster_url, overview (synopsis). Already populated via TMDB scan. | None — endpoint shape is sufficient. | New `DetailCubit` consuming `LibraryRepository.getFile(id)`; `findById` deleted. | A |
| Home tab — Recently added rail | `MockData.recentlyAdded` (8 items) | New endpoint `GET /api/v1/files/recent?limit=N` (or sort param on existing `/files`). Backed by `media_files.created_at DESC`. | New endpoint or extend `/files` with `sort=recent_desc&limit=N`. | New `RecentCubit`; rail consumes the cubit. | A |
| Profile tab — display name + email | Hardcoded "Alex Kowalski" / "alex@fluxora.io" | Pairing flow already accepts `device_name`. Add `display_name` + `email` to clients table; persist on pair-approve. New endpoint `GET /api/v1/clients/me`. | Schema migration + new endpoint. | Extend pairing screen to capture display_name + email; profile screen reads from `/clients/me`. | A |
| Profile tab — plan badge | Hardcoded "PLUS MEMBER" | The operator's tier is already on `GET /api/v1/info` (`subscription_tier`). Mobile already calls `/info` post-pair. Just surface it in profile. | None — `/info` already has the field. | Profile screen reads tier from cached `/info` response. | A |
| Home tab — Continue watching rail | `MockData.continueWatching` (5 items) | New endpoint `GET /api/v1/clients/me/continue-watching?limit=N`. Joins `stream_sessions` (most recent per file) with `media_files`, filtered to `last_progress_sec > 0 AND last_progress_sec < duration_sec * 0.95`. | New endpoint + service method. | New `ContinueWatchingCubit`; rail consumes it. | B |
| Search tab — query → results | `MockData.continueWatching/trending/recentlyAdded` filtered client-side | New endpoint `GET /api/v1/files/search?q=...&limit=N`. SQL `LIKE` on `title` + `overview` for v1; FTS5 deferred. | New endpoint + service method. | New `SearchCubit`; results render same as M3. | B |
| Search tab — recent searches | `MockData.recentSearches` | Local-only — store last 10 queries in `flutter_secure_storage` (or shared_preferences). | None | Add `RecentSearchesStore` (mobile-local). | B |
| Search tab — trending searches | `MockData.trendingSearches` | Drop the rail. v1 has no aggregated query telemetry; trending search isn't worth a backend pipeline. | None | Delete the trending-searches block from `search_screen.dart`. | B |
| Profile tab — stats (Hours / Movies / Shows) | Hardcoded "284 / 62 / 18" | New endpoint `GET /api/v1/clients/me/stats`. Aggregates from `stream_sessions` joined with `media_files.kind`. | New endpoint + service method. | Profile screen consumes `/clients/me/stats`. | B |
| Detail screen — synopsis | `MockMediaItem.synopsis` | Already in `media_files.overview` from TMDB. Just render it. | None | Rendered as part of Phase A's Detail wiring. | A |
| Detail screen — cast | `MockData.findById(id).cast` (4 entries) | New `media_credits` table populated from TMDB `/movie/{id}/credits` and `/tv/{id}/credits` at scan time. New endpoint `GET /api/v1/files/{id}/credits` returns cast + crew. | Schema migration (`media_credits` table) + TMDB-client extension + scan-time persistence + new endpoint. | Detail screen renders cast rail from real credits. | C |
| Detail screen — crew | Same as cast | Same as cast — `media_credits` covers both. | Same as cast. | Same as cast. | C |
| Detail screen — similar titles | `MockMediaItem.similarIds` | New `media_similar` join table populated from TMDB `/movie/{id}/recommendations` and `/tv/{id}/recommendations`. New endpoint `GET /api/v1/files/{id}/similar`. | Schema migration (`media_similar`) + TMDB-client extension + scan-time persistence + new endpoint. **Note:** TMDB recommendations point at TMDB IDs that may not be in the user's library — server should filter to in-library IDs only. | Detail screen renders similar-titles rail from real data. | C |
| Detail screen — Quality / HDR badges | `MockMediaItem.qualityBadge` | Already in `media_files` via FFprobe at scan: `width`, `height`, `codec_name`, `hdr_format`. Compose "4K HDR" / "1080p" / etc. client-side. | Verify `media_files` row has the FFprobe fields populated; add if missing. | Detail screen + rails compose the badge from real fields. | A (if fields exist) / G (if migration needed alongside the quality / direct-play work) |
| Player — quality switching | n/a today (HLS single-variant) | Server emits an HLS *master* playlist with multiple variants (e.g. 1080p / 720p / 480p) — `media_kit` then switches automatically. Owner / scan time picks the variants. New endpoint stays at `GET /stream/{file_id}` but the playlist body changes from a media playlist to a master. | `ffmpeg_service.py` ladder support — spawn N FFmpeg processes (one per variant) writing to the same session dir, build the master playlist that lists each. **Defer:** picker UI + server-side per-variant CRF tuning. v1 ladder = source-aware default (4K → 1080p+720p+480p; 1080p → 1080p+720p+480p; 720p → 720p+480p; below → single-variant). | New `QualitySheet` populated from `Player.state.tracks.video` (media_kit exposes the master's variants). Picker dispatches `Player.setVideoTrack(...)` — purely client-side switching against the master playlist server already serves. | G |
| Player — Direct play (source) | n/a today (always transcoded to HLS) | New endpoint `GET /api/v1/files/{file_id}/source` returns the original file as a streamed HTTP response (`Range`-header capable) under bearer auth. No transcoding, no FFmpeg subprocess. Server checks `media_files.codec_name` + container against an "always-direct-playable" allowlist (e.g. `mp4 + h264 + aac`); falls back to recommending HLS if the file is a format the mobile player can't decode natively. | New endpoint + content-type + Range support + bearer-auth gate. | New `DirectPlayer` path in `PlayerCubit` — try direct first when `file.codec_name` is in the allowlist; fall back to existing HLS startStream on first decode error. Quality sheet adds a "Source" / "Auto" toggle (Source = always direct play; Auto = pick based on bandwidth + codec). | G |
| Episodes screen — seasons + episodes | `MockData.findById(showId).seasons` | **No new `episodes` table.** Each episode file is already a regular `media_files` row (TMDB scan populates `tmdb_id`, `title`, etc. per file). A "show" is computed by grouping `media_files` rows that share the same `tmdb_show_id`. New endpoint `GET /api/v1/shows/{tmdb_show_id}/episodes` runs `SELECT * FROM media_files WHERE tmdb_show_id = ? ORDER BY season_number, episode_number`. **Migration prerequisite:** verify `media_files` already carries `tmdb_show_id` + `season_number` + `episode_number`; if any are missing, one migration adds them and the next library scan back-fills via TMDB lookup. | Verify columns exist (likely yes — TMDB scan needs season/episode). If missing, schema migration + TMDB-client tweak to record them on TV scans. New endpoint `GET /shows/{tmdb_show_id}/episodes`. New endpoint `GET /shows/{tmdb_show_id}` for show-level metadata (poster, name, overview, year — derived from any episode row's TMDB show parent record). | Episodes screen consumes the new endpoint; tapping an episode dispatches `PlayerCubit.startStream(episode.media_files.id)` — same code path as movie playback. Show-detail route reuses the existing detail screen with episode rail instead of "Play" button. | D |
| Downloads tab — full surface | `MockData.downloads` (6 items) + `storageUsedGb` / `storageTotalGb` constants | Mobile-local download manager with sqflite-backed queue + `flutter_downloader` plugin for background downloads + `disk_space_plus` for storage indicator. Server endpoint: `GET /api/v1/stream/{file_id}/download` returns the underlying media file directly (skip transcode for offline copy — mobile decodes locally). | New `/stream/{id}/download` endpoint (or repurpose existing direct-file URL). | Major mobile feature: `DownloadManager` service + `DownloadsCubit` + sqflite migration + plugin integration + per-row state machine + resume-on-restart. | E |
| Home tab — Trending now rail | `MockData.trending` (8 items) | New endpoint `GET /api/v1/files/trending?days=7&limit=N`. Aggregates `stream_sessions.started_at >= now - 7 days`, counts per `file_id`, returns top N with `media_files` join. | New endpoint + service method. **Note:** single-tenant servers may have only one client streaming — "trending" is meaningful only with 2+ paired clients. v1 single-user case is degenerate (it's just "what I watched recently"). | New `TrendingCubit`; rail consumes it OR rail is hidden when there are <2 paired clients. | F (optional) |

---

## 3. Phasing

Phases A–F ordered by **effort + dependency**. Each phase is a self-contained shipment that can land independently. Phase F is optional.

| Phase | Scope | Server work | Mobile work | Mock entries deletable after phase |
|-------|-------|-------------|-------------|-----------------------------------|
| **A — Quick wins + pairing hardening** | Library, Detail basics, Recently-added, Profile name/email/plan, **pairing UX** | New `GET /files/recent` + `GET /clients/me`; schema migration adding `display_name` + `email` to `clients` table; pairing flow accepts the new fields + handles re-pair from same `client_id` cleanly | `library_screen` rewires to `LibraryBloc`; new `DetailCubit`, `RecentCubit`; `findById` removed; profile screen reads real fields. **Pairing screen rebuild** — display_name (editable, defaulted) + optional email + clear state-machine UI + retry-on-network-drop + lost-token-recovery "Reconnect" route | `MockMediaItem.recentlyAdded`, `MockMediaItem.findById`, profile hardcoded fields |
| **B — Medium effort** | Continue-watching, Search, Profile stats | New `GET /clients/me/continue-watching`, `GET /files/search` (SQL `LIKE` on `title`+`overview` for v1; FTS5 deferred to v2 — same endpoint contract, only the WHERE clause changes), `GET /clients/me/stats` | `ContinueWatchingCubit`, `SearchCubit` + `RecentSearchesStore`, profile stats wiring; trending-searches rail deleted from search screen | `MockData.continueWatching`, `MockData.trending` (search consumer), `recentSearches`, `trendingSearches`, profile stats |
| **C — Rich Detail** | Cast, crew, similar titles | Migrations: `media_credits`, `media_similar`; TMDB credits + recommendations integration in `tmdb_client.py`; scan-time persistence; new endpoints `GET /files/{id}/credits` + `/similar` | Detail screen consumes real credits + similar; `MockCastMember` deleted | `MockCastMember`, `MockMediaItem.cast`/`crew`/`similarIds` |
| **D — Episodes** | Seasons + episodes for TV shows — **schema-light path** | Verify `media_files` already has `tmdb_show_id` + `season_number` + `episode_number`. If yes: just expose `GET /shows/{tmdb_show_id}` + `GET /shows/{tmdb_show_id}/episodes` (both pure SQL queries — no new table). If no: one small migration adds the columns, then the next scan back-fills from TMDB. No new `episodes` table; episode files stay regular `media_files` rows. | Episodes screen consumes the new endpoint; show-detail route reuses the existing detail screen with episode rail instead of "Play" button. Tapping an episode dispatches `PlayerCubit.startStream(episode.media_files.id)` — same playback code path as movies. | `MockSeason`, `MockEpisode`, `MockMediaItem.seasons` |
| **E — Downloads** *(hidden in v1)* | Mobile download manager + storage indicator + offline playback. **Hidden behind a tab-removal in v1**; ship as v1.1+. | Verify direct-file URL works under bearer auth (or new endpoint `GET /stream/{id}/download`); document offline-playback constraints (no DRM) | When ready: new `download_manager.dart` service + `DownloadsCubit` + sqflite migration + `flutter_downloader` + `disk_space_plus` plugins + per-row state + resume + offline player path. **For v1:** Downloads tab is removed from `FluxBottomTabs` registry; `Routes.downloads` deleted; `downloads_screen.dart` left in tree but unreferenced. | `MockDownload`, `MockDownloadStatus`, `MockData.downloads`, `storageUsedGb`/`storageTotalGb` (deleted at v1 ship even though E is post-v1, since the tab is hidden) |
| **F — Trending** *(skipped for v1)* | Trending-now rail removed entirely from Home. Single-tenant single-user trending is degenerate. Not worth a backend pipeline. | None | Delete the trending rail from `home_screen.dart`; `TrendingCubit` never built | `MockMediaItem.trending` |
| **G — Quality switching + Direct play** | Multi-variant HLS ladder (server) + Source/Auto picker (mobile) | `ffmpeg_service.py` ladder support — emit an HLS *master* playlist with multiple variants from one source. New `GET /files/{file_id}/source` returns the original file as a streamed `Range`-capable HTTP response under bearer auth (no transcoding). v1 ladder = source-aware default (4K → 1080p+720p+480p; 1080p → 1080p+720p+480p; 720p → 720p+480p; below → single-variant). Allowlist for direct-play codecs (e.g. `mp4 + h264 + aac`). | New `QualitySheet` populated from `Player.state.tracks.video` (media_kit auto-exposes the master's variants). Picker dispatches `Player.setVideoTrack(...)`. **Direct play:** `PlayerCubit` tries `/source` first when codec is allowlisted, falls back to HLS on decode error. Source / Auto toggle in the quality sheet (Source = always direct; Auto = pick by codec + bandwidth). | n/a — no mock to delete; this is new functionality (quality + source were never mocked) |

After Phases A + B + C + D land (and Trending dropped + Downloads tab hidden + Quality/Direct-play folded into G): **`apps/mobile/lib/shared/data/mock_data.dart` deleted**, all imports removed, `MockGradients` (still used by `flux_mini_player.dart`'s placeholder + the player overlay) lifted to `shared/widgets/gradients.dart`.

Phase G is independent of the mock-data deletion — it ships net-new functionality (quality switching + direct play) and doesn't reference any mock fixtures.

---

## 4. Effort estimate

Rough estimate in agent sessions (one session ≈ a Claude Code session of 1–4 hours):

| Phase | Sessions | Notes |
|-------|----------|-------|
| A | 2–3 | Mobile rewiring + one new endpoint + small migration. **Bumped from 1–2 because pairing UX hardening adds the state-machine rebuild + Reconnect route.** |
| B | 2–3 | Three new endpoints + three cubits; SQL aggregation logic for stats |
| C | 3–5 | TMDB API extension + 2 migrations + 2 endpoints + scan-time persistence (touches the existing scan flow) |
| D | 1–2 | **Re-scoped from 5–8 to 1–2 sessions.** No new schema (episodes are regular `media_files` rows). Two pure-SQL endpoints + show-detail rendering reuses the existing detail screen. |
| E | 8–12 | Full download manager is its own feature; mobile-side state machine, plugin integration, offline-playback path. Could grow further if iOS background-download quirks bite. **Hidden in v1; ships as v1.1+.** |
| F | 0 | **Dropped for v1.** Single-tenant single-user trending is degenerate; rail removed from Home. Not worth a backend pipeline. |
| G | 4–6 | Multi-variant HLS ladder is FFmpeg config + master-playlist generation; direct-play is a new endpoint + mobile fallback chain. Quality picker + Source toggle UI on top. |

**Recommended ship line for v1:** **A + B + C + D + G** = the full mock cleanup + rich detail + episodes + quality/direct-play. ~12–19 sessions. With these in, mobile is honest end-to-end:
- Library + Detail (basic + cast + crew + similar) + Episodes + Recently-added + Continue-watching + Search + Profile + Notifications all real
- Quality switching + Source play work in the player
- Downloads tab hidden (re-enabled when E lands as v1.1)
- Trending rail removed entirely
- `mock_data.dart` deleted

Without G the redesign still holds together — quality / source are net-new functionality, not mock-replacements. G can slip to v1.1 if the ladder + direct-play work bites.

---

## 5. Decisions locked (2026-05-03)

| # | Decision | Locked answer |
|---|----------|---------------|
| 1 | **Search backend** | **SQL `LIKE` on `title` + `overview` for v1.** Endpoint contract `GET /files/search?q=...` stays identical when v2 swaps in FTS5 — only the WHERE clause changes. v2 migration is one-shot: create FTS virtual table, populate from existing rows, swap query. Zero mobile-side work for the upgrade. |
| 2 | **Profile per-client endpoint** | **New `GET /clients/me`.** Returns `{display_name, email, tier, paired_at, last_active}`. `/info` stays as the public-server-identity surface. |
| 3 | **Trending rail** | **Drop permanently for v1.** Single-tenant single-user trending is degenerate. Rail removed from `home_screen.dart`; no `TrendingCubit` ever built; Phase F deleted from the roadmap. |
| 4 | **Downloads scope** | **Hide tab in v1.** `FluxBottomTabs` registry shrinks to 4 (Home / Library / Search / Profile) for v1. `Routes.downloads` removed. `downloads_screen.dart` stays in tree but unreferenced — re-enabled when Phase E (download manager) ships in v1.1+. |
| 5 | **Episodes in v1** | **Build Phase D — schema-light approach.** Episode files are already regular `media_files` rows; "show" is `WHERE tmdb_show_id = ?`. Only adds 2 pure-SQL endpoints. Re-scoped from 5–8 sessions to 1–2. **The user asked: "if the file have ep stat then only it will work right?"** — yes, exactly. The existing TMDB scan should already record episode metadata per file; if columns are missing one small migration adds them. |
| 6 | **Quality badges + switching + direct play** | **All three in v1.** Badges (Phase A — verify fields exist) + multi-variant HLS ladder + Direct-play / Source toggle land together as **Phase G**. Quality switching uses `media_kit`'s built-in master-playlist variant API; Direct-play = new `GET /files/{id}/source` endpoint that streams the original file under `Range` headers when codec is in the allowlist (`mp4 + h264 + aac` for v1). |
| 7 | **Pairing UX** | **Hardened in Phase A.** Display_name editable + defaulted to platform-derived ("iPhone 15 Pro" / "Pixel 8"); email optional with skip. Pairing screen rebuilt with explicit state machine: Requested → Pending → Approved / Rejected / TimedOut / NetworkError; retry button on the last three. Lost-token-recovery path: if `secureStorage.client_id` exists but `auth_token` is null, route to a "Reconnect to your server" screen that re-uses the same `client_id` (server updates the row instead of duplicating). Re-pair from the same `client_id` updates `display_name`/`email` and reissues a token, never duplicates. |
| 8 | **MockGradients** | **Lift to `shared/widgets/gradients.dart`.** Used by `flux_mini_player` placeholder + multiple poster fallbacks; gradient placeholders look intentional vs. solid-violet which reads as broken. Lift before deleting `mock_data.dart`. |

---

## 6. Cutover ritual (per phase)

Each phase ends with a focused commit pair:

1. **Server commit:** new endpoint(s) + migration(s) + tests.
2. **Mobile commit:** cubit(s) wired, mock entries deleted, screens rewired. `flutter analyze` clean × all 3 packages; mobile tests still pass.

After each cutover, append an entry to `AGENT_LOG.md` listing the deleted `MockData.*` symbols. Final cleanup commit (post-Phase F or post-decision-that-F-is-out-of-scope):

3. **`feat(mobile): delete mock_data.dart — all rails on real data`** — removes the file + every remaining import, lifts `MockGradients` to `shared/widgets/gradients.dart` if still needed, updates `frontend_architecture.md` and `folder_structure.md` to drop the mock-data references.

---

## 7. What this plan does NOT do

- **Does not redesign UI surfaces.** Real data flows through the existing M0–M9 screens unchanged. The visual contract is locked.
- **Does not introduce new mock data.** No transitional fixtures, no "test data when offline" mode. If the endpoint is missing, the surface renders an empty state with a clear "Coming soon" or "No data yet" message, not a fake.
- **Does not block on multi-tenant work.** Single-tenant v1 is the target. Trending is dropped entirely (decision §5 row 3) — no analytics pipeline.
- **Does not add analytics / telemetry.** No new tracking pipeline. Continue-watching is computed from existing `stream_sessions`, profile stats are computed from the same.
- **Does not touch Notifications.** Already real (M8).
- **Does not migrate to FTS5.** Decision §5 row 1 — SQL `LIKE` for v1; FTS5 is a v2 task whose endpoint contract is already locked.
- **Does not add a new `episodes` table.** Decision §5 row 5 — episode files stay regular `media_files` rows; show-detail is an aggregate query.

---

## 8. Pre-flight findings (2026-05-03 — done)

Five reads completed against `main` at commit `8ae0388`. Findings below — Phase A scope is now frozen.

### 8.1 `media_files` row shape today

Has: `id`, `path`, `name`, `extension`, `size_bytes`, `duration_sec`, `library_id`, `tmdb_id`, `title`, `overview`, `poster_url`, `last_progress_sec`, `created_at`, `updated_at`.

**Missing — Phase A migration must add:**
- `width`, `height` (FFprobe — for quality badges + direct-play allowlist)
- `codec_name`, `hdr_format` (FFprobe — for direct-play allowlist + quality "4K HDR" composition)
- `tmdb_show_id`, `season_number`, `episode_number` (pre-folded for Phase D so we ship one schema bump, not two)

### 8.2 `clients` table today

Has: `id`, `name` (functions as display_name — `POST /auth/request-pair` populates from `device_name`), `platform`, `last_seen`, `is_trusted`, `auth_token`, `status` (added in migration 003).

**Missing — Phase A migration must add:**
- `email` (optional, captured during pairing per decision §5 row 7)
- `paired_at` (TEXT, ISO timestamp — surfaces "Paired Mar 15" on the desktop Clients screen + on `/clients/me` response)

`name` already serves as display_name; **no rename needed** — just route the new pairing-flow `display_name` field into the existing column.

### 8.3 Legacy `LibraryRepository.getLibraries()` mobile compile path

The repo + cubit are intact post-M9 token cutover; `library_repository_impl.dart` still compiles cleanly. The M3 mock-redesign of `library_screen.dart` displaced the BLoC consumer but left the repo + bloc files untouched. Phase A's mobile work just rewires the screen to `LibraryBloc`; no repo / domain churn.

### 8.4 TV episode columns on `media_files`

**None present today.** The TMDB scan service records the per-file `tmdb_id` (which IS the episode's TMDB ID for TV), `title`, `overview`, `poster_url`, but does not persist the parent show ID, season number, or episode number. Phase A's migration adds the three columns; Phase D's TMDB-scan tweak back-fills them on next library scan (or adds a one-time back-fill migration step that re-queries TMDB for existing TV files).

### 8.5 Existing pairing endpoints + state machine

`apps/server/routers/auth.py` exposes:
- `POST /auth/request-pair` — accepts `{client_id, device_name, platform, app_version}`. Rate-limited `5/minute`. ✅ ready to extend with `display_name` (rename of `device_name`?) + optional `email`.
- `GET /auth/status/{client_id}` — polling. Returns `{status: "pending_approval" | "approved" | "rejected", auth_token?: string}`. Token is returned **once** on first approved poll then popped from in-memory `_pending_tokens` dict. ✅ structure is fine.
- `POST /auth/approve/{client_id}`, `POST /auth/reject/{client_id}`, `DELETE /auth/revoke/{client_id}` — localhost-only. ✅

**Bugs found that Phase A must fix:**

1. **Re-pair from the same `client_id` is broken.** `POST /auth/approve/{client_id}` returns `409 Conflict` if the client's `status` is not `pending`. So a mobile user who reinstalls the app and tries to re-pair (same persisted `client_id` in their secure-storage backup, or restored from iCloud / Google Backup) hits a 409 the operator can't resolve from the desktop UI today. **Phase A fix:** when `POST /auth/request-pair` arrives for a `client_id` that already exists in the `clients` table:
   - if `status = pending`: no-op (stay pending; refresh `last_seen`).
   - if `status = approved` or `rejected`: **reset `status = pending`, clear the prior `auth_token`, refresh `name` + `email`, drop any cached `_pending_tokens` entry.** Operator sees a fresh "re-pair request from {device}" in the desktop Clients screen; old token is dead immediately.
   This is a security improvement too — a stolen token whose owner reinstalls the app forces re-approval rather than silently retaining access.

2. **Pending tokens are in-memory.** `_pending_tokens: dict[str, str]` in `auth.py` lines 159–167. If the server restarts between approve and the first /auth/status poll, the raw token is lost and the client never gets it. v1 single-tenant home server — the operator can just re-approve. **Phase A fix:** out of scope; flag in `04_manual_tasks.md` as a known limitation.

3. **No lost-token-recovery on the mobile side.** If `secureStorage.auth_token` returns null but `client_id` is still present, the app currently routes back to `/connect` (full re-discovery), losing the user's server URL too. **Phase A fix:** new "Reconnect to your server" route (`Routes.reconnect`) — reuses the same `client_id` against the same `serverUrl` (both in secure storage), fires a fresh `POST /auth/request-pair`, polls `/auth/status`. Falls back to `/connect` only if `serverUrl` is also gone.

`apps/mobile/lib/features/auth/presentation/cubit/pair_cubit.dart` was not re-read in this pre-flight (decision deferred to Phase A — exact polling backoff numbers are tuning, not scope-affecting).

---

## 9. Phase A scope frozen

After §8 findings, Phase A is exactly:

### 9.1 Server side

**Migration `016_media_quality_episodes_client_email.sql` (one schema bump):**

```sql
-- FFprobe fields (quality badges + direct-play allowlist)
ALTER TABLE media_files ADD COLUMN width        INTEGER;
ALTER TABLE media_files ADD COLUMN height       INTEGER;
ALTER TABLE media_files ADD COLUMN codec_name   TEXT;
ALTER TABLE media_files ADD COLUMN hdr_format   TEXT;

-- TV episode aggregation (pre-folded for Phase D — one schema bump for both)
ALTER TABLE media_files ADD COLUMN tmdb_show_id   INTEGER;
ALTER TABLE media_files ADD COLUMN season_number  INTEGER;
ALTER TABLE media_files ADD COLUMN episode_number INTEGER;

-- Per-client profile fields
ALTER TABLE clients ADD COLUMN email     TEXT;
ALTER TABLE clients ADD COLUMN paired_at TEXT;

-- Back-fill paired_at for existing rows
UPDATE clients
   SET paired_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
 WHERE paired_at IS NULL;

-- Index for tmdb_show_id lookups (Phase D /shows/{id}/episodes)
CREATE INDEX IF NOT EXISTS idx_media_files_tmdb_show_id ON media_files(tmdb_show_id);
```

**FFprobe persistence:** extend `services/ffmpeg_service.py` (or wherever scan-time probing lives) to record `width`/`height`/`codec_name`/`hdr_format` from FFprobe output. Migrate via a re-scan; existing rows stay null until the next scan touches them.

**Auth re-pair fix:** `services/auth_service.create_pair_request()` handles the same-`client_id` case per §8.5 bug 1.

**Auth router:** `POST /auth/request-pair` accepts optional `email` field on `PairRequestBody`; `display_name` is the existing `device_name` field (rename in the Pydantic model for clarity but keep backwards-compat).

**New endpoints:**
- `GET /api/v1/files/recent?limit=N` — bearer-token-auth; `SELECT * FROM media_files ORDER BY created_at DESC LIMIT ?`. Default limit 20, max 50.
- `GET /api/v1/clients/me` — bearer-token-auth; resolves the client from the bearer token, returns `{id, display_name (=name), email, platform, paired_at, last_seen, tier}`. `tier` is read from `user_settings.subscription_tier`.

**Tests:** migration applies cleanly on a fresh DB and on a DB at `015_extended_settings`. New endpoints have happy-path + auth-failure tests. Re-pair flow has a test covering the new same-`client_id` reset behaviour. Server suite stays green.

### 9.2 Mobile side

**Library tab:** `library_screen.dart` rewires to `LibraryBloc.add(LibraryStarted())`. Filter chips + grid/list toggle stay (chrome unchanged); the underlying data switches from `MockData.continueWatching/trending/recentlyAdded` to `LibraryBloc`'s state. `MockMediaItem` references in this screen go to zero.

**Detail screen:** new `DetailCubit` consuming `LibraryRepository.getFile(id)`. Existing `/files/{id}` endpoint already returns title / overview / duration / poster / `last_progress_sec` (= `resume_sec`). Quality badge composes from `width`+`height`+`hdr_format` after the migration back-fills. Cast / crew / similar / synopsis-rich-text rails delete (those are Phase C). Episodes button delete (re-added in Phase D once `/shows/{id}/episodes` lands).

**Recently-added rail:** new `RecentCubit` consuming `GET /files/recent`. Home tab rewires the third rail to it.

**Profile tab:** reads `display_name`, `email`, `tier` from `GET /clients/me`. Stats row (Hours / Movies / Shows) — empty-stated until Phase B's `/clients/me/stats`. Hardcoded "Alex Kowalski" / "alex@fluxora.io" / "PLUS MEMBER" go away.

**Pairing rebuild:** `pairing_screen.dart` rebuilt with explicit state-machine UI:

| State | UI |
|-------|----|
| Editing | display_name field (editable, defaulted to platform-derived "iPhone 15 Pro" / "Pixel 8" / "Galaxy S24"); optional email field with skip; Pair button. |
| Requested | Spinner + "Waiting for approval on the server…" + Cancel button. Polls every 2 s with backoff to 5 s after 30 s. |
| Approved | Brief check-mark animation → `context.go(Routes.home)`. |
| Rejected | Red icon + "The server owner rejected this request." + Try again button (returns to Editing). |
| TimedOut (60 s no response) | Amber icon + "Server didn't respond — check it's running and on the same network." + Retry button. |
| NetworkError | Same UX as TimedOut with the underlying error message. |

**Lost-token-recovery route:** new `Routes.reconnect = '/reconnect'`. Boot-time guard in `app_router.dart` `_guardRedirect` detects `client_id != null && auth_token == null` and routes to `/reconnect`. Reconnect screen reuses the existing `serverUrl` + `client_id` and triggers a fresh `request-pair`. If `serverUrl` is also null, falls through to `/connect`.

**`mock_data.dart` deletions after Phase A:**
- `MockMediaItem.recentlyAdded` (Recent rail now real)
- `MockMediaItem.findById` (Detail uses real `getFile`)
- `MockMediaItem.continueWatching` is **kept** for Phase B (used by Home + Search; deleted at Phase B cutover)

**Tests:** mobile suite stays at 27. Goldens not introduced this phase (M14 polish).

### 9.3 Scope explicitly NOT in Phase A

- `MockData.continueWatching` deletion → Phase B
- `MockData.trending` (search consumer) deletion → Phase B
- Detail cast / crew / similar → Phase C
- Episodes button + `/episodes/:id` route → Phase D
- Downloads tab presence → Phase E (hidden in v1; tab removal is its own small commit, can land alongside Phase A or as standalone)
- Quality switcher + Direct-play UI → Phase G
- `MockGradients` lift → final cleanup commit after all data phases

### 9.4 Phase A delivery — proposed shape

3 commits:

1. `feat(server): migration 016 + FFprobe persistence + recent + clients/me + re-pair fix` — server-side everything in §9.1.
2. `feat(mobile): Phase A real-data wiring (Library + Detail + Recent + Profile basics)` — mobile §9.2 except pairing.
3. `feat(mobile): pairing UX rebuild + lost-token Reconnect route` — pairing-specific to keep the diff focused.

After commit 3 lands and CI passes: Phase B can start cleanly. Mock entries deleted by Phase A: `MockMediaItem.recentlyAdded` + `MockMediaItem.findById` + the profile hardcoded fields.

---

## 10. Cross-references for the next agent

- This plan: §1 goal, §2 inventory, §3 phases, §5 locked decisions, §8 pre-flight findings, §9 frozen Phase A scope.
- [`docs/04_api/01_api_contracts.md`](../04_api/01_api_contracts.md) — every new endpoint lands there at commit time.
- [`docs/03_data/02_database_schema.md`](../03_data/02_database_schema.md) — migration 016 lands there at commit time.
- [`docs/06_security/01_security.md`](../06_security/01_security.md) §"Pairing Flow" — re-pair fix must be reflected.
- [`apps/server/routers/auth.py`](../../apps/server/routers/auth.py) — re-pair fix lands here + `models/client.py` for the optional `email` field.
- [`apps/server/services/auth_service.py`](../../apps/server/services/auth_service.py) — same-`client_id` reset logic lands here.
- [`apps/mobile/lib/features/auth/presentation/screens/pairing_screen.dart`](../../apps/mobile/lib/features/auth/presentation/screens/pairing_screen.dart) — full rebuild.
- [`apps/mobile/lib/core/router/app_router.dart`](../../apps/mobile/lib/core/router/app_router.dart) — adds `Routes.reconnect`.

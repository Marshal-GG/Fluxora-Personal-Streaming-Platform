# Fluxora — Agent Log Archive 12

> **Archived:** 2026-05-14
> **Contents:** Entries from 2026-05-09 through 2026-05-14, covering the plan-18 library transcode pipeline, plan-19 close-out + sharp-edge fixes, plan-20 auto streaming mode + course corrections, plan-21 client-side audio decoding, and M14 mobile redesign closeout (polish + a11y + golden tests).

---

## Summary

### 2026-05-09 — Seek-restart scrubber regressions + library transcode plan drafted

Fixed two operator-reported scrubber regressions: (1) backward seeks past the playlist's `t=0` were silently clamping to the start instead of triggering a server-restart at the target; (2) forward seeks > 5 s caused a one-frame scrubber jump-to-end due to a race between `playlistOffsetSec` and libmpv's position stream. Fix: `_pendingValue` release-pin (set in `onChangeEnd`, cleared by post-frame settle-check within 750 ms or 5 s fallback timer) in `flux_player_controls.dart`. Also flipped `isSeeking=true` eagerly before the 300 ms debounce. Drafted `docs/10_planning/18_library_transcode_plan.md` for opt-in AV1/VP9 → H.264 pre-transcode (8 milestones).

**Test counts at end:** Server 695 / Mobile 78 / Desktop 90 / Core 8.

---

### 2026-05-09 — Full-codebase doc audit (6 parallel Opus subagents)

Deep audit of all docs against current code state. 16 docs modified (+546 / -269 lines). Key fixes: status-code corrections in API contracts, schema NOT NULL/DEFAULT mismatches in database schema, TURN env-var caveat flagged in infrastructure, activity event types table expanded, security doc token-format corrected, frontend architecture extended with M11/M12 viewer screens and shared-widget section.

**Sharp edge discovered:** Real bug — TURN config name mismatch (`webrtc_turn_*` vs `fluxora_turn_*`) means Internet streaming over restrictive NATs silently fails.

**Test counts:** Unchanged (docs only).

---

### 2026-05-09 — Audit follow-up: TURN env-var, real-IP heartbeat, double-tap-skip, regression tests

Fixed all 4 audit sharp edges: (1) TURN env-var reads renamed to `settings.fluxora_turn_*` — direct attribute access so future renames surface as `AttributeError`, not silent failure. (2) `Routes.downloads` confirmed as intentional v1.1 stub (explicit comment in `mobile_shell.dart`) — not deleted. (3) `auth_service.update_client_heartbeat` updated to use `real_ip_key(request)` so tunneled clients record real IP, not 127.0.0.1. (4) `_seekRelative` in `flux_player_controls.dart` fixed to compute source-time before emitting delta — double-tap-skip after forward server-restart no longer lands at wrong position.

**Test counts:** Server 698 / Mobile 78 / Desktop 90 / Core 8.

---

### 2026-05-09 — Plan 18 — library transcode (M1–M5 + M8) via 2 parallel Opus subagents

Shipped the library transcode pipeline for AV1/VP9 → H.264 sidecars. Server: migration 027 (`transcode_jobs` table + sidecar columns on `media_files`), `transcode_service.py` (single-worker FIFO loop, crash-recovery sweep, FFmpeg progress pipe), `routers/transcode.py` (5 REST endpoints), `routers/stream.py` rewired to `playback_path = transcoded_path or path`. Desktop: full `features/transcode/` feature folder with Clean Architecture, folder tree, candidates/queue/history tabs, sidebar entry. M6 (post-scan toast) + M7 (stale-detection) deferred to v1.1.

**Test counts:** Server 730 / Mobile 78 / Desktop 104 / Core 8.

---

### 2026-05-09 — Plan 19 §M7 client-side decoding default + plan-18 sidecar-metadata-override hotfix

Strategic pivot to `client-decode` as the default streaming mode (AV1/VP9 stream-copy via fmp4). Migration 028 on `user_settings`. `_StreamingModeCard` in desktop encoder settings. Plan 18 hotfix: `source_codec_override` + `duration_sec_override` kwargs to `start_stream` / `restart_stream` so sidecar-path sessions don't fall back to live-transcode due to path-based DB lookup misses.

**Test counts:** Server 734 / Mobile 78 / Desktop 104 / Core 8.

---

### 2026-05-09 — Plan 19 close-out — M1-M6 + M8 via 2 parallel Opus subagents

Closed all 7 remaining plan-19 milestones: M1 quality preset chooser (smaller/recommended/mastering), M2 transcode storage settings + sidecar-path rewrite + cache-root validation, M3 `/transcode/storage` endpoint, M4 folder-grouped tree with tri-state checkboxes, M5 per-row size column + Stored-at menu, M6 `.webm→.mkv` ext override + stale-sidecar detection + partial-output cleanup, M8 per-library codec passthrough overrides + library-delete cascade. Three new migrations (029, 030, 031).

**Test counts:** Server 775 / Mobile 78 / Desktop 113 / Core 8.

---

### 2026-05-10 — Plan-19 close-out sharp edges resolved (all 4)

(1) `/transcode/storage` `by_library` breakdown: library-delete confirmation now shows "Also delete N transcoded sidecars (X GB)". (2) Folder-tree memoisation via `Expando` keyed by list reference. (3) `ApiClient.delete` query-param hook (avoids path-string concat in `library_repository_impl.dart`). (4) `Process.start` → `url_launcher` for the open-folder affordance in `storage_strip.dart`.

**Test counts:** Unchanged (mechanical fixes, existing tests cover).

---

### 2026-05-12 — Plan 20 — auto streaming mode + opt-in fallback (doc sweep)

Doc-update-protocol sweep for plan 20 (code shipped by prior agents). Plan 20 adds opt-in `streaming_mode='auto'` with transparent stream-copy → transcode fallback within 6 s of `PlayerReady`, per-client codec blocklist (`client_codec_blocklist` table, migration 033), `POST /fallback-transcode` endpoint, mobile auto-fallback watcher gated on `auto` mode, desktop 3-option `_StreamingModeCard`.

**Test counts:** Server 792 / Mobile 78 / Desktop 113 / Core 8.

---

### 2026-05-12 — Archive plan 20 (auto streaming mode)

Moved `docs/10_planning/20_auto_streaming_mode.md` → `docs/10_planning/archive/20_auto_streaming_mode.md`. Updated CLAUDE.md and roadmap links.

---

### 2026-05-12 — Plan 20 course corrections + plan 21 drafted

Three operator course corrections: (1) default flipped from `auto` back to `client-decode`; (2) fallback endpoint and blocklist consult gated on `streaming_mode == 'auto'` only; (3) desktop `_StreamingModeCard` re-ordered with `client-decode` first and `Recommended` badge. `StreamStartResponse.streaming_mode` added so mobile cubit can arm the watcher without a settings round-trip. Parallel agent drafted `docs/10_planning/21_client_audio_decoding.md`.

**Test counts:** Server 792 / Mobile 78 / Desktop 113 / Core 8.

---

### 2026-05-12 — Plan 21 close-out: docs sweep + archive + AGENT_LOG

M5 docs sweep for plan 21 (client-side audio decoding). Code (M1-M4) shipped by prior subagents. Plan 21: audio stream-copy allowlist `{aac, ac3, eac3, opus, flac}`, fmp4 switch for non-AAC audio, `client_audio_codec_blocklist` table (migration 034), `POST /fallback-audio-transcode` endpoint, mobile audio watcher, 128k → 256k AAC bitrate bump, `-ac` channel preservation. Archived plan 21 doc.

**Test counts:** Server 814 / Mobile 82 (player cubit 25 tests) / Desktop 113 / Core 8.

---

### 2026-05-14 — M14 shipped · mobile-redesign closed · goldens

Wave 1a: animation constants, `_DragHud` always-in-tree (`AnimatedOpacity` + `IgnorePointer`), `AnimatedScale` press feedback, `AnimatedOpacity` ripple overlay, route-fade `_fadePage<T>()` (250 ms), tab-scale 220 ms. Wave 1b: 29 Semantics nodes across player chrome, `ExcludeSemantics` on decorative elements, `FocusTraversalGroup` with `NumericFocusOrder` (top-bar 1 → quick-actions 6), `autofocus` on play/pause, `MediaQuery.withClampedTextScaling(1.3×)` on all 16 screens, private-widget exposure (`_TransportBar` → `PlayerTransportBar` etc., `@visibleForTesting`). Wave 2: 10 golden PNG baselines via `golden_toolkit: ^0.15.0`. Doc sweep: 6 docs updated (current_status, mobile_redesign_plan, roadmap, ship_readiness, frontend_architecture, gotchas). 4 new gotcha entries.

**Test counts at archive time (2026-05-14):** Server 814 / Mobile 92 (82 unit/widget + 10 goldens) / Desktop 113 / Core 8.

---

## Cross-references to archived entries

- Plan 18 implementation: `apps/server/database/migrations/027_transcode_jobs.sql`, `services/transcode_service.py`, `routers/transcode.py`
- Plan 19 migrations: `028_streaming_mode.sql`, `029_transcode_storage_settings.sql`, `030_per_library_codec_passthrough.sql`, `031_sidecar_source_mtime.sql`
- Plan 20 migrations: `032_streaming_mode_auto.sql`, `033_client_codec_blocklist.sql`
- Plan 21 migration: `034_client_audio_codec_blocklist.sql`
- M14 golden tests: `apps/mobile/test/goldens/` (10 PNG baselines + 10 test files)
- Plan docs (archived): `docs/10_planning/archive/19_library_transcode_followups.md`, `docs/10_planning/archive/20_auto_streaming_mode.md`, `docs/10_planning/archive/21_client_audio_decoding.md`

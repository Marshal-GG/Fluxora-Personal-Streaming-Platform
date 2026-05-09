# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the canonical format spec at [`docs/12_guidelines/04_agent_log_format.md`](docs/12_guidelines/04_agent_log_format.md).
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_NN.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 11)
**Archived:** 2026-05-09
**Contents:** Streaming pipeline §16 (resume + throttle plan) + §17 (FFmpeg diagnostics + M2 readrate retry) + same-day real-device follow-on patches (transcode-only readrate gate + scrubber-drag StatefulWidget conversion) + cross-cutting doc audit. Server suite **669 → 695** (+26). Mobile **75 → 78** (+3).

* **§16 — Streaming resume + throttle plan (2026-05-08).** Server-side resume-seek (`POST /stream/start/{file_id}?seek_sec=`) returns `applied_seek_sec` so mobile knows where the playlist's t=0 maps in source-time; mobile cubit threads this into `playlistOffsetSec` so the scrubber displays source-time, not playlist-local time. Audio fixed under tonemap (force re-encode). `_kSeekRestartThresholdSec=5` + 300 ms debounce; `playlistOffsetSec` lives in `PlayerReady`.

* **§17 — FFmpeg diagnostics + M2 retry (2026-05-08).** Uniform `-loglevel info` for ALL FFmpeg invocations (no more `<no stderr captured>`); new `services/ffmpeg_capabilities.py` probes FFmpeg version + flag support at server boot; `-readrate 1.5 -readrate_initial_burst 30` capability-gated to transcodes only.

* **§17 follow-on real-device patches (2026-05-08).** Two operator-reported regressions fixed same day: seg00195.ts 404 storm under stream-copy → readrate gate flipped to transcode-only (stream-copy doesn't need throttling); scrubber-drag rubber-band → `_ProgressBar` converted to `StatefulWidget` with `_dragValue` local state to break the per-tick `player.seek` → libmpv-clamp → slider-redraw cycle.

* **Cross-cutting doc audit (2026-05-08).** 12 docs synced after the §16/§17/follow-on rounds: `docs/00_overview/current_status.md`, `docs/04_api/01_api_contracts.md`, `docs/12_guidelines/03_gotchas.md` (2 new gotchas), `CLAUDE.md` (§17 plan row), `docs/00_overview/folder_structure.md`, `docs/02_architecture/02_tech_stack.md`, `docs/09_backend/01_backend_architecture.md`, `docs/10_planning/01_roadmap.md`, `docs/10_planning/05_ship_readiness.md`, `docs/10_planning/16_streaming_resume_and_throttle_plan.md`. Cross-link sweep clean — no stale 669/694/75-mobile/`-loglevel warning` claims outside archive logs.

**Test counts at archive time (2026-05-08):**
- Server: **695 passing** (+26 since archive 10's 669 → §16 server M1/M2/M3/M4 + §17 M1/M2/M3/M4 + follow-on regression guards).
- Mobile: **78 passing** (+3 since archive 10's 75: §16 cubit playlistOffsetSec round-trip + scrubber-offset display tests).
- Desktop: **90 passing** (untouched).
- Core: **8 passing** (untouched).

`flutter analyze` clean × all 3 packages. `ruff` clean.

**Migrations at archive time:** 001 → **026** (unchanged from archive 10 — no schema work in §16/§17).

**Working tree at archive time:** Clean. Four chunked commits landed on top of `eb92ef5`:
- `cc3e128 feat(server): streaming pipeline §16 + §17 — resume seek + audio fix + FFmpeg diagnostics + capability-gated readrate`
- `fa13d98 feat(mobile): streaming §16 scrubber-offset + §17 follow-on slider drag-preview state`
- `c18d8f2 docs: cross-cutting sync after streaming §16 + §17 + same-day follow-on`
- `79e4f51 chore: append AGENT_LOG entries for streaming §16 + §17 + follow-on + doc audit`

---

## [2026-05-09] [mobile] [fix] [docs] — Seek-restart scrubber regressions + library transcode plan

**Phase:** Phase 2 — streaming pipeline polish
**Status:** Complete (regression fixes); Drafted (transcode plan, awaiting design-decision answers)
**Commits:** uncommitted

### What Was Done

#### 1. Seek backward-out-of-playlist routing fix (operator-reported)

After a forward server-restart shifted the playlist's source-time origin to `K > 0`, all backward seeks were taking the in-player path (because `deltaMs < 5000` is always true for negative deltas), and `playerTargetMs = (targetSourceMs - offsetMs).clamp(0, ...)` clamped to `0` — silently stranding the user at the playlist's start instead of triggering a server-restart at the new target.

**Fix in `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart::seekTo`:** rewrote the branching to also check playlist-local bounds. Backward seeks that land within the loaded playlist still take the in-player path; backward seeks that fall before the playlist's `t=0` now route through the server-restart path. Forward seeks unchanged.

#### 2. Scrubber jump-to-end during forward server-restart (operator-reported, two iterations)

Forward seeks > 5 s release-and-trigger a server-restart. The user observed the scrubber visibly **slamming to the end of the track for one paint** and then settling at the actual seek target.

**Root cause** (took two iterations to nail): `_commitServerSeek`'s final `emit(isSeeking: false, playlistOffsetSec: K_new)` is a single state update, but in the widget tree the new `offsetMs = K_new × 1000` lands a paint or two before libmpv's position stream catches up to the new playlist's coordinates. For one frame: `sourcePos = oldPlayerPos + K_new` against `sourceDur = newPlayerDur + K_new`, ratio explodes past 1.0, `clamp(0,1)` drops it on `1.0`, scrubber paints at the right edge.

**Fix in `apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart`:** added a `_pendingValue` "release pin" that holds the slider at the user-released fraction across the entire seek-commit window. Three lifecycle paths:
- **Set** in `Slider.onChangeEnd` alongside clearing `_dragValue` (single `setState` so the widget re-renders the same value, never goes through `liveValue`).
- **Cleared** by a post-frame settle check in `build` once the player's reported `sourcePos` lands within 750 ms of the pinned target (handles both the in-player path where `isSeeking` never flips, and the post-restart path once libmpv catches up).
- **Cleared** by a 5 s fallback `Timer` armed in `onChangeEnd`, so a stalled / failed seek can never strand the pin permanently.

**Iteration history (worth knowing if this regresses again):** the first attempt cleared the pin in `didUpdateWidget` on the `isSeeking true → false` transition. That looked clean but **preempted the exact transient that was the bug** — pin cleared the same frame the offset updated, before the position stream caught up. Removed that path; relying solely on streams-have-settled-or-timer is more robust. Comment in `flux_player_controls.dart` calls this out for the next agent.

**Cubit-side complement:** also flipped `isSeeking=true` *immediately* on entering the server-restart branch in `seekTo`, before the 300 ms debounce starts. Previously there was a debounce window where the pin held but `isSeeking` was still false — under that condition the post-frame settle's `!isSeeking` guard would let stale stream emissions clear the pin early. Now the pin's lifecycle is 1:1 with the cubit's seeking flag through the entire restart window.

#### 3. `isSeeking` cascade

Threaded `state.isSeeking` from the player_screen's `BlocConsumer.builder` through `_VideoView` → `FluxPlayerControls` → `_ProgressBar`. Existing `_SeekingOverlay` already used `state.isSeeking` directly; the new cascade additionally exposes it to the scrubber's pin logic.

#### 4. Library transcode plan drafted

Operator hit a real perf cliff: 1080p AV1 source, GPU NVDEC rejected the chroma format (`av1_cuvid is not supported with this chroma format`), cuvid auto-fallback engaged software AV1 decode → NVENC encode. Pipeline throughput pinned to ~1× realtime by software AV1 decode → segments produced at the player's playback rate → `seg00018 404` retries → audible stalls. Diagnostic confirmed in server log shipped by operator.

Drafted [`docs/10_planning/18_library_transcode_plan.md`](docs/10_planning/18_library_transcode_plan.md) for **user-driven, opt-in** pre-transcode of AV1/VP9 sources to H.264 sidecars. Post-scan toast surfaces candidates → desktop UI multi-select → server queue runs FFmpeg jobs → playback automatically uses the transcoded copy via stream-copy. Mobile changes: zero (swap is server-side, `playback_path = transcoded_path or path`). 8 milestones (~10 h). 8 design questions in §9 are gating M1.

#### 5. Verification

`flutter analyze lib/features/player test/features/player` clean (ran twice across iterations). `flutter test` 78/78 passing.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Modified | apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart | seekTo: backward-out-of-playlist now routes to server-restart; isSeeking emits eagerly on server-restart entry |
| Modified | apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart | _ProgressBar gains _pendingValue release-pin + 5 s fallback timer; isSeeking threaded in |
| Modified | apps/mobile/lib/features/player/presentation/screens/player_screen.dart | _VideoView passes isSeeking to FluxPlayerControls |
| Modified | apps/mobile/test/features/player/player_cubit_test.dart | Comment updated to mention the new playlist-bounds branch |
| Created | docs/10_planning/18_library_transcode_plan.md | User-driven AV1/VP9 → H.264 pre-transcode feature plan |
| Modified | CLAUDE.md | "Where the detail lives" gains plan 18 row |
| Modified | docs/12_guidelines/03_gotchas.md | New gotcha: post-emit state-vs-stream race produces transient ratio>1 |
| Modified | docs/10_planning/17_ffmpeg_diagnostics_and_m2_retry_plan.md | §10 appended: 2026-05-09 follow-on regressions + fixes |
| Modified | docs/10_planning/01_roadmap.md | Streaming-pipeline-polish row notes today's regression closure; new line for plan 18 |
| Renamed | docs/logs/AGENT_LOG_archive_11.md | Rotated AGENT_LOG.md (was at 995 lines pre-this-entry) |
| Modified | AGENT_LOG.md | Reset with "Current State Summary (From Archive 11)" + this entry |

### Docs Updated

- `docs/10_planning/18_library_transcode_plan.md` (new)
- `CLAUDE.md`
- `docs/12_guidelines/03_gotchas.md`
- `docs/10_planning/17_ffmpeg_diagnostics_and_m2_retry_plan.md`
- `docs/10_planning/01_roadmap.md`
- `AGENT_LOG.md` + archive rotation

### Decisions Made

- **Pin clears via streams-settle + timer fallback, not via `isSeeking` transition.** First attempt cleared on `didUpdateWidget(isSeeking: true → false)` — looked clean, was wrong: it preempted the very transient it was meant to mask. Streams-have-settled is the durable signal; the 5 s timer is a safety net for stalled seeks.
- **Server-restart now emits `isSeeking=true` eagerly** in `seekTo` (before the 300 ms debounce) so the scrubber pin's gating is 1:1 with the cubit's flag through the whole restart window. Side effect: the existing `_SeekingOverlay` now appears immediately on release rather than after debounce — minor UX improvement, not a regression.
- **No new cubit tests for the bounds-check branch.** The seekTo branching requires a real `Player` in `PlayerReady` state to exercise; native media_kit libs are unavailable in headless tests. Existing safety-invariant tests still cover the no-session path; the new branch is field-validated by the operator's same-session retest. Comment in `player_cubit_test.dart` documents this.

### Issues / Sharp Edges Discovered

- **`Player.open()` reload emits position/duration streams in NO guaranteed order** — old position can land against new duration during the brief reload window. Any future scrubber/progress UI must guard with a release-pin or equivalent. Documented in the new gotcha.
- **`_seekRelative` (double-tap-skip / side-rail skip in `flux_player_controls.dart:270`) is still in player-time** — uses `widget.player.state.position + delta` and ignores `playlistOffsetSec`. After a forward server-restart, double-tap-skip would compute against playlist-local time and pass a small player-time number to `_emitSeek`, which the cubit interprets as source-time. Net effect: double-tap-skip after a forward seek-restart will behave as a backward seek to absolute source-time = delta. Not in scope for today's regression-fix round; flagged here so the next round picks it up. **Repro:** seek to 5:00, double-tap-forward — expect 5:10, will land at 0:10.

### Test Counts (re-baselined)

- **Server: 695 passing** (unchanged — no server-side code touched today).
- **Mobile: 78 passing** (unchanged — fix-only round; no new test coverage achievable without a real `Player`).
- **Desktop: 90 passing** (untouched).
- **Core: 8 passing** (untouched).

### Working-Tree Status

Single uncommitted batch on top of `eb92ef5` (post-archive-10 chunked commits already landed). Operator asked for one consolidated commit covering today's work.

### Next Agent Should

1. **Address the §9 design questions in plan 18** before starting any implementation work on the library transcode feature. Recommendations are listed inline in the plan; user approval gates M1.
2. **Patch `_seekRelative` in `flux_player_controls.dart:270`** to thread `playlistOffsetSec` and emit a source-time target. Currently ships a double-tap-skip bug that's only exposed after a forward server-restart.
3. **Real-device regression test for the scrubber pin** — operator confirmed the jump-to-end is fixed, but the iteration history (didUpdateWidget clear → premature) suggests this surface is fragile. If a future change to `_commitServerSeek`'s emit ordering, or to media_kit's stream behavior, breaks the pin, the symptom is "scrubber paints at end for one frame after a forward seek > 5 s". The 750 ms settle tolerance + 5 s fallback timer should keep it self-healing, but watch for it.
4. **`current_status.md` test counts didn't change today** — don't bump them on no-op rounds. (Carried forward from archive 10's same note.)

---

## [2026-05-09] [docs] [audit] — Full-codebase doc audit (6 parallel opus subagents)

**Phase:** Phase 2 — doc maintenance
**Status:** Complete
**Commits:** uncommitted (this entry written before commit)

### What Was Done

Spawned 6 Opus subagents in parallel, each owning a non-overlapping doc territory, to perform a deep audit of the docs against current code state. Operator-requested ("do full code base doc audit and check if anything is missed from docs, and do it deeply and update all the docs, dont miss any code or file, spawn multiple opus sub agents to do it faster"). Each subagent read its assigned code surfaces (services / routers / models / migrations / mobile features / desktop features / etc.) and updated only its assigned docs in place, returning a concise drift report.

Subagent partition (no write-overlap):

| Subagent | Owned docs |
|---|---|
| A — Backend architecture | `docs/09_backend/01_backend_architecture.md` |
| B — API contracts | `docs/04_api/01_api_contracts.md` |
| C — Data (schema, models, flows, migration guide) | `docs/03_data/01..04*.md` |
| D — Frontend architecture | `docs/08_frontend/01_frontend_architecture.md` |
| E — Overview + tech stack + system + components | `docs/00_overview/*.md` + `docs/02_architecture/*.md` |
| F — Security + infrastructure | `docs/06_security/01_security.md` + `docs/05_infrastructure/*.md` (excl. runbooks) |

Net total: **16 docs modified, +546 / −269 lines**. No code touched.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Modified | docs/00_overview/current_status.md | New "(latest) 2026-05-09" lead paragraph; test counts re-baselined to 695/78/90/8 |
| Modified | docs/00_overview/folder_structure.md | Server tree counts (24 services / 17 routers / 12 models, excluding `__init__.py`); top-level dir additions (`functions/`, `installer/`, `build/`); mobile/desktop test comments |
| Modified | docs/02_architecture/01_system_overview.md | §16/§17 streaming-engine notes; status stamp |
| Modified | docs/02_architecture/02_tech_stack.md | pytest count datestamp; 247 → 695 in testing matrix; mobile 75 → 78 |
| Modified | docs/02_architecture/03_component_architecture.md | Streaming Engine block rewritten with §16/§17 plumbing + ffmpeg_capabilities dependency |
| Modified | docs/03_data/01_data_models.md | Added `transcoding_hwaccel_device`, `transcoding_chain` settings columns |
| Modified | docs/03_data/02_database_schema.md | Fixed NOT NULL/DEFAULT mismatches (`bytes_transferred`, `progress_sec`, `language`, `transcoding_hwaccel_device`); INTEGER → BOOLEAN for migration-015 cols; added explicit index names |
| Modified | docs/03_data/03_data_flows.md | "Last Updated" stamp; flows verified against current services |
| Modified | docs/03_data/04_migration_guide.md | File-layout extended 010 → 026; test count refreshed; new "Patterns introduced post-014" section (sanitisation, FK ordering, JSON-blob columns, semantic flips, `_migrations` filename ledger); WAL + foreign_keys=ON note added |
| Modified | docs/04_api/01_api_contracts.md | 16 drift fixes — status code corrections (notifications 204 not 200), schema corrections (groups enter/grant-status/enroll, LibraryResponse `cover_urls`, BenchmarkProgress matrix-mode fields, BenchmarkHistoryEntry `resolution_count`), rate-limit decorators added, HLS route shape rewritten as single route, activity event types table expanded, auth modes table expanded |
| Modified | docs/05_infrastructure/01_infrastructure.md | Env-var table flagged TURN name-pair caveat |
| Modified | docs/05_infrastructure/02_url_inventory.md | +9 endpoints (`/info/support-bundle`, `/files/{id}/content`, `PATCH /auth/clients/me`, 5× `/transcoding/benchmark*`, `/healthz` row) |
| Modified | docs/05_infrastructure/06_webrtc_and_turn.md | TURN env-var bug flagged; doc tells operators to set both `webrtc_turn_*` AND `fluxora_turn_*` until code-fix lands |
| Modified | docs/06_security/01_security.md | Token storage: SHA-256 → HMAC-SHA256 (matches CLAUDE.md hard rule #13); token format: opaque UUID/JWT-future → `secrets.token_urlsafe(32)`; sign-out flow updated to mention existing `DELETE /auth/clients/me`; rate-limit summary added stream `/seek` 30/min; activity-log row marked shipped |
| Modified | docs/08_frontend/01_frontend_architecture.md | Added M11 viewer screens (doc/photo/music), M12 settings sub-screens (account/privacy/playback prefs), reconnect/scan-qr screens, desktop sub-features (subscription/profile/help/command_palette/system_stats); pruned moved widgets (`flux_button.dart` + `flux_chip.dart` now in core); player tree mentions `_pendingValue` + `isSeeking` cascade; framework table version pins per app; new shared-widgets section for `packages/fluxora_core/lib/widgets/` |
| Modified | docs/09_backend/01_backend_architecture.md | Added missing services (`benchmark_service`, `benchmark_history_service`, `ffmpeg_capabilities`); added missing router endpoints (`/benchmark*`, `/stream/{id}/seek`, `/clients/me/visible-libraries|continue-watching|stats`); added missing models (`StreamSeekResponse`, `StorageBreakdownResponse`, `ServerInfoResponse`, etc.); test count 351 → 695; tree indent corrected |
| Modified | AGENT_LOG.md | This entry |

### Docs Updated

Same as Files Modified — every change in this round was documentation.

### Decisions Made

- **Doc-only audit, no code fix.** The TURN env-var bug surfaced in the audit (see Sharp Edges below) is a real defect, but the operator's request was scoped to docs. Flagged in the security/infra docs and in this entry; the actual code fix is for a follow-up round.
- **Subagent ownership lock prevented file collisions.** Each of the 6 subagents wrote to a non-overlapping set of doc files. Verified post-run via `git status` — no merge conflicts, no double-edits.
- **Authoritative test counts injected into each prompt** (server 695 / mobile 78 / desktop 90 / core 8) rather than asking subagents to re-count. Reduced token cost + ensured consistency across the 16 updated docs.

### Issues / Sharp Edges Discovered

1. **🚨 Real bug — TURN config name mismatch.** `apps/server/services/webrtc_service.py:59-61` reads `webrtc_turn_url` / `webrtc_turn_username` / `webrtc_turn_password` via `getattr(settings, …, None)`, but `apps/server/config.py:76-78` declares `fluxora_turn_url` / `fluxora_turn_user` / `fluxora_turn_pass`. The two name pairs never bind, so the TURN code path silently ignores any env var and `_ice_servers()` returns STUN-only. **Effect:** Internet streaming over restrictive NATs will fail to negotiate even when the operator has set TURN credentials. **Fix:** rename the service-side reads to match config (or rename config to match service; pick one). Either change is a single-file diff. Not done in this audit because the operator scoped the work to docs. Until fixed, operators must export BOTH name pairs to make TURN work.
2. **`Routes.downloads` is registered nowhere.** `apps/mobile/lib/features/downloads/.../downloads_screen.dart` is in tree but `app_router.dart` doesn't define a route for it. Either wire it for v1.1 or delete the orphaned screen.
3. **Migration 023 IP-tracking limitation has no code-level TODO.** `auth_service.update_client_heartbeat` records `127.0.0.1` for all Cloudflare-tunneled clients because `CF-Connecting-IP` isn't consumed in that path. Documented in the migration guide; consider adding a `# TODO(real-ip)` marker in the service.
4. **`docs/00_overview/current_status.md` size — already at the 25k-token Read-cap from the 2026-05-08 entry.** This audit added a "(latest) 2026-05-09" paragraph at the top per the standard pattern. Future agents should still grep + targeted-Read; full-file `Read` will fail.
5. **Code count source-of-truth ambiguity.** Two ways to count `apps/server/services/`: 25 (`ls *.py | wc -l`, includes `__init__.py`) or 24 (excludes init). Folder-structure doc uses 24; I'd been telling subagents 25/18/13. Discrepancy is benign (init files don't carry behaviour) — left at 24/17/12 in folder doc since it's more useful for human readers.

### Test Counts (re-baselined)

No test changes this round (docs only). Numbers unchanged from the prior session entry:
- **Server: 695 passing**.
- **Mobile: 78 passing**.
- **Desktop: 90 passing**.
- **Core: 8 passing**.

### Working-Tree Status

16 modified docs, no new files, no code changes. Operator asked for a single audit-result commit.

### Next Agent Should

1. **Fix the TURN env-var name mismatch** (Sharp Edge #1). Either rename `services/webrtc_service.py:59-61` reads from `webrtc_turn_*` → `fluxora_turn_*`, or rename `config.py:76-78` declarations from `fluxora_turn_*` → `webrtc_turn_*`. The `fluxora_*` prefix is more consistent with the rest of the project's env vars; recommend renaming the service-side reads. Add a regression test asserting `_ice_servers()` actually returns the TURN entry when the env vars are set. Operator-facing impact: Internet streaming over restrictive NATs is currently silent-fail.
2. **Decide the `Routes.downloads` fate** (Sharp Edge #2). Either wire it into `app_router.dart` for v1.1, or delete `downloads_screen.dart` + ancillary code.
3. **Address the §9 design questions in plan 18** (carried forward from prior entry).
4. **Patch `_seekRelative` for `playlistOffsetSec`** (carried forward — double-tap-skip after a forward server-restart still bugged).

---

## [2026-05-09] [server] [mobile] [fix] [tests] — Audit follow-up: TURN env-var, real-IP heartbeat, double-tap-skip, regression tests

**Phase:** Phase 2 — bug fixes surfaced by the 2026-05-09 doc audit
**Status:** Complete
**Commits:** uncommitted

### What Was Done

Operator request: "fix all the issues" surfaced by the prior audit round. Worked through the 4 actionable flags from the audit + carried-forward Sharp Edges:

1. **TURN env-var name mismatch (Sharp Edge #1) — fixed.** `apps/server/services/webrtc_service.py::_ice_servers()` was reading `webrtc_turn_url` / `webrtc_turn_username` / `webrtc_turn_password` via `getattr(settings, …, None)` — names that never bound to any declared `Settings` field. Renamed reads to `settings.fluxora_turn_url` / `fluxora_turn_user` / `fluxora_turn_pass` (canonical names per `config.py:76-78`). Direct attribute access (no `getattr` fallback) so a future config-rename would surface as a `AttributeError` at boot rather than silently dropping TURN. Module-level docstring updated to reference the correct env vars.

2. **`Routes.downloads` "orphan" (Sharp Edge #2) — false positive, not deleted.** Re-reading `apps/mobile/lib/shared/widgets/mobile_shell.dart:20-23` shows the Downloads tab is **intentionally** kept as a v1.1 stub — explicit comment: *"`downloads_screen.dart` stays in the tree so re-enabling is a one-line restoration once the offline-storage subsystem lands."* The audit subagent's flag of this as "orphan" was wrong; deletion would force v1.1 to rebuild the screen. Left in place.

3. **Migration 023 IP-tracking limitation (Sharp Edge #3) — fixed at the call site, not just flagged.** Discovered `apps/server/utils/real_ip.py` already exposes a `real_ip_key(request)` helper that reads the trusted `request.state.real_ip` set by `RealIPMiddleware` (CF-Connecting-IP when the immediate peer is a Cloudflare IP and `FLUXORA_TRUST_CF_HEADERS` is on, else peer host). Updated `apps/server/routers/deps.py::validate_token` to call `real_ip_key(request)` instead of `request.client.host`. Tunneled clients are now recorded with their real IP in `clients.last_ip` instead of `127.0.0.1`. The migration's known limitation is closed at its actual call site, where it always belonged.

4. **`_seekRelative` ignores `playlistOffsetSec` (carried-forward Sharp Edge) — fixed.** `apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart::_seekRelative` was using `widget.player.state.position + delta` (player-time) and passing the result to the cubit, which expects source-time. After a forward server-restart with `playlistOffsetSec > 0`, a `+10 s` skip from source-time `5:00` would compute `playerPos + 10 s` and emit it as a source-time target — the cubit subtracted `playlistOffsetSec`, got a negative number, clamped to `0`, and double-tap-skip silently sent the user back to the start of the playlist. Now the helper computes `sourcePos = playerPos + offset` first, applies `delta` in source-time, then clamps to `[0, sourceDur]` before emitting.

5. **Regression tests added.** `apps/server/tests/test_webrtc_ice_servers.py` — 3 tests pinning `_ice_servers` behaviour: STUN-only when no TURN configured, includes TURN entry when all three are set, drops TURN if any of url/user/pass is empty.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Modified | apps/server/services/webrtc_service.py | TURN env-var reads renamed to `settings.fluxora_turn_*`; module docstring updated |
| Modified | apps/server/routers/deps.py | `last_ip` now read via `real_ip_key()` so tunneled clients are recorded with their real IP, not 127.0.0.1 |
| Modified | apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart | `_seekRelative` threads `playlistOffsetSec`; double-tap-skip stays in source-time |
| Created | apps/server/tests/test_webrtc_ice_servers.py | 3 regression tests for the TURN-config behaviour |
| Modified | docs/00_overview/current_status.md | New "(latest) 2026-05-09" lead paragraph for the audit follow-up; server count 695 → 698 |
| Modified | docs/02_architecture/02_tech_stack.md | Test count 695 → 698 (×2 occurrences) |
| Modified | docs/03_data/04_migration_guide.md | Test count 695 → 698 |
| Modified | docs/05_infrastructure/01_infrastructure.md | Env-vars table TURN row drift caveat removed; "Last Updated" |
| Modified | docs/05_infrastructure/06_webrtc_and_turn.md | Drift section removed; "Wire it into Fluxora" simplified to canonical names; "Last Updated" |
| Modified | docs/09_backend/01_backend_architecture.md | Test count tally 695 → 698 |
| Modified | docs/10_planning/01_roadmap.md | Test count 695 → 698 |
| Modified | docs/10_planning/05_ship_readiness.md | Test count 695 → 698 |
| Modified | AGENT_LOG.md | This entry |

### Docs Updated

Same as Files Modified — all 8 owned-doc edits + AGENT_LOG.

### Decisions Made

- **Direct attribute access on `Settings`, not `getattr` with default.** The whole reason the bug existed is that `getattr(settings, "webrtc_turn_url", None)` swallowed the name mismatch silently. The fix uses `settings.fluxora_turn_url` directly so any future rename or removal hits an `AttributeError` at boot — loud, not silent.
- **Real-IP fix at the call site, not via TODO comment.** The audit subagent suggested adding a `# TODO(real-ip)` marker; investigation revealed the project already had `real_ip_key(request)` available. Added an actual fix to `routers/deps.py`. The marker would have just been technical debt.
- **Did NOT delete `downloads_screen.dart`.** Explicit "kept-on-purpose" comment in `mobile_shell.dart` overrides the audit's "orphan" flag. The audit subagent didn't read that comment.

### Issues / Sharp Edges Discovered

- **Audit subagents can produce false positives if they don't read every nearby comment.** The Downloads-screen flag is the example: an "unregistered route" looks like dead code unless you read the explicit "stays in tree for v1.1" comment two files over. Future audits should weight existing comments before flagging deletion.
- **`real_ip_key()` re-implements the peer-fallback inline rather than calling out the existing path.** Not a bug, but the `_peer_host(request)` helper is private to `real_ip.py`. If callers need `real_ip` outside the `RealIPMiddleware`-wrapped path, they currently re-derive the peer host. Consider exporting `_peer_host` if a third caller appears.

### Test Counts (re-baselined)

- **Server: 695 → 698 passing** (+3 from `test_webrtc_ice_servers.py`).
- **Mobile: 78 passing** (unchanged — `_seekRelative` is a real-device-only path; `flutter analyze lib/features/player` clean, full mobile suite still passes).
- **Desktop: 90 passing** (untouched).
- **Core: 8 passing** (untouched).

`flutter analyze lib/features/player` clean. `ruff check` clean. Server suite ran in 115 s.

### Working-Tree Status

Audit-follow-up changes uncommitted on top of `55f9865`. Operator's earlier "fix all the issues, …" implies a single consolidating commit.

### Next Agent Should

1. **Address the §9 design questions in plan 18** (still gating M1 of the library transcode feature).
2. **Real-device regression test for the scrubber pin** (carried forward from prior entry — fragile surface; symptom is "scrubber paints at end for one frame after a forward seek > 5 s").
3. **`current_status.md` size — still over the 25k Read-cap.** Use `Grep` + targeted `Read` with offset/limit. Splitting into per-component status files is a candidate refactor when the next non-trivial doc round comes through.
4. **Watch for the `mobile_settings_remediation_plan` cross-link** — has been moved to `docs/10_planning/archive/15_mobile_settings_remediation_plan.md`. CLAUDE.md and the roadmap reference the archived path; some older docs may still link to the unarchived path.

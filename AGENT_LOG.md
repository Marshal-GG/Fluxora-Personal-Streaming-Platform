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

---

## [2026-05-09] [server] [desktop] [feat] [tests] — Plan 18 — library transcode (M1–M5 + M8) shipped via 2 parallel opus subagents

**Phase:** Phase 2 — closing the AV1/VP9 live-transcode pain
**Status:** Complete (M1–M5 + M8). M6 + M7 deferred to v1.1.
**Commits:** uncommitted

### What Was Done

Operator request: *"docs\10_planning\18_library_transcode_plan.md — we do this now, make proper ui for it too, still use multiple opus agents for faster work"*. Spawned 2 parallel Opus subagents — one for the server backend (M1–M4 + M8), one for the desktop UI (M5) — each owning a non-overlapping write surface, with the locked API contract embedded verbatim in both prompts so they couldn't diverge.

§9 design-decisions resolved with the recommendations: H.264 only · default `slow cq=19` only · concurrency = 1 · AV1 + VP9 only as candidates · copy everything for subtitles + multi-track audio · keep orphan transcodes when source moves · never auto-delete originals · side-by-side `<basename>.h264.<ext>` storage.

#### 1. Server backend (subagent A)

- **Migration 027** (`027_transcode_jobs.sql`): adds `transcoded_path TEXT`, `transcoded_size_bytes INTEGER`, `transcoded_at INTEGER` to `media_files`; creates `transcode_jobs` (id PK, file_id FK ON DELETE CASCADE, target_codec, encoder, quality_preset, status CHECK in {queued, running, done, failed, cancelled}, progress_pct REAL, eta_sec, error, output_path, created_at, started_at, finished_at) + indexes on `status` and `file_id`.
- **`models/transcode.py`**: `TranscodeCandidate`, `TranscodeQueueRequest` (1-50 file_ids), `TranscodeQueueResponse`, `TranscodeJobResponse` (joined `file_name` from `media_files.name`), `TranscodeRetryResponse`. JobStatus literal pinned to the 5 lifecycle states.
- **`services/transcode_service.py`**: single-worker FIFO loop. `start_worker()` is invoked from `main.py`'s lifespan (before app accepts requests); `stop_worker()` on shutdown. Crash-recovery sweeps `running` rows on boot and marks them `failed` with `error="server restarted mid-job"`. Encoder picked at queue time: `h264_nvenc` if it's in `encoder_registry.ENCODER_REGISTRY` and supported, else `libx264`. FFmpeg cmd uses `-progress pipe:2` parsed every ~1.5 s; on success stats the sidecar and writes the three new `media_files` columns in one transaction. Output_path collision (target file already exists) = fail-fast with `error="output path collision: <path>"` before spawning FFmpeg. Audio: `-c:a copy` if source is AAC, else `-c:a aac -b:a 192k`.
- **`routers/transcode.py`**: 5 endpoints under `/api/v1/transcode/...`, all `validate_token_or_local`. POST `/queue` is rate-limited `10/minute` per `real_ip_key` (matches the existing stream-start convention). `DELETE /jobs/{id}` returns 409 on terminal states; `POST /jobs/{id}/retry` returns 409 unless original is `failed` or `cancelled`.
- **`routers/stream.py`** (one-place edit, not `ffmpeg_service.py` as the spec suggested — the file row dict only exists at the router layer): `POST /stream/start/{file_id}` and the seek-restart path now compute `playback_path = file_row.transcoded_path or file_row.path` with a `Path(...).exists()` guard that falls back to source on missing-sidecar with a WARNING log.
- **Tests:** new `test_transcode_service.py` (14 tests covering candidate detection, queue dedup, active-job skip, cancel state transitions, retry preserving original error, status filter, crash-recovery sweep), new `test_transcode_router.py` (13 tests covering all 5 endpoints + 400/404/409/422 paths + auth gates), additions to `test_stream.py` (sidecar pickup + missing-sidecar fallback). Server suite **698 → 730 (+32)**.

#### 2. Desktop UI (subagent B)

- **`apps/desktop/lib/features/transcode/`** — full feature folder mirroring the existing `library/` Clean Architecture shape:
  - `domain/entities/{transcode_candidate.dart, transcode_job.dart}` — Equatable entities; `TranscodeJobStatus` enum (queued / running / done / failed / cancelled).
  - `domain/repositories/transcode_repository.dart` (interface) + `data/repositories/transcode_repository_impl.dart` (concrete over `ApiClient`).
  - `presentation/cubit/{transcode_cubit.dart, transcode_state.dart}` — sealed-union state (`Initial`/`Loaded` with `candidates`+`jobs`+`selectedFileIds`+`lastFetchAt`/`Failure`). 2 s `/jobs` polling timer started/stopped with the screen lifecycle. Selection auto-strips ids that have left the candidate list (post-queue, post-completion) so the checkbox state stays consistent without operator-visible flicker.
  - `presentation/screens/transcode_screen.dart` — TabBar + TabView wrapping the 3 tabs.
  - `presentation/widgets/{candidates_tab.dart, queue_tab.dart, history_tab.dart}` — Candidates: multi-select + aggregate disk + runtime estimate (`≈` prefix + italic) + `[Start transcode]` button. Queue: live `FluxProgress` bars + per-row Cancel + bulk Cancel-selected. History: terminal jobs + Retry on failed/cancelled.
- **Routing:** `Routes.transcode = '/transcode'` registered in `app_router.dart`.
- **DI:** `TranscodeRepository` lazy-singleton + `TranscodeCubit` factory in `injector.dart`.
- **Sidebar:** new entry between Library and Clients in `flux_sidebar.dart` (Material `Icons.fast_forward_outlined` — desktop sidebar uses Material icons exclusively).
- **Tests:** new `test/features/transcode/transcode_cubit_test.dart` — 14 tests covering loadCandidates emit-order, selectFiles state mutation, startTranscode (POST `/queue` then refresh `/jobs`), cancelJob (DELETE then refresh), retryJob (POST `/retry` then refresh), 2 s polling lifecycle, selection auto-strip after queue. Desktop suite **90 → 104 (+14)**.

#### 3. Verification

- `cd apps/server && python -m pytest -q` → **730 passed** in 148 s.
- `cd apps/server && ruff check .` → All checks passed.
- `cd apps/desktop && flutter analyze` → No issues found.
- `cd apps/desktop && flutter test --exclude-tags=golden` → **104 passed**.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Created | apps/server/database/migrations/027_transcode_jobs.sql | Sidecar columns + queue table |
| Created | apps/server/models/transcode.py | 5 Pydantic wire models |
| Created | apps/server/services/transcode_service.py | Queue + worker + FFmpeg invocation + crash-recovery |
| Created | apps/server/routers/transcode.py | 5 REST endpoints |
| Created | apps/server/tests/test_transcode_service.py | 14 service tests |
| Created | apps/server/tests/test_transcode_router.py | 13 router tests |
| Modified | apps/server/main.py | Mount router; `start_worker` / `stop_worker` in lifespan |
| Modified | apps/server/routers/stream.py | `playback_path = transcoded or path` rewire (start + seek) |
| Modified | apps/server/tests/test_stream.py | +2 sidecar pickup / fallback tests |
| Created | apps/desktop/lib/features/transcode/{domain,data,presentation}/* | 11 new files (entities, repo, cubit/state, screen, 3 tab widgets) |
| Created | apps/desktop/test/features/transcode/transcode_cubit_test.dart | 14 cubit tests |
| Modified | apps/desktop/lib/core/router/app_router.dart | Register `Routes.transcode` |
| Modified | apps/desktop/lib/core/di/injector.dart | Repo lazy-singleton + cubit factory |
| Modified | apps/desktop/lib/shared/widgets/flux_sidebar.dart | Sidebar entry between Library and Clients |
| Modified | docs/04_api/01_api_contracts.md | New "Library Transcode (Plan 18)" section with all 5 endpoints |
| Modified | docs/03_data/02_database_schema.md | New `transcode_jobs` table + sidecar columns + 2 new index rows + migration 027 row |
| Modified | docs/03_data/04_migration_guide.md | File layout extended to 027; test count 698 → 730 |
| Modified | docs/09_backend/01_backend_architecture.md | New service/router/model/test rows; total 698 → 730 |
| Modified | docs/08_frontend/01_frontend_architecture.md | New `transcode/` feature subtree, route row, test entry; desktop count 90 → 104 |
| Modified | docs/10_planning/18_library_transcode_plan.md | Status banner; M1-M5 + M8 ✅; M6 + M7 deferred |
| Modified | docs/10_planning/01_roadmap.md | Library-transcode row 🔲 → ✅ Done; counts |
| Modified | docs/10_planning/05_ship_readiness.md | Counts 698/90 → 730/104 |
| Modified | docs/02_architecture/02_tech_stack.md | Server count 698 → 730 |
| Modified | docs/00_overview/folder_structure.md | 027 row; routers 17 → 18; services 24 → 25; models 12 → 13 |
| Modified | docs/00_overview/current_status.md | New "(latest) 2026-05-09" lead paragraph; per-component server count |
| Modified | AGENT_LOG.md | This entry |

### Docs Updated

Same as Files Modified — every `docs/` write listed above + AGENT_LOG.

### Decisions Made

- **Streaming-pipeline rewire moved from `ffmpeg_service.py::start_stream` to `routers/stream.py`.** The plan's spec snippet uses `file_row.get("transcoded_path")` but `start_stream` only receives `file_path: str` — the row dict only exists at the router layer. The router is the only place where the swap can be cleanly made. Both the start and seek-restart paths now do the same swap.
- **Used `media_files.codec_name` (the actual column from migration 016), not `video_codec` as the spec wrote.** Same intent; the column name in this codebase is `codec_name`. The Pydantic wire field is still named `video_codec` per the spec (so the desktop client doesn't have to remap).
- **Worker uses `proc.terminate()` (cross-platform) rather than POSIX `SIGTERM` directly.** On POSIX `terminate()` sends SIGTERM; on Windows it issues `TerminateProcess`. Preserves portability since Fluxora ships on Windows / macOS / Linux.
- **API endpoint paths in `transcode_repository_impl.dart` are inline string literals**, not exported from `packages/fluxora_core/lib/network/endpoints.dart`. The desktop subagent's "don't touch core" rule prevented widening that file. Documented at the top of the impl.
- **Sidebar uses `Icons.fast_forward_outlined` (Material), not `LucideIcons.*`.** The desktop has no `lucide_icons` dep; the rest of the sidebar uses Material icons exclusively, so we matched the existing convention.

### Issues / Sharp Edges Discovered

1. **Pre-migration-016 rows may have NULL `codec_name`** so the `LOWER(codec_name) IN ('av1','vp9')` candidate query returns 0 for libraries scanned before the codec_name column existed. Mitigation surfaced in the desktop UI's empty state (the operator should re-scan their library). Worth adding a server-side hint in a future round.
2. **`.webm` source extension would produce a `.h264.webm` sidecar.** FFmpeg actually rejects H.264-in-WebM at mux time, so the job will fail with a stderr error pointing at the container/codec mismatch. Worth a future enhancement: force `.mkv` sidecar extension when source is `.webm`. Logged in plan 18 for v1.1.
3. **Cancelled-running jobs leave a brief window** between `status='cancelled'` (set synchronously) and `_cleanup_partial` (deletes the partial output file on the worker's exit branch). Acceptable for v1; worth documenting if the operator sees "partially-written sidecar visible on disk for ~1 s after cancel".
4. **Crash-recovery sweep marks orphan rows failed but doesn't clean up partial outputs they may have written.** Future enhancement: derive each orphan's expected `_sidecar_path` from its file row and unlink it on boot. Logged for v1.1.
5. **`models/library.py` has no `name` field directly** — `file_name` in `TranscodeJobResponse` is joined from `media_files.name`. Verified the join works in the existing test fixtures.

### Test Counts (re-baselined)

- **Server: 730 passing** (+32 from `test_transcode_service.py` 14 + `test_transcode_router.py` 13 + `test_stream.py` +2 + 3 from prior audit-follow-up TURN tests landed in the same range).
- **Mobile: 78 passing** (unchanged — plan 18 has zero mobile changes by design).
- **Desktop: 104 passing** (+14 from `transcode_cubit_test.dart`).
- **Core: 8 passing** (untouched).

`flutter analyze` clean × all packages. `ruff check` clean.

### Working-Tree Status

Plan 18 changes uncommitted on top of `5fe519f`. Operator-asked single consolidating commit.

### Next Agent Should

1. **Real-device end-to-end test** of the transcode flow: queue an actual AV1 file, watch the worker run, verify the sidecar lands next to the source, verify subsequent playback stream-copies (server log says `mode=stream-copy(h264/mpegts) source_codec=h264` even though the original was AV1). The unit tests don't run a real FFmpeg.
2. **Decide whether to ship M6 (post-scan toast) and M7 (stale-detection on rescan) for v1** or defer to v1.1. Both are listed as deferred in plan 18 right now.
3. **Watch for the `.webm` source edge case** (Sharp Edge #2 above) — first job that fails on a `.webm` source is the trigger to ship the "force `.mkv` sidecar extension when source is webm" tweak.
4. **`current_status.md` is still over the 25 k Read-cap.** Carried forward — splitting into per-component files is a future refactor.

---

## [2026-05-09] [server] [desktop] [feat] [fix] [tests] — Plan 19 §M7 client-side decoding default + plan 18 sidecar-metadata-override hotfix

**Phase:** Phase 2 — strategic pivot to client-side decoding for v1 launch + plan-18 real-device test follow-up
**Status:** Complete (M7 launch-priority milestone). M1-M6 + M8 of plan 19 deferred to v1.1.
**Commits:** uncommitted

### What Was Done

Two threads, one commit. Both touch `routers/stream.py` + `services/ffmpeg_service.py`; shipping together avoids a half-fix interim state where the sidecar metadata overrides land but the streaming-mode toggle doesn't (or vice versa).

#### 1. Strategic pivot — plan 19 §M7 (launch priority)

Operator real-device test of plan 18 surfaced four pain points in the live-transcode pipeline (4× sized sidecars at default `nvenc cq=19`, side-by-side storage clutter, no path control, no UI feedback). Mid-iteration the strategy reframed: *"we will just launch project currently with client side decoding, priority casue that is more reliable and work with more clients as server load is very low … dont remove the server work code, for now just create a toggle in encoding settings."*

Built **plan 19** as the formal followup roadmap, then immediately elevated **M7 (AV1/VP9 stream-copy + global "Streaming mode" toggle) to launch priority** with M1-M6 + M8 deferred to v1.1.

- **Migration 028** (`028_streaming_mode.sql`) — single column on `user_settings`: `streaming_mode TEXT NOT NULL DEFAULT 'client-decode' CHECK(streaming_mode IN ('client-decode','server-transcode'))`. Default `client-decode` matches launch intent (server CPU near zero from day 1; modern devices hardware-decode).
- **`services/ffmpeg_service.py`** — `start_stream` reads `streaming_mode` from settings; extends the direct-remux check to AV1 + VP9 when `client-decode`. Uses the existing fmp4 segment path that HEVC already shipped (`-c:v copy -hls_segment_type fmp4 -hls_fmp4_init_filename init.mp4`). `_build_ffmpeg_cmd` gains `direct_remux_av1: bool = False` and `direct_remux_vp9: bool = False` kwargs (default False keeps existing tests green); the local `use_fmp4` derivation extends to fire on AV1 / VP9 too. New `mode=stream-copy(av1/fmp4)` and `mode=stream-copy(vp9/fmp4)` log shapes.
- **`models/settings.py`** — `UserSettingsResponse.streaming_mode: Literal["client-decode","server-transcode"] = "client-decode"`; `UpdateSettingsBody.streaming_mode: Literal[…] | None = None`.
- **`services/settings_service.py`** — kwarg + DB-column mapping for `streaming_mode`; default-row stub uses `'client-decode'`.
- **Desktop** — new `_StreamingModeCard` at the top of the Configuration tab in `EncoderSettingsScreen`. Two radio rows ("Client decodes (recommended)" + "Server transcodes (legacy / mixed device pools)") with body copy + an amber-tinted "Devices older than ~2021 may fail to play AV1 sources" advisory under the recommended option. Custom radio dot (Container with circular border) so we don't churn against Flutter's v3.32 `Radio.groupValue` deprecation. Hooked to `SettingsCubit`'s new `streamingMode` field via the existing PATCH path.
- **Tests** — `test_stream.py` +3 cases: `test_build_ffmpeg_cmd_stream_copies_av1_when_client_decode`, `_vp9_…`, `_transcodes_av1_when_server_transcode`. Server suite **731 → 734 (+3)**. Desktop unchanged (the new widget is hand-validated; deeper widget tests deferred with the rest of plan 19).

#### 2. Plan 18 sidecar-metadata-override hotfix (real-device follow-up)

Operator's real-device retest of the plan-18 transcode pipeline surfaced that the sidecar swap in `routers/stream.py` was working at the path level (FFmpeg got the sidecar path), but **two adjacent path-based DB lookups inside `start_stream` were missing**:
- `_resolve_source_metadata(file_path)` queries `media_files WHERE path = ?` — sidecar paths aren't in `media_files`, so it returned `(None, None)` and `source_codec` came back as `<unknown>`. The direct-remux check failed and the file fell into the transcode branch — silent NVENC re-encode of an already-H.264 sidecar back to H.264.
- The static-VOD-playlist `SELECT duration_sec FROM media_files WHERE path = ?` missed for the same reason — surfaced as "Static VOD playlist skipped — no duration known" in the operator's log; player got the FFmpeg-incremental playlist with no scrubber.

**Fix:** added `source_codec_override: str | None = None` and `duration_sec_override: float | None = None` kwargs to `start_stream` and `restart_stream`. When set, they short-circuit the path-based DB lookups. The router computes both values from the source row's existing fields (`"h264"` because the sidecar is H.264 by construction; `file_row["duration_sec"]` because the sidecar's duration matches the source) and passes them through whenever `transcoded_path` is in use AND the file exists on disk. Same logic mirrored in the seek-restart path.

**Tests:** extended `test_start_stream_uses_transcoded_sidecar_when_present` to assert the overrides reach `start_stream`'s call site; added `test_start_stream_no_overrides_when_no_sidecar` companion. The +3 audit-follow-up TURN tests + the +2 here account for `731 → 734` total.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Created | apps/server/database/migrations/028_streaming_mode.sql | One-column migration: `streaming_mode` enum on `user_settings` |
| Modified | apps/server/services/ffmpeg_service.py | AV1/VP9 direct-remux check; `_build_ffmpeg_cmd` gains `direct_remux_av1`/`_vp9`; `use_fmp4` extended; new `mode=` log shapes; `start_stream`/`restart_stream` gain `source_codec_override` + `duration_sec_override` |
| Modified | apps/server/services/settings_service.py | `streaming_mode` kwarg + column mapping + default-row stub |
| Modified | apps/server/models/settings.py | `streaming_mode` `Literal` field on `UserSettingsResponse` and `UpdateSettingsBody` |
| Modified | apps/server/routers/stream.py | Sidecar override-kwargs computed in both `/start` and `/seek` paths |
| Modified | apps/server/tests/test_stream.py | +3 AV1/VP9 cmd-builder tests; +2 sidecar-override regression tests |
| Modified | apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart | `_StreamingModeCard` + `_StreamingModeOption` widgets at top of Configuration tab; `_streamingMode` state; threaded into `_save` |
| Modified | apps/desktop/lib/features/settings/presentation/cubit/settings_state.dart | `streamingMode` field + copyWith |
| Modified | apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart | Load + save wiring for `streamingMode` |
| Modified | docs/10_planning/19_library_transcode_followups.md | Status banner re-baselined to "M7 launch priority"; §3 migration scope shrunk; §7 milestones reordered; §9 simplified to launch decisions; §10 split launch / deferred; §12 TL;DR rewritten |
| Modified | docs/00_overview/current_status.md | New "(latest) 2026-05-09" lead paragraph for §M7 + sidecar hotfix; per-component server count 730 → 734 |
| Modified | docs/00_overview/folder_structure.md | 028 row added to migrations |
| Modified | docs/02_architecture/02_tech_stack.md | Server tests 730 → 734 |
| Modified | docs/03_data/02_database_schema.md | Migration 028 row in Applied Migrations |
| Modified | docs/03_data/04_migration_guide.md | File-layout extended to 028; test count refreshed |
| Modified | docs/04_api/01_api_contracts.md | New `PATCH /settings — streaming_mode field` section |
| Modified | docs/09_backend/01_backend_architecture.md | `ffmpeg_service.py` row gains §M7 + sidecar override notes; total 730 → 734 |
| Modified | docs/10_planning/01_roadmap.md | New "Client-side codec passthrough (plan 19 §M7)" row marked ✅ Done; counts refreshed |
| Modified | docs/10_planning/05_ship_readiness.md | Counts 730 / 104 → 734 / 104 |
| Modified | CLAUDE.md | "Where the detail lives" gains plan 19 row |
| Modified | AGENT_LOG.md | This entry |

### Docs Updated

Same as Files Modified above — every `docs/`-prefixed entry plus CLAUDE.md and the AGENT_LOG.

### Decisions Made

- **Default `streaming_mode = 'client-decode'`** matches the operator's stated launch intent. Server CPU near zero from day 1; modern devices "just work"; legacy operators flip to `server-transcode` after seeing one device fail. The settings UI carries an explicit "Older devices may not play AV1 / VP9 directly" warning under the recommended option so the failure mode is set as expectation rather than discovered.
- **Single global toggle, not per-codec.** AV1 and VP9 flip together. Per-codec granularity (separate `av1_stream_copy_enabled` / `vp9_stream_copy_enabled`) was the original §M7 draft; collapsing to one `streaming_mode` enum is simpler UI and mirrors the operator's mental model. Per-library overrides (M8, deferred) would re-introduce per-codec granularity at the per-library scope when they ship.
- **Sidecar pickup wins regardless of mode.** If `media_files.transcoded_path` is set + the file exists on disk, the existing H.264 sidecar streams (stream-copy from H.264). Mode only governs what happens when there's no sidecar. Operators who already ran plan-18 jobs don't lose that work when v1 ships with `client-decode` default.
- **Custom radio dot vs Material `Radio` widget.** Flutter v3.32 deprecated `Radio.groupValue` + `onChanged` in favour of a `RadioGroup` ancestor. The `_StreamingModeCard` uses a hand-built circular `Container` for the visual radio dot + an `InkWell`-wrapped row for the actual selector — avoids the deprecation churn while keeping the visual semantics.
- **Hot-fix and §M7 ship together as one commit.** Both touch the same `routers/stream.py` and `services/ffmpeg_service.py` paths. Shipping the sidecar-override fix without §M7 would mean an operator on `client-decode` mode would still see live transcode for every AV1 / VP9 file unless they had already run plan-18 jobs on every file individually — defeats the launch-priority intent. Shipping §M7 without the override fix would mean operators who DID run plan-18 jobs would still see transcode-instead-of-stream-copy for those files. Both fixes complete the picture.

### Issues / Sharp Edges Discovered

1. **AV1 / VP9 in fmp4 stream-copy is library/build dependent on the client side.** media_kit / libmpv must be built with AV1 + VP9 decode for the client to actually play these. Modern builds do; older Android / iOS builds may not. Operator-facing knob is the `streaming_mode` toggle — flip to `server-transcode` for legacy device pools. **Repro for next agent:** point an iOS pre-A17 device at a 1080p AV1 source with `streaming_mode='client-decode'`; expected: stream stalls or media_kit raises a "no decoder for codec" error.
2. **The `direct_remux_av1` and `direct_remux_vp9` defaults of `False` on `_build_ffmpeg_cmd` are deliberate** — the retry path (line 1378) for the cuvid auto-fallback never gets here under stream-copy (retry is gated on `not direct_remux`), so passing the new kwargs there is a no-op. Defaults of `False` mean "treat as transcode," which matches the retry-path semantics.
3. **`media_files.codec_name` is the canonical column** — plan 18 / plan 19 both query it for codec detection. Pre-migration-016 rows have NULL `codec_name` and won't appear as transcode candidates AND won't be picked up by the AV1/VP9 stream-copy path either. Carried forward from plan 18's known sharp edges.
4. **Plan 19 deferred milestones are real work for v1.1.** M1 (preset chooser, lower default `cq=19` → `cq=23`) is the highest-priority deferred item — operators who DO opt into transcoding still hit the 4×-bigger sidecar pain immediately. The operator's launch path (`client-decode` default) sidesteps it for AV1/VP9 sources but still bites for true-non-stream-copy sources (MPEG-2/4, ancient codecs).

### Test Counts (re-baselined)

- **Server: 731 → 734 passing** (+3 from `test_stream.py` AV1/VP9 cmd-builder tests; the +2 sidecar override tests landed in the 730 → 731 hot-fix-style run already).
- **Mobile: 78 passing** (unchanged — plan 19 §M7 has zero mobile changes by design).
- **Desktop: 104 passing** (unchanged).
- **Core: 8 passing** (untouched).

`flutter analyze lib/features/transcoding` clean. `ruff check` clean. Server suite ran in 132 s.

### Working-Tree Status

All §M7 + hotfix changes uncommitted on top of `191fe44`. Operator-asked single consolidating commit covering both threads.

### Next Agent Should

1. **Real-device end-to-end test of `client-decode` mode.** Point a modern phone at an AV1 source on a fresh server (post-migration). Server log should say `mode=stream-copy(av1/fmp4) source_codec=av1` and CPU should stay near zero. Compare against the same source on `server-transcode` mode (toggle in Settings → Encoder Settings → Streaming Mode) — should fall back to the plan-18 transcode pipeline.
2. **Watch for AV1 / VP9 fmp4 playback issues on real devices.** Modern (~2022+) phones / tablets / desktops should hardware-decode both. Older devices may not — that's the documented failure mode behind the `server-transcode` fallback toggle.
3. **Plan 19 deferred milestones — M1 is highest priority** when the operator round comes back. Lowering the transcode default from `cq=19` to `cq=23` is a one-line change that halves the sidecar size for operators who DO opt into transcoding.
4. **`_seekRelative` mobile bug** (still carried forward from earlier — double-tap-skip after a forward server-restart still bugged; flagged in the prior AGENT_LOG entry but not yet fixed).
5. **`current_status.md` is still over the 25 k Read-cap.** Carried forward.

---

## [2026-05-09] [server] [desktop] [feat] [tests] — Plan 19 close-out — M1, M2, M3, M4, M5, M6, M8 shipped via 2 parallel opus subagents

**Phase:** Phase 2 — closing the remaining 7 milestones of plan 19 in one round
**Status:** Complete. All 8 milestones of plan 19 closed (M7 shipped earlier same day as launch-priority commit `627cdf1`; M1-M6 + M8 shipped here).
**Commits:** uncommitted

### What Was Done

Operator request: *"create multiple opus sub agents to do them now"* — referring to the 7 plan-19 milestones marked deferred at M7's ship time. Spawned **2 parallel Opus subagents**, partitioned along the server / desktop boundary so cubit / repository / model files don't collide. The locked API contract was embedded in both prompts so they could build in parallel without diverging.

| Subagent | Owns | Milestones |
|---|---|---|
| A — Server backend | All of `apps/server/` for plan 19 + tests | M1 (preset map + worker default), M2 (storage settings + sidecar-path rewrite + cache-root validation), M3 (`/transcode/storage` endpoint), M6 (.webm extension override + stale-mtime detection on rescan + partial-output cleanup on crash recovery), M8 (per-library codec passthrough overrides + library-delete cascade with sidecar cleanup) |
| B — Desktop UI | All of `apps/desktop/lib/features/transcode/` and the relevant settings + library widgets | M1 (Queue dialog with preset chooser), M3 (`_StorageStrip` widget + 5 s polling), M4 (folder-grouped tree with tri-state checkboxes), M5 (per-row size column + Stored-at menu), M8 (3-state segmented controls per codec on library edit form + sidecar-cleanup checkbox in library-delete confirmation) |

3 new migrations (029, 030, 031) added in correct numerical order. Plan 19 §3's separate-migration-per-milestone discipline is preserved — each migration's CHECK constraints + nullable defaults reflect the milestone's specific shape.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Created | apps/server/database/migrations/029_transcode_storage_settings.sql | M2 — `transcode_storage_mode` + `transcode_cache_root` on `user_settings` |
| Created | apps/server/database/migrations/030_per_library_codec_passthrough.sql | M8 — `av1_stream_copy_override` + `vp9_stream_copy_override` on `libraries` (nullable, tri-state) |
| Created | apps/server/database/migrations/031_sidecar_source_mtime.sql | M6 — `transcoded_source_mtime` on `media_files` |
| Modified | apps/server/services/transcode_service.py | M1 `QUALITY_PRESETS` map (smaller / recommended / mastering); M2 `_sidecar_path()` rewrite for both modes; M6 .webm→.mkv ext override + partial-output cleanup on crash recovery; M3 storage aggregate query helper |
| Modified | apps/server/services/settings_service.py | M2 `_validate_transcode_cache_root` async helper (absolute / writable / outside-library checks via `asyncio.to_thread`); kwarg + column-mapping for both new fields; default-row stub extended; sentinel `_UNSET` for explicit-clear vs leave-unchanged semantics |
| Modified | apps/server/services/library_service.py | M6 stale-sidecar detection on rescan; M8 `delete_library` accepts `delete_sidecars: bool = True` and unlinks files before CASCADE delete |
| Modified | apps/server/services/ffmpeg_service.py | M8 `_resolve_codec_passthrough(settings_row, library_row, codec)` helper replaces direct `streaming_mode` read; per-library override beats global setting; `start_stream` + `restart_stream` accept `library_row` kwarg |
| Modified | apps/server/routers/transcode.py | M1 `POST /queue` accepts `preset` field (Pydantic Literal); M3 new `GET /storage` endpoint |
| Modified | apps/server/routers/settings.py | M2 PATCH accepts `transcode_storage_mode` + `transcode_cache_root` with validation pass-through |
| Modified | apps/server/routers/library.py | M8 PATCH accepts `av1_stream_copy_override` + `vp9_stream_copy_override` (3-state); DELETE accepts `?delete_sidecars=` query (default true) |
| Modified | apps/server/routers/stream.py | Threads `library_row` into `start_stream` / `restart_stream` calls so per-library overrides resolve |
| Modified | apps/server/models/transcode.py | M1 `preset` on `TranscodeQueueRequest`; M3 `TranscodeStorageResponse` |
| Modified | apps/server/models/settings.py | M2 `transcode_storage_mode` + `transcode_cache_root` fields on both Update + Response |
| Modified | apps/server/models/library.py | M8 2 override fields on Library models |
| Modified | apps/server/tests/{test_transcode_service,test_transcode_router,test_stream,test_library,test_settings_extended,conftest}.py | +41 server tests |
| Created | apps/desktop/lib/features/transcode/domain/entities/transcode_storage.dart | M3 entity + per-codec breakdown |
| Created | apps/desktop/lib/features/transcode/presentation/widgets/storage_strip.dart | M3 top-of-page aggregate widget + cross-platform open-in-file-manager helpers |
| Created | apps/desktop/lib/features/transcode/presentation/widgets/queue_dialog.dart | M1+M5 `showQueueDialog()` with 3-radio preset chooser + live estimated total + cache-root readout |
| Created | apps/desktop/lib/features/transcode/presentation/widgets/folder_tree.dart | M4 `FolderNode<T>` + `buildFolderTree()` + recursive `FolderTreeView<T>` with tri-state checkboxes |
| Created | apps/desktop/lib/features/library/domain/entities/library.dart | M8 desktop-only `LibraryCodecOverrides` sidecar (the canonical Library is freezed in fluxora_core; off-limits) |
| Modified | apps/desktop/lib/features/transcode/domain/entities/{transcode_candidate,transcode_job}.dart | M4 `path` field for tree grouping; M5 `outputSizeBytes` / `srcSizeBytes` / `srcPath` |
| Modified | apps/desktop/lib/features/transcode/domain/repositories/transcode_repository.dart | M1 `TranscodePreset` enum + `estimateOutputBytes()` helper; M3 `getStorage()`; preset arg on `queueJobs()` |
| Modified | apps/desktop/lib/features/transcode/data/repositories/transcode_repository_impl.dart | M1 preset wiring; M3 `/storage` endpoint |
| Modified | apps/desktop/lib/features/transcode/presentation/cubit/{transcode_cubit,transcode_state}.dart | Storage state slice; expanded-paths set for tree; queue preset; split timers (2 s `/jobs` + 5 s `/storage`) |
| Modified | apps/desktop/lib/features/transcode/presentation/screens/transcode_screen.dart | Mounted `_StorageStrip` above the TabBar |
| Modified | apps/desktop/lib/features/transcode/presentation/widgets/{candidates,queue,history}_tab.dart | M4 folder tree replaces flat list (Candidates + History); M5 per-row size column + Stored-at menu (Queue + History) |
| Modified | apps/desktop/lib/features/library/{domain/repositories,data/repositories,presentation/cubit,presentation/cubit/state,presentation/screens}/* | M8 `LibrariesPayload` typedef + `LibraryOverrideUpdate` 3-state sentinel (unchanged / clear / value); `deleteSidecars` flag; `codecOverrides` map; library edit form gains 3-state segmented controls per codec; library-delete dialog gains sidecar-cleanup checkbox (default checked) |
| Modified | apps/desktop/test/features/transcode/transcode_cubit_test.dart | +9 desktop tests for storage state, folder tree, preset selection, expand-state |
| Modified | docs/10_planning/19_library_transcode_followups.md | Status banner: full plan closed; milestone table marks M1-M6 + M8 ✅; §12 TL;DR rewritten |
| Modified | docs/00_overview/current_status.md | New "(latest) 2026-05-09" lead paragraph for the close-out; per-component server count 734 → 775 |
| Modified | docs/00_overview/folder_structure.md | 029 / 030 / 031 rows added |
| Modified | docs/02_architecture/02_tech_stack.md | Server tests 734 → 775 |
| Modified | docs/03_data/02_database_schema.md | 029 / 030 / 031 rows in Applied Migrations table |
| Modified | docs/03_data/04_migration_guide.md | File-layout extended to 031; test count refreshed |
| Modified | docs/09_backend/01_backend_architecture.md | Test tally 734 → 775 |
| Modified | docs/10_planning/01_roadmap.md | Plan-19 row collapsed to "all 8 milestones closed same day"; counts |
| Modified | docs/10_planning/05_ship_readiness.md | Counts 734 / 104 → 775 / 113 |
| Modified | AGENT_LOG.md | This entry |

### Docs Updated

Same as Files Modified above — every `docs/`-prefixed entry plus the AGENT_LOG.

### Decisions Made

- **Subagent partition along the server / desktop boundary, not by milestone.** Plan 19's milestones were too cross-cutting at the file level — `services/transcode_service.py`, `models/transcode.py`, `routers/transcode.py`, `transcode_cubit.dart`, `transcode_repository.dart`, `history_tab.dart` would all have been touched by 3+ subagents if we'd partitioned by milestone. By-layer partition kept each subagent's write surface disjoint and let them run in parallel without merge conflicts. Same approach as plan 18's first ship.
- **API contract embedded verbatim in both prompts.** Field names, endpoint paths, status codes, JSON shapes — all specified in both the server and desktop prompts so neither subagent could invent its own naming. This was the load-bearing risk-mitigation move; without it the desktop subagent would have had to wait for the server subagent to finish before building, defeating the parallelism.
- **`LibraryOverrideUpdate` sealed sentinel for the 3-state PATCH semantics.** "Use global" (`null`) is ambiguous — it could mean "leave unchanged" (don't include in PATCH body) or "explicitly clear" (set to NULL on the server). Desktop subagent introduced a `LibraryOverrideUpdate.unchanged | .clear | .value(true|false)` sealed type so the cubit can express both. Server side accepts the same field as `bool | null` per the API contract; the desktop's sentinel is only its own internal modeling.
- **Did NOT extend the per-library Library entity in fluxora_core.** That entity is freezed and shared across mobile + desktop + future clients; reaching into it for desktop-only fields would force a mobile rebuild. Desktop subagent created a `LibraryCodecOverrides` sidecar entity stored in `apps/desktop/lib/features/library/domain/entities/library.dart` and threaded it through `library_state.codecOverrides: Map<String, LibraryCodecOverrides>`. Mobile is unaffected.
- **`UNSET` sentinel in `settings_service.update_settings`.** The kwargs all default to `None`, but `None` is also the in-band "explicitly clear this column" value for `transcode_cache_root` (so the operator can clear back to the data-dir default). The server subagent introduced a module-level `_UNSET = object()` sentinel that both the API and the test fixtures use to distinguish "kwarg not provided" from "kwarg = None". This is on the server side; desktop's PATCH body just omits or sets `null` per the existing convention.

### Issues / Sharp Edges Discovered

1. **No per-library size breakdown in the storage endpoint.** The desktop's library-delete confirmation says "Also delete N transcoded sidecars" but renders the checkbox without the N — `GET /transcode/storage` returns aggregate size only, not per-library. Adding a `by_library: dict[str, {count, bytes}]` field to `TranscodeStorageResponse` is a small server-side enhancement; deferred to a follow-up round.
2. **Folder-tree memoisation isn't there yet.** `buildFolderTree()` runs on every Candidates rebuild. Free for ≤17 candidates (the typical home-server scale); at 5000+ candidates it'd want caching keyed by `state.candidates.identityHashCode`. Not blocking for v1.
3. **`ApiClient.delete` had no query-param hook.** Desktop subagent appended `?delete_sidecars=…` to the path string. Worth landing a proper `delete<T>(path, {queryParameters})` overload eventually for consistency with the GET / POST / PATCH variants.
4. **`Process.start("explorer", [path])` exit code on Windows.** The Windows-side "Open folder" affordance returns non-zero exit codes even on success in some cases; desktop subagent wraps the call in try/catch and only surfaces a SnackBar on actual exceptions. Worth migrating to `url_launcher`'s `file://` URI eventually for parity with the existing `_ExternalLinkRow` pattern.
5. **Cancel button text style.** The Queue / Library-delete confirmation modals use the platform-default `TextButton` for `[Cancel]` — there's no explicit FluxButton variant for "muted cancel". Consistent with existing dialogs in the codebase, but worth a future M14 visual-polish pass.

### Test Counts (re-baselined)

- **Server: 734 → 775 passing** (+41 across the 5 milestones; majority in `test_transcode_service.py` for preset map + sidecar paths + crash recovery, plus `test_settings_extended.py` for cache-root validation, plus `test_library.py` for delete-with-sidecars, plus `test_stream.py` for per-library override resolution).
- **Desktop: 104 → 113 passing** (+9 in `transcode_cubit_test.dart` for storage / preset / folder tree / expand-state).
- **Mobile: 78 passing** (unchanged — plan 19 has zero mobile changes).
- **Core: 8 passing** (untouched).

`flutter analyze lib/features/transcode lib/features/library` clean. `ruff check` clean. Server suite ran in 227 s.

### Working-Tree Status

All plan-19 close-out changes uncommitted on top of `627cdf1`. Operator-asked single consolidating commit covering both subagents' output + the doc updates.

### Next Agent Should

1. **Real-device retest of the full transcode-with-presets flow.** Queue an AV1 file on `recommended` preset, verify sidecar lands at the new dedicated cache root with `~2×` source size (vs the `~4×` of the old `mastering` default that motivated this whole round). Compare against `smaller` preset and verify it's `~1.2×`.
2. **Per-library override real-device test.** Mark a library as "always transcode" via the segmented control, play an AV1 file from that library, confirm server log says `mode=transcode(...)` even though global setting is `client-decode`. Then mark the library "use global" and verify it goes back to `mode=stream-copy(av1/fmp4)`.
3. **Library-delete-with-sidecars real-device test.** Delete a library that has transcoded sidecars; verify all sidecar files on disk are removed when the checkbox is checked, preserved when unchecked.
4. **`_seekRelative` mobile bug** (still carried forward — double-tap-skip after a forward server-restart still bugged; flagged in the prior AGENT_LOG entry but not yet fixed).
5. **`current_status.md` is over 25 k Read-cap.** Carried forward.
6. **Add per-library breakdown to `/transcode/storage`** when an operator round comes through — closes Sharp Edge #1 (the missing N in the delete confirmation).

---

## [2026-05-10] [server] [desktop] [core] [fix] [tests] — Plan 19 close-out sharp edges resolved (all 4)

**Phase:** Phase 2 — closing the 4 sharp edges flagged at plan-19 close-out
**Status:** Complete. All 4 sharp edges from `c175084`'s archive note are fixed.
**Commits:** uncommitted

### What Was Done

The plan-19 close-out commit (`8efd180`) flagged 4 sharp edges as "follow-up enhancements, not unfinished plan-19 work." Operator scoped them as a single fix-round; all four landed cleanly.

#### 1. `/transcode/storage` — `by_library` breakdown (fix #1)

The library-delete confirmation modal had been showing "Also delete N transcoded sidecars" with no actual N — the storage endpoint surfaced aggregate cache size only. Extended the SQL aggregate in `services/transcode_service.py::storage_aggregate` with a per-library `LEFT JOIN libraries` query (so files orphaned by a previous library-delete still bucket under `(orphaned)` rather than disappearing from the strip). Pydantic `TranscodeStorageResponse` gains `by_library: dict[str, dict] = Field(default_factory=dict)`.

Desktop: `TranscodeStorage` entity gains a `byLibrary: Map<String, TranscodeStorageLibraryBreakdown>` field; `library_screen.dart::_confirmRemove` does a one-shot `getStorage()` fetch on dialog open (best-effort — falls back to the count-less copy if the request fails) and renders the actual N + GB inline:

> *Also delete 12 transcoded sidecars (5.4 GB)*  
> *Removes any H.264 transcoded files this library produced. Source files are never touched.*

#### 2. Folder-tree memoisation (fix #2)

`buildFolderTree<T>` runs the recursive directory grouping + alphabetical sort on every Candidates / History rebuild. Free at the typical ≤17-candidate scale; quadratic at 5000+ where the children-search at each level becomes an O(N) `firstWhere`. Wrapped the function with an `Expando<FolderNode<dynamic>>` keyed by the leaves list reference: same `List<T>` → cached tree returned in O(1); new list (cubit emitted fresh state) → recompute. Cast back to `FolderNode<T>` is safe because a single list reference can only carry one element type. Iterables that aren't `List<T>` (transient `where`/`map` chains) skip the cache entirely — they'd never hit it anyway.

#### 3. `ApiClient.delete` query-param hook (fix #3)

`packages/fluxora_core/lib/network/api_client.dart::delete` gained a `queryParameters: Map<String, dynamic>?` named param mirroring the GET / POST / PATCH variants. Forwards to dio's existing `queryParameters` arg. Desktop's `library_repository_impl.dart::deleteLibrary` no longer hand-builds `${path}?delete_sidecars=$bool` — passes the boolean via the new param.

#### 4. `Process.start` → `url_launcher` (fix #4)

`storage_strip.dart::openPathInFileManager` was spawning `explorer` / `open` / `xdg-open` via `Process.start` and wrapping in try/catch because Windows `explorer` returns non-zero exit on success in some cases, making the error-handling unreliable. Replaced with `url_launcher`'s `launchUrl(Uri.file(path))` — the OS handles the file:// scheme via its native opener and returns a clean bool, which we surface in the SnackBar on failure. Dropped the `dart:io` `Platform` + `Process` imports.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Modified | apps/server/services/transcode_service.py | `storage_aggregate` adds per-library LEFT JOIN aggregate |
| Modified | apps/server/models/transcode.py | `TranscodeStorageResponse.by_library` field |
| Modified | packages/fluxora_core/lib/network/api_client.dart | `delete()` accepts `queryParameters` |
| Modified | apps/desktop/lib/features/library/data/repositories/library_repository_impl.dart | Use `queryParameters` instead of path-string concat |
| Modified | apps/desktop/lib/features/transcode/domain/entities/transcode_storage.dart | New `TranscodeStorageLibraryBreakdown` + `byLibrary` field |
| Modified | apps/desktop/lib/features/library/presentation/screens/library_screen.dart | One-shot `getStorage()` fetch on delete dialog open; renders N + GB; new `_formatBytes` helper |
| Modified | apps/desktop/lib/features/transcode/presentation/widgets/folder_tree.dart | `Expando`-keyed memoisation on `buildFolderTree` |
| Modified | apps/desktop/lib/features/transcode/presentation/widgets/storage_strip.dart | `Process.start` → `launchUrl(Uri.file(...))` |
| Modified | docs/10_planning/archive/19_library_transcode_followups.md | Status banner notes all 4 sharp edges resolved 2026-05-10 |
| Modified | AGENT_LOG.md | This entry |

### Docs Updated

Plan 19's archive banner refresh + AGENT_LOG. Test counts unchanged (no test file changes — fixes are mechanical and exercise existing test paths).

### Decisions Made

- **`(orphaned)` synthetic library bucket in the storage aggregate.** Files whose `library_id` is NULL or points at a deleted library still exist on disk and the strip should account for them. The desktop's library-delete dialog won't surface this bucket (it queries by the specific library being deleted), but the aggregate strip will. Avoids a hidden discrepancy where total size != sum of per-library sizes.
- **Best-effort fetch on dialog open, no spinner.** The library-delete dialog calls `getStorage()` once when the user clicks Remove. If the request fails, the dialog renders without the count rather than blocking with a loading state. Operator's intent ("delete this library") shouldn't depend on the storage strip being reachable.
- **Memoisation is opt-in based on type.** `Expando` requires an Object key; `List<T>` is one but transient `Iterable<T>` chains aren't stable references. The `is List<T>` check skips the cache when the caller passes anything else — no false hits. History tab still rebuilds its sorted list per build (separate caching layer is a follow-up); Candidates tab gets the win immediately because the cubit holds a stable list.
- **Did NOT consolidate the 4 `_formatBytes` duplicates** in the desktop codebase. There are now 4 (added one in `library_screen.dart`). Eliminating them is a separate refactor — not part of "fix the 4 sharp edges". Comment on the new helper points at the duplicates.

### Issues / Sharp Edges Discovered

1. **`url_launcher` on Linux desktop requires `xdg-utils`.** On a fresh Linux install without `xdg-open` available, `launchUrl` returns false and the operator gets the SnackBar but no action. Pre-existing (the old code had the same dependency); just worth noting that the Linux runtime requirement is now `url_launcher_linux`'s prerequisite list rather than ours.
2. **History tab's folder-tree still recomputes per build** because it sorts in-place inside the build method (`state.jobs.toList()..sort(...)`). The memoisation only helps when the caller passes a stable list; History creates a fresh sorted list each time. Move the sort into the cubit when an operator round comes through; leave as-is for now since History rarely has 1000+ entries.
3. **Per-library `(orphaned)` bucket isn't surfaced in the desktop UI yet.** The aggregate strip shows it because the by-codec section folds NULL-library-id files into the totals, but there's no per-library row for the orphaned bucket. Could add a "Cleanup orphaned sidecars" affordance in a future round.

### Test Counts (re-baselined)

- **Server: 775 passing** (unchanged — `by_library` field is additive on an existing endpoint; existing tests still pass; new field rendering is exercised through the desktop).
- **Mobile: 78 passing** (unchanged).
- **Desktop: 113 passing** (unchanged — fixes are mechanical and exercise existing test paths; no new tests needed).
- **Core: 8 passing** (untouched).

`flutter analyze lib` clean (full lib, not just transcode + library subtrees). `ruff check` clean. Server suite ran in 169 s.

### Working-Tree Status

All 4 fixes uncommitted on top of `c175084`. Single consolidating commit covering all 4.

### Next Agent Should

1. **Real-device retest of the library-delete confirmation** — confirm the operator sees "Also delete 12 transcoded sidecars (5.4 GB)" with the actual count + size on a library that has sidecars; confirm the count-less fallback copy renders cleanly when `getStorage()` fails (kill the server while the dialog opens).
2. **Real-device retest of the folder tree on a 5000+-candidate dataset** — synthetic test would suffice. Confirm scrolling is smooth and the tree doesn't recompute on every parent rebuild (instrumentation: temporary `print` in `buildFolderTree` or wrap with a counter Expando).
3. **`_seekRelative` mobile bug** (still carried forward — never fixed; double-tap-skip after a forward server-restart bugged).
4. **History-tab folder-tree sort move into cubit** (Sharp Edge #2 of this round) — small, defer until an operator round.
5. **`current_status.md` 25 k Read-cap** carried forward.

---

## [2026-05-12] [feat] [docs] — plan 20 — auto streaming mode + opt-in fallback

**Phase:** Phase 2 — transparent client-error fallback for mixed device pools
**Status:** Complete (code shipped; this entry covers the doc-update protocol sweep)
**Commits:** uncommitted

### What Was Done

Doc-update-protocol sweep for plan 20 (`docs/10_planning/20_auto_streaming_mode.md`). Plan 20 adds a third opt-in `streaming_mode='auto'` value that lets the server transparently fall back from stream-copy to transcode if a mobile player emits an error within 6 s of `PlayerReady`. All documentation updated; no code or tests modified in this session.

Key changes implemented:

- **Plan 20 code (already shipped before this session):** `'auto'` mode + per-client codec blocklist + `POST /api/v1/stream/{session_id}/fallback-transcode` + `stream_decision` diagnostic log + mobile auto-fallback watcher + desktop 3-option `_StreamingModeCard` + migrations 032 + 033 + `services/client_codec_service.py`.
- **`current_status.md`** — new 2026-05-12 lead paragraph with full plan-20 summary; test counts updated (server 775 → 792; mobile 78; desktop 113 unchanged).
- **`docs/04_api/01_api_contracts.md`** — `streaming_mode` section widened to 3-value table; new `POST /fallback-transcode` endpoint documented in full (body, response, all 6 status codes, blocklist semantics); new `StreamStartResponse` section documenting `streaming_mode` field.
- **`docs/09_backend/01_backend_architecture.md`** — status header updated; migrations 032 + 033 added to structure; `stream.py` router entry updated with fallback endpoint; `ffmpeg_service.py` entry updated with `_session_force_transcode` + `stream_decision` log; `client_codec_service.py` added to both file tree and Service Map; `stream_session.py` models updated; `test_client_codec_service.py` added to test list; total 775 → 792.
- **`docs/08_frontend/01_frontend_architecture.md`** — status header updated with plan-20 mobile watcher + desktop 3-option card; `player_cubit_test.dart` entry updated; `encoder_settings_screen.dart` entry updated.
- **`docs/03_data/02_database_schema.md`** — status header updated; `user_settings.streaming_mode` column updated to 3-value CHECK; `client_codec_blocklist` schema block added; migrations 032 + 033 rows added to Applied Migrations.
- **`docs/03_data/04_migration_guide.md`** — Last Updated header; file layout extended to 033; test count 775 → 792.
- **`docs/10_planning/01_roadmap.md`** — new plan-20 row (✅ Done 2026-05-12) added before the plan-19 row.
- **`docs/12_guidelines/03_gotchas.md`** — new gotcha: "Operator reports 'server is still using CPU/GPU during client-decode mode'" with the `stream_decision` grep workflow + reason enum table.

### Files Created / Modified

| Action | Path | Why |
|--------|------|-----|
| Modified | docs/00_overview/current_status.md | New 2026-05-12 lead paragraph; test counts 775/78/113 |
| Modified | docs/04_api/01_api_contracts.md | `streaming_mode` 3-value table; `POST /fallback-transcode` full schema; `StreamStartResponse.streaming_mode` field |
| Modified | docs/09_backend/01_backend_architecture.md | Migrations 032+033; client_codec_service; ffmpeg_service plan-20 notes; stream.py fallback endpoint; stream_session.py models; test_client_codec_service.py; total 775→792 |
| Modified | docs/08_frontend/01_frontend_architecture.md | Plan-20 mobile watcher + desktop 3-option card; encoder_settings_screen + player_cubit_test updates |
| Modified | docs/03_data/02_database_schema.md | streaming_mode 3-value CHECK; client_codec_blocklist table block; migrations 032+033 in Applied Migrations |
| Modified | docs/03_data/04_migration_guide.md | File layout to 033; Last Updated header; test count 775→792 |
| Modified | docs/10_planning/01_roadmap.md | Plan-20 row ✅ Done 2026-05-12 |
| Modified | docs/12_guidelines/03_gotchas.md | New auto-mode / stream_decision gotcha |
| Modified | AGENT_LOG.md | This entry |
| (shipped pre-session) | apps/server/database/migrations/032_streaming_mode_auto.sql | Widen streaming_mode CHECK to add 'auto' |
| (shipped pre-session) | apps/server/database/migrations/033_client_codec_blocklist.sql | New client_codec_blocklist table |
| (shipped pre-session) | apps/server/models/settings.py | streaming_mode Literal widened to 3 values |
| (shipped pre-session) | apps/server/models/stream_session.py | StreamStartResponse.streaming_mode field; FallbackTranscodeRequest/Response |
| (shipped pre-session) | apps/server/services/settings_service.py | _defaults() + kwarg mapping for streaming_mode='auto' |
| (shipped pre-session) | apps/server/services/ffmpeg_service.py | _session_force_transcode dict; set_session_force_transcode helper; stream_decision log line; _resolve_codec_passthrough session_force_transcode arg |
| (shipped pre-session) | apps/server/services/client_codec_service.py | New — is_blocked + add_block (idempotent) |
| (shipped pre-session) | apps/server/routers/stream.py | POST /fallback-transcode endpoint; StreamStartResponse.streaming_mode; client_codec_service.is_blocked consult under auto mode |
| (shipped pre-session) | apps/server/tests/test_settings.py | Extend default-value asserts to 'auto'; extend Literal accept-list |
| (shipped pre-session) | apps/server/tests/test_stream.py | test_fallback_transcode_endpoint_*; test_start_stream_consults_codec_blocklist; test_codec_passthrough_session_force_transcode_overrides_all |
| (shipped pre-session) | apps/server/tests/test_client_codec_service.py | New — is_blocked / add_block round-trip |
| (shipped pre-session) | apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart | 3-option _StreamingModeCard |
| (shipped pre-session) | apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart | streamingMode load + save wiring |
| (shipped pre-session) | apps/desktop/lib/features/settings/presentation/cubit/settings_state.dart | streamingMode field; default stays 'client-decode' |
| (shipped pre-session) | apps/mobile/lib/features/player/domain/repositories/player_repository.dart | reportFallbackTranscode method |
| (shipped pre-session) | apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart | POST /fallback-transcode API call |
| (shipped pre-session) | apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart | 6 s auto-fallback watcher (only when streamingMode='auto'); cancel on first successful frame |

### Docs Updated

- `docs/00_overview/current_status.md`
- `docs/04_api/01_api_contracts.md`
- `docs/09_backend/01_backend_architecture.md`
- `docs/08_frontend/01_frontend_architecture.md`
- `docs/03_data/02_database_schema.md`
- `docs/03_data/04_migration_guide.md`
- `docs/10_planning/01_roadmap.md`
- `docs/12_guidelines/03_gotchas.md`

### Test Counts (re-baselined)

- **Server: 792 passing** (+17 from test_stream.py plan-20 cases + test_client_codec_service.py)
- **Mobile: 78 passing** (unchanged)
- **Desktop: 113 passing** (unchanged)
- **Core: 8 passing** (untouched)

### Next Agent Should

1. **Real-device verification of `auto` mode** — point a real device at an AV1 source with `streaming_mode='auto'`, confirm the player loads, then force a player error (simulate by using a codec the device can't hardware-decode); verify server log shows `stream_decision … path=transcode reason=forced-fallback` on the second start, and that a row now exists in `client_codec_blocklist`; verify that subsequent plays of the same codec on that device start directly in transcode (no second 6 s window).
2. **Verify blocklist persists across server restarts** — the `client_codec_blocklist` table is DB-persisted (not in-memory), so it should survive a server process restart. Confirm the behaviour holds: start a session under auto, trigger a fallback, restart the server, play the same file on the same device — server should start in transcode from the first attempt.
3. **Consider extending the fallback watcher to buffer stalls** — the current watcher only fires on hard player errors (`player.stream.error`). Prolonged buffer stalls (e.g. `VideoState.buffering` for > 15 s) are a softer signal that the device is struggling; extending the watcher to cover stalls would catch more client-decode failures in the wild. This is a plan-21 candidate.
4. **Consider desktop player auto-fallback** — the desktop has a player feature at `apps/desktop/lib/features/player/`; the plan-20 doc notes "mirror mobile" but the desktop player may not be fully wired yet. If desktop can also play media, it should also benefit from the auto-fallback watcher.

---

## [2026-05-12] [docs] — Archive plan 20 (auto streaming mode)

**Phase:** Phase 2 — close-out
**Status:** Complete
**Commits:** uncommitted

### What Was Done

Plan 20 was marked ✅ shipped 2026-05-12 in its doc and a doc-update-protocol sweep had already landed earlier the same day. Moved the plan doc into the archive folder and updated the two external references that pointed at the live path.

No code, tests, or data touched. No new design work — this is the close-out file move only.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Renamed | docs/10_planning/20_auto_streaming_mode.md → docs/10_planning/archive/20_auto_streaming_mode.md | Plan complete; move to archive folder per project convention (matches plan 15 / plan 19 archival pattern) |
| Modified | docs/10_planning/01_roadmap.md | Plan-20 row link updated to `./archive/20_auto_streaming_mode.md`; "archived 2026-05-12" appended |
| Modified | CLAUDE.md | New "Where the detail lives" row added for archived plan 20, placed after the plan-19 archive row |
| Modified | AGENT_LOG.md | This entry |

### Docs Updated

- `docs/10_planning/01_roadmap.md`
- `CLAUDE.md`

### Working-Tree Status

Plan 20's implementation files (migrations 032 + 033, server/mobile/desktop changes from the doc) are **still uncommitted** in the working tree — the original "shipped" plan-20 commit was never made. The archival edits in this entry stack on top of that uncommitted state. When the operator commits, both rounds will land together (or in two commits at their discretion).

### Next Agent Should

1. **Wait for operator's commit decision on plan-20 + archive bundle** — operator owns all git writes per CLAUDE.md Hard Prohibition #1. The current working tree has plan-20 code (server migrations, models, services, router, mobile/desktop player + settings) + this archival doc shuffle, none of it committed.
2. **Plan 21 (client-side audio decoding) is in the design-question phase** — four design questions surfaced in chat were left unanswered: audio codec allowlist scope (DTS/TrueHD policy), HLS fmp4 switch for non-AAC + H.264 sessions, blocklist granularity (separate audio table vs combined), and fallback scope (audio-only re-encode vs full transcode). Once answered, draft `docs/10_planning/21_client_audio_decoding.md` mirroring plan-20's structure and run the standard milestone cadence (M1 migration → M5 docs sweep). The Next-Agent guidance in the previous log entry called this "a plan-21 candidate" specifically for the buffer-stall extension; the audio-decoding plan would consume the 21 number.

---

## [2026-05-12] [feat] [docs] [server] [mobile] [desktop] — plan 20 course corrections · plan 21 drafted

**Phase:** Phase 2 — close-out
**Status:** Complete
**Commits:** uncommitted (bundled with plan-20 implementation + archival from earlier 2026-05-12 entries)

### What Was Done

Operator reviewed shipped plan-20 behavior and requested three course corrections, then a parallel agent drafted plan 21 on top of the corrected baseline.

#### 1. Plan-20 course corrections

The earlier same-day plan-20 shipping made `auto` the new default streaming mode and unconditionally armed the mobile auto-fallback watcher on every session. Operator pushed back: (a) `auto` should be opt-in, not default; (b) fallback should only fire under `auto` — strict `client-decode` must surface errors to the user; (c) the `Recommended` badge on the encoder-settings card should sit on `client-decode`, not `auto`.

Applied corrections:

- **Server default** flipped back to `client-decode` in `models/settings.py` `UserSettingsResponse` Literal default + `services/settings_service.py::_defaults()`.
- **Migration 032 simplified** — dropped the CASE preserve/bump rule; the rewrite now just widens the CHECK + carries existing values forward. Default in the DDL is now `client-decode` to match the model default.
- **Fallback endpoint gated on auto** — `POST /api/v1/stream/{session_id}/fallback-transcode` now returns 409 when `streaming_mode != 'auto'` (after the existing 404 + 403 checks). The detail message names the current mode so the operator can act on it without log-spelunking.
- **Blocklist consult gated on auto** — `routers/stream.py::start_stream` reads `settings_row` once; the `client_codec_blocklist` lookup runs only when `effective_mode == 'auto'`. Strict modes ignore the blocklist entirely.
- **`StreamStartResponse.streaming_mode` added** — server includes the effective mode in the response so the mobile cubit can decide whether to arm the watcher without a separate settings round-trip. Field added to both `models/stream_session.py` and the mobile entity at `apps/mobile/lib/features/player/domain/entities/stream_start_response.dart` (defaults to `client-decode` for graceful pre-plan-20 server responses).
- **Mobile watcher gated** — `PlayerCubit.startStream` now only calls `_scheduleAutoFallbackWatcher` when `response.streamingMode == 'auto'`. Strict modes let any `player.stream.error` bubble up unchanged, so the user sees the actual decode error instead of a misleading 409 from the server.
- **Desktop UI re-ordered + re-badged** — `_StreamingModeCard` order is now: Client decodes (subtitle `Recommended`, first), Auto (subtitle `Mixed device pools`, second), Server transcodes (subtitle `Legacy / every device`, third). `_streamingMode` initial-state fallback flipped from `auto` to `client-decode`. Same fallback in `settings_cubit.dart` and the `SettingsLoaded` constructor default in `settings_state.dart`.
- **`ffmpeg_service.py` resolver fallback** — both `_resolve_codec_passthrough` and the `stream_decision` log's `global_mode` branch fell back to `auto` when the setting was empty; both now fall back to `client-decode` to match the new default.
- **Server tests updated** — `test_get_settings_returns_defaults` asserts `streaming_mode == "client-decode"`; the four fallback-endpoint tests + the `start_stream_consults_codec_blocklist` test now seed `UPDATE user_settings SET streaming_mode = 'auto'` because the endpoint + blocklist are now gated on the mode. New test `test_fallback_transcode_returns_409_outside_auto_mode` covers the strict-mode rejection path.
- **Plan-20 doc rewritten** — the archived `docs/10_planning/archive/20_auto_streaming_mode.md` no longer claims `auto` is the new default. Behavior matrix swapped to show `client-decode` as the Recommended default and `auto` as opt-in. Migration block simplified to match the new SQL. Mobile + desktop sections note the watcher-only-fires-under-auto + the `streaming_mode` response field. Migration numbering also corrected (032/033 — 031 was already taken on main).

#### 2. Plan 21 drafted (separate agent)

While this session ran, a parallel agent answered the four design questions for client-side audio decoding and produced `docs/10_planning/21_client_audio_decoding.md`. Status `Drafted 2026-05-12 — awaiting M1 sign-off`. Locked decisions: allowlist `{aac, ac3, eac3, opus, flac}` (DTS/TrueHD excluded), fmp4 switch when audio codec is non-AAC, separate `client_audio_codec_blocklist` table (not combined with video), audio-only re-encode on fallback (video stays stream-copy), bitrate bump 128k → 256k AAC, source-channel preservation via `-ac` on remaining re-encode paths. ~12h across M1-M5. CLAUDE.md "Where the detail lives" table gained a row pointing at the new plan.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Modified | apps/server/database/migrations/032_streaming_mode_auto.sql | Simplified — dropped the CASE preserve/bump rule; widen CHECK + carry forward existing values; default `client-decode` |
| Modified | apps/server/models/settings.py | `streaming_mode` Literal default flipped `auto` → `client-decode` |
| Modified | apps/server/models/stream_session.py | `StreamStartResponse.streaming_mode` field added |
| Modified | apps/server/services/settings_service.py | `_defaults()["streaming_mode"]` flipped to `client-decode` |
| Modified | apps/server/services/ffmpeg_service.py | Resolver + `stream_decision` log fall back to `client-decode` when setting empty |
| Modified | apps/server/routers/stream.py | `/fallback-transcode` 409s outside auto mode; blocklist consult in `/start` gated on auto mode; `/start` response carries `streaming_mode` |
| Modified | apps/server/tests/test_settings.py | Defaults assert `client-decode`; Literal accept-list tests unchanged |
| Modified | apps/server/tests/test_stream.py | Auto-mode setup added to 4 fallback tests + blocklist-consult test; new `test_fallback_transcode_returns_409_outside_auto_mode` |
| Modified | apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart | 3 options re-ordered (client-decode first as Recommended, auto second, server-transcode third); initial-state fallback `client-decode` |
| Modified | apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart | Local fallback default flipped to `client-decode` |
| Modified | apps/desktop/lib/features/settings/presentation/cubit/settings_state.dart | `SettingsLoaded.streamingMode` default `client-decode` |
| Modified | apps/mobile/lib/features/player/domain/entities/stream_start_response.dart | New `streamingMode` field |
| Modified | apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart | Watcher armed only when `response.streamingMode == 'auto'` |
| Modified | docs/10_planning/archive/20_auto_streaming_mode.md | Doc rewritten — `client-decode` is the Recommended default; auto is opt-in; behavior matrix + migration block updated |
| Created | docs/10_planning/21_client_audio_decoding.md | Drafted by parallel agent — audio stream-copy plan |
| Modified | docs/10_planning/01_roadmap.md | Plan-21 row added under plan-20 |
| Modified | CLAUDE.md | "Where the detail lives" row added for plan 21 (drafted) |
| Modified | AGENT_LOG.md | This entry |

### Docs Updated

- `docs/10_planning/archive/20_auto_streaming_mode.md` — rewritten per course corrections (no longer claims `auto` is default)
- `docs/10_planning/21_client_audio_decoding.md` — new drafted plan (separate agent)
- `docs/10_planning/01_roadmap.md` — plan-21 row added
- `CLAUDE.md` — plan-21 row in "Where the detail lives"

### Decisions Made

1. **Recommended = `client-decode`, not `auto`** — the operator picked strict modern-device-only mode as the default because the v1 device target is post-2021 mobile + the operator's own dev hardware; auto's transparent-fallback win is real but the cost (one bad session per device/codec combo before the blocklist learns) only matters with mixed device pools. Auto stays one click away in the Settings card for any operator who wants it.
2. **`StreamStartResponse.streaming_mode`** is the right plumb, not a separate `/api/v1/server/effective-mode` endpoint or a settings-cubit dependency in the mobile player cubit. The mobile cubit already reads the start response; adding a field has zero round-trip cost and keeps the player feature free of a settings cubit dependency.
3. **Blocklist scoped to auto mode** — strict `client-decode` ignores the blocklist (operator's pick wins). Without this, an operator switching from auto back to strict would still see preemptive transcoding for previously-flagged devices, which defeats the strict-mode contract.
4. **Migration 032 stays minimal** — earlier draft had a CASE statement preserving `server-transcode` rows and bumping everything else to `auto`. With the default flipping back to `client-decode`, that complexity is gone — we just widen the CHECK + carry forward existing values verbatim.

### Issues / Sharp Edges Discovered

1. **Non-auto error UX is whatever media_kit surfaces today** — in strict `client-decode` mode, a player error bubbles up via the existing `player.stream.error` path with no custom copy. There's no "Could not decode — try Auto in settings" affordance. If real-device testing shows users hit decode failures in strict mode and don't know what to do, add a non-auto error listener that emits `PlayerFailure` with actionable copy. Out of scope for this round; flagged for follow-up.
2. **Desktop has no player feature** — fallback wiring only exists on mobile. The desktop control panel doesn't play media; no parallel cubit to update. If desktop ever grows playback, mirror the mobile pattern (the repository method already exists).
3. **Pre-existing broken golden** — `apps/desktop/test/goldens/m3_dashboard_golden_test.dart` fails with a 62.74% pixel diff on `main`, unrelated to plan 20. Confirmed by stashing all session changes and re-running. Run `--exclude-tags=golden` until someone regenerates it.

### Test Counts (re-baselined)

- Server: **792 passing** (775 before plan 20 + 17 new across `test_stream.py`, `test_settings.py`, `test_client_codec_service.py`)
- Mobile: **78 passing** (unchanged — the player-cubit gating reuses existing tests; no new fallback-watcher gating test added, deferred to plan 21's M4 mobile sweep where the audio watcher needs the same gate)
- Desktop: **113 passing** (excluding pre-existing-broken golden)
- `ruff check .` clean; `flutter analyze apps/desktop/lib apps/mobile/lib` clean

### Working-Tree Status

All plan-20 implementation + course corrections + plan-21 draft are uncommitted in one working-tree state. Operator will commit this round as a single chunk (per their instruction). No code stash, no parallel branch.

### Next Agent Should

1. **Real-device verification of auto-mode fallback** — pair a device with a known-broken codec/device combo (10-bit AV1 on an RTX 20-series host targeting a pre-2021 Android), set `streaming_mode='auto'`, start a stream, confirm the 6 s watcher fires the fallback POST + the playlist reloads + the second session for the same (client, codec) starts in transcode directly. The persistent blocklist is the load-bearing piece — verify it survives a server restart.
2. **Decide on plan 21 M1 sign-off** — operator owns the green light. The doc at `docs/10_planning/21_client_audio_decoding.md` has the locked decisions + milestone breakdown. If approved, run M1 (migration 034 + `client_audio_codec_service.py` + tests) as a single subagent task; M2+ can follow the plan-20 two-parallel-subagents pattern partitioned along server/mobile.
3. **Consider a non-auto error UX affordance** — if operators in strict `client-decode` mode hit decode failures and don't know about the Auto toggle, the player should surface "Try Auto mode in Settings → Encoder Settings" alongside the raw error. Could ship as part of plan 21 M4 (mobile error sweep) since plan 21 adds audio-error UX surface anyway.
4. **Audit comment quality on the audio-passthrough resolver before M2 ships** — plan 21 §M2 introduces `_resolve_audio_passthrough` mirroring plan 20's `_resolve_codec_passthrough`. Make sure the two stay structurally aligned so a future operator can reason about both from one mental model; if the audio one accumulates special cases, factor out the shared shape.

---

## [2026-05-12] [plan-21 shipped] [docs] [server] [mobile] — plan 21 close-out: docs sweep + archive + AGENT_LOG

**Phase:** Phase 2 — streaming pipeline polish
**Status:** Complete
**Commits:** uncommitted

### What Was Done

M5 docs sweep for plan 21 (client-side audio decoding). All code (M1-M4) was already shipped by prior subagents. This session performed the documentation update protocol sweep, archived the plan, and wrote this log entry.

#### 1. `docs/00_overview/current_status.md`

Added a new "As of 2026-05-12 (latest)" block describing plan 21's shipped state. Bumped server test count header from 775 → 814. Updated migration range from 001-026 to 001-034. Updated mobile player cubit test count to 25 (was 21). Moved the plan-20 block to "Earlier 2026-05-12" to make room for plan-21.

#### 2. `docs/03_data/02_database_schema.md`

Updated status frontmatter line to include migration 034. Added new `client_audio_codec_blocklist` (Migration 034) section immediately after `client_codec_blocklist`, with full DDL, purpose, and independence note.

#### 3. `docs/03_data/04_migration_guide.md`

Updated last-updated frontmatter and migration range (001-033 → 001-034). Added `034_client_audio_codec_blocklist.sql` to the file-layout tree. Added "Parallel per-client blocklist tables (032–034)" pattern section describing the shared PK+FK shape, the lookup gate (auto-mode only), and why they're separate tables. Bumped test suite reference from 792 → 814.

#### 4. `docs/04_api/01_api_contracts.md`

Extended the `POST /api/v1/stream/start/{file_id}` response section to document `audio_streaming_mode: "stream-copy" | "transcode"` (plan 21 field, default `"transcode"`). Added full documentation for the new `POST /api/v1/stream/{session_id}/fallback-audio-transcode` endpoint (request shape, 200/404/403/409/422/429 status codes, blocklist semantics, relation to the video fallback endpoint).

#### 5. `docs/08_frontend/01_frontend_architecture.md`

Added entity/repository/impl inline comments for `audioStreamingMode` and `reportFallbackAudioTranscode`. Extended the `player_cubit.dart` entry to describe `_scheduleAutoAudioFallbackWatcher` (arming conditions, detection heuristics, 6 s window, cancel on non-empty audioParams). Updated player test file description to mention 25 total tests including plan-21 additions. Added "Desktop Has No Player Feature" section to permanently document that `apps/desktop/lib/features/player/` does not exist.

#### 6. `docs/09_backend/01_backend_architecture.md`

Added `034_client_audio_codec_blocklist.sql` to the migrations tree. Updated `stream.py` router description to include the new fallback-audio-transcode endpoint and audio-mode gate. Added `client_audio_codec_service.py` to the services tree. Updated `stream_session.py` model description to include `audio_streaming_mode` field and `FallbackAudioTranscodeRequest/Response`. Added `client_audio_codec_service` row to the service table. Updated FFmpeg Pipeline Detail to describe the audio stream-copy allowlist, `_resolve_audio_passthrough`, fmp4 trigger extension, 256k bitrate bump, `-ac` channel preservation, and the extended `stream_decision` log format. Bumped test count from 792 → 814.

#### 7. `docs/10_planning/01_roadmap.md`

Changed plan 21 row from "Drafted 2026-05-12 — awaiting M1 sign-off" to "Done 2026-05-12" with shipped feature summary and link to archived plan.

#### 8. `docs/12_guidelines/03_gotchas.md`

Added 6 new gotcha entries (no existing entries modified):
- Plan 21 audio stream-copy bandwidth uncapped (sharp edge #7)
- Plan 21 mid-stream audio codec changes (sharp edge #9)
- Plan 21 audioParams-silence heuristic fragility (sharp edge #1)
- Plan 21 `_ensure_fmp4_init_segment` audio codec mismatch (M2 agent sharp edge)
- Plan 21 duplicate `_probe_audio_params` per `/start` (M3 agent sharp edge)
- Desktop has no player feature (M4 agent finding)

#### 9. Plan archive

Copied `docs/10_planning/21_client_audio_decoding.md` → `docs/10_planning/archive/21_client_audio_decoding.md` with an "Archived 2026-05-12 — all 5 milestones shipped" header block. Deleted original. Updated CLAUDE.md "Where the detail lives" row (path + status label). Grepped docs/ and CLAUDE.md for stale references to the old path — zero found.

### Files Created / Modified

| Action | Path | Why |
|---|---|---|
| Created | apps/server/database/migrations/034_client_audio_codec_blocklist.sql | M1 — new audio blocklist table (done by prior M1 agent) |
| Created | apps/server/services/client_audio_codec_service.py | M1 — audio blocklist service (done by prior M1 agent) |
| Created | apps/server/tests/test_client_audio_codec_service.py | M1 — 6 tests for audio blocklist service (done by prior M1 agent) |
| Modified | apps/server/services/ffmpeg_service.py | M2 — audio allowlist, passthrough resolver, fmp4 extension, 256k bitrate, -ac channels (done by prior M2 agent) |
| Modified | apps/server/tests/test_stream.py | M2+M3 — 16 new tests for audio pipeline (done by prior M2/M3 agents) |
| Modified | apps/server/routers/stream.py | M3 — audio blocklist consult + fallback-audio-transcode endpoint (done by prior M3 agent) |
| Modified | apps/server/models/stream_session.py | M3 — audio_streaming_mode field + new request/response models (done by prior M3 agent) |
| Modified | apps/mobile/lib/features/player/domain/entities/stream_start_response.dart | M4 — audioStreamingMode entity field (done by prior M4 agent) |
| Modified | apps/mobile/lib/features/player/domain/repositories/player_repository.dart | M4 — reportFallbackAudioTranscode method (done by prior M4 agent) |
| Modified | apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart | M4 — POST /fallback-audio-transcode impl (done by prior M4 agent) |
| Modified | apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart | M4 — audio watcher logic (done by prior M4 agent) |
| Modified | apps/mobile/test/features/player/player_cubit_test.dart | M4 — 4 new audio watcher tests (done by prior M4 agent) |
| Modified | apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart | M4 — Auto card body text revised (done by prior M4 agent) |
| Modified | docs/00_overview/current_status.md | M5 — plan 21 shipped block; test count 814; migration range 001-034 |
| Modified | docs/03_data/02_database_schema.md | M5 — client_audio_codec_blocklist table section added; status line updated |
| Modified | docs/03_data/04_migration_guide.md | M5 — 034 entry in tree; parallel-blocklist pattern section; test count 814 |
| Modified | docs/04_api/01_api_contracts.md | M5 — audio_streaming_mode field + fallback-audio-transcode endpoint documented |
| Modified | docs/08_frontend/01_frontend_architecture.md | M5 — audio watcher in cubit; desktop-no-player section; test count 25 |
| Modified | docs/09_backend/01_backend_architecture.md | M5 — 034 migration; stream.py; client_audio_codec_service; model; FFmpeg section; test count 814 |
| Modified | docs/10_planning/01_roadmap.md | M5 — plan 21 row status flipped to Done; archive link added |
| Renamed | docs/10_planning/archive/21_client_audio_decoding.md | M5 — plan 21 archived with shipped-status header (moved from 21_client_audio_decoding.md) |
| Modified | docs/12_guidelines/03_gotchas.md | M5 — 6 new gotcha entries for plan 21 sharp edges |
| Modified | CLAUDE.md | M5 — plan 21 row path updated to archive; status label updated |
| Modified | docs/02_architecture/02_tech_stack.md | M5 — server test count 775 → 814 (stale value found in cross-reference sweep) |
| Modified | AGENT_LOG.md | M5 — this entry |

### Docs Updated

- `docs/00_overview/current_status.md` — plan 21 shipped block; test counts; migration range
- `docs/03_data/02_database_schema.md` — client_audio_codec_blocklist table section
- `docs/03_data/04_migration_guide.md` — 034 file tree entry; parallel-blocklist pattern section
- `docs/04_api/01_api_contracts.md` — audio_streaming_mode field; fallback-audio-transcode endpoint
- `docs/08_frontend/01_frontend_architecture.md` — audio watcher; desktop-no-player section; cubit description
- `docs/09_backend/01_backend_architecture.md` — 034 migration; services; models; FFmpeg pipeline detail
- `docs/10_planning/01_roadmap.md` — plan 21 status + archive link
- `docs/10_planning/archive/21_client_audio_decoding.md` — new (archived plan 21)
- `docs/12_guidelines/03_gotchas.md` — 6 new gotcha entries
- `docs/02_architecture/02_tech_stack.md` — server test count 775 → 814 (stale reference found during cross-reference sweep)
- `CLAUDE.md` — plan 21 "Where the detail lives" row updated

### Issues / Sharp Edges Discovered

No new issues. All sharp edges from M1-M4 agents were captured in the gotchas entries above. Cross-reference sweep found zero stale links to the old `21_client_audio_decoding.md` path.

### Test Counts (re-baselined)

- **Server: 814 passing** (+22 from plan 21 M1-M3: 6 audio-service tests + 9 ffmpeg-service tests + 7 router/endpoint tests)
- **Mobile player cubit: 25 passing** (+4 from plan 21 M4 audio watcher tests)
- **Desktop: 113 passing** (untouched in plan 21)
- **Core: 8 passing** (untouched)

### Next Agent Should

1. **Real-device audio fallback testing on iOS + Android** — use FLAC and AC3 source content, set `streaming_mode='auto'`, verify: (a) stream starts with `audio_streaming_mode='stream-copy'`; (b) on a device that can't decode FLAC, the 6 s audio watcher fires `POST /fallback-audio-transcode`; (c) the playlist reloads with audio transcoded; (d) subsequent sessions for the same `(client, audio_codec)` start directly in audio-transcode mode; (e) verify `_ensure_fmp4_init_segment` doesn't produce an AAC-config init segment for an AC3 stream-copy session (see gotchas).
2. **Server-side perf follow-up: deduplicate `_probe_audio_params`** — `routers/stream.py` calls `_probe_audio_params(file_path)` independently of `ffmpeg_service.start_stream`'s own probe; this is ~50-100 ms per session. Fix: pass the probe result through as an optional param to `start_stream`, or persist `audio_codec` + `audio_channels` on `media_files` at scan time. Track in `docs/10_planning/04_manual_tasks.md` as a performance follow-up.
3. **`_ensure_fmp4_init_segment` audio codec audit** — the helper's hard-coded `-c:a aac -b:a 128k` produces an AAC config box in `init.mp4`; when the session is streaming AC3/Opus/FLAC via stream-copy, the segments' audio box won't match. Fix: pass `audio_passthrough`, `source_audio_codec`, and `source_channels` to the helper and use `-c:a copy` when audio is stream-copied. Verify during real-device testing that this actually manifests (FFmpeg normally emits init.mp4 correctly; the helper only fires as a fallback).

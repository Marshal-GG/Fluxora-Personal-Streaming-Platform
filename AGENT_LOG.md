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

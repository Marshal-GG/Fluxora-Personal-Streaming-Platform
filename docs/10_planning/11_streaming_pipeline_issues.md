# Streaming Pipeline — Issue Audit & Remediation Plan

> **Category:** Planning
> **Status:** Active — Drafted 2026-05-05
> **Scope:** Identifies and prioritises every defect found in the HLS streaming pipeline (mobile/desktop player ⇆ server ⇆ FFmpeg) during the 2026-05-05 user-reported regression triage.  Lays out a sequenced remediation plan with concrete code targets, commit boundaries, and test strategy.
> **Triggered by:** four user-reported issues (seek delay, GPU/CPU pegging, "code error 1" on HDR→SDR toggle, HDR-not-working) — investigation surfaced six additional issues that share root causes with the reported ones.

---

## 1 · Executive Summary

The streaming pipeline shipped with the M2 LAN Streaming MVP and has been extended incrementally — Phase 6 added cuvid widening, manual fmp4 init segments, a static VOD playlist generator, and HDR→SDR tonemap.  Each feature works in isolation but the **integration assumes FFmpeg is fast and deterministic**, which doesn't survive contact with:

- CPU-bound filter chains (tonemap is ~0.6× realtime on the bundled FFmpeg).
- Users seeking the timeline (no architectural support — segments are produced strictly sequentially from `t=0`).
- Mid-session re-spins (tonemap toggle restarts the stream; orphans the previous FFmpeg until the OS cleans up).

**Headline failures (in user impact order):**

1. **Seek-ahead is unusable** — beyond the encoded portion, players hit 5 s router waits → 404, then stop.  Architectural — no `-ss` restart, no segment numbering shift.
2. **HDR→SDR toggle silently fails** with "exit code 1" + empty stderr.  Root cause is a 10 s playlist-appearance timeout that kills FFmpeg right as it produces the first tonemapped segment.
3. **Concurrent FFmpegs accumulate** when the user toggles tonemap or starts a second stream of the same file.  Old FFmpeg keeps churning until `_disposeCurrentSession` reaches it; on Android, lifecycle quirks can drop that hook entirely.
4. **HDR display tonemap doesn't happen client-side**, so users on SDR phones see washed-out HDR even when source is HDR10.  Server-side tonemap is the only fix and it's broken (issue #2).

**Cross-cutting symptom:** the `<no stderr captured>` diagnostic appears for at least three distinct failure modes, hiding the actual upstream FFmpeg error.  This is the single most-impactful diagnostic improvement we can ship.

**Sequenced remediation:** four commits, ~2 days of work end-to-end.  Commit 1 unblocks HDR users immediately; commits 2–3 ship the seek architecture; commit 4 closes the loop on diagnostics + zombie cleanup.  Detail in [§5](#5--remediation-plan).

---

## 2 · Current Architecture (one-page summary)

### 2.1 Player → server → FFmpeg flow

```
  Mobile player                        Server                            FFmpeg subprocess
  -------------                        ------                            ------------------
  POST /api/v1/stream  ───────────▶  start_stream ()
                                       ├── resolve codec / hdr_format
                                       ├── pick encoder via priority chain
                                       ├── build HLS cmd
                                       └── spawn   ──────────────────▶  ffmpeg -i <file> -ss N? \
                                                                          -c:v <encoder> \
                                                                          -hls_time 6/10 \
                                                                          -hls_list_size 0 \
                                                                          ...
                                                                            ↓ writes segments
                                                                            <hls_root>/<sid>/seg00000..N.m4s
                                                                            <hls_root>/<sid>/init.mp4 (fmp4)
                                                                            <hls_root>/<sid>/playlist.m3u8 ← polled
  ◀────── { playlistUrl, sessionId, resumeSec, hdrFormat, tonemapped }
  open(playlistUrl) ─────────────▶  GET /hls/{sid}/playlist.m3u8
  GET seg00000.m4s ──────────────▶  serve from disk
  GET seg00001.m4s ──────────────▶  serve
  ...
  user seeks to 5 min ───────────▶  GET seg00050.m4s   (does not exist yet; FFmpeg at seg00007)
                                     ├── wait 5 s polling disk
                                     └── 404 Segment not found  ❌
  PATCH /progress { sec: N } ────▶  update DB (resume marker)
  DELETE /stream/{sid} ──────────▶  stop_stream (kills FFmpeg, cleans dir)
```

### 2.2 Key files

| Concern | Path |
|---|---|
| Stream router (REST surface) | [`apps/server/routers/stream.py`](../../apps/server/routers/stream.py) |
| FFmpeg command builder + spawn loop | [`apps/server/services/ffmpeg_service.py`](../../apps/server/services/ffmpeg_service.py) |
| Encoder registry (per-encoder args) | [`apps/server/services/encoder_registry.py`](../../apps/server/services/encoder_registry.py) |
| Encoder priority chain / fallback | [`apps/server/services/session_router.py`](../../apps/server/services/session_router.py) |
| Mobile player cubit | [`apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart) |
| Mobile player overlay (seek bar, HDR toggle) | [`apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart`](../../apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart) |

### 2.3 Pipeline modes

| Mode | Trigger | CPU/GPU | Output |
|---|---|---|---|
| Stream-copy mpegts | source = h264 | Negligible | mpegts segments + plain m3u8 |
| Stream-copy fmp4  | source = hevc | Negligible | fmp4 segments + `EXT-X-MAP init.mp4` |
| Transcode | source ≠ h264/hevc, OR tonemap requested | Heavy | encoder-defined (NVENC/QSV/VAAPI/sw); fmp4 if encoder.segment_fmt = "fmp4" |

### 2.4 Static VOD playlist (post-2026-05-04)

After `_spawn_ffmpeg_attempt` succeeds, the server overwrites FFmpeg's growing playlist with a complete `#EXT-X-PLAYLIST-TYPE:VOD` listing **every segment FFmpeg will eventually write**, derived from `media_files.duration_sec ÷ hls_time`.  When the player asks for a segment FFmpeg hasn't produced yet, the [HLS route waits up to 5 s](../../apps/server/routers/stream.py) for it to appear, then 404s.

This works for sequential playback but **assumes the user only plays forward at ≤1× speed** — the moment they seek beyond the encoded boundary, the static list lies and the wait-then-404 loop kicks in.

---

## 3 · Issues — Reported by User (2026-05-05)

### 3.1 Seek-ahead takes minutes or 404s

**Symptom (verbatim):** "when i seek fwd the video it takes ages to video to play again if i get lucky"

**Root cause:** No `-ss` restart on seek.  FFmpeg encodes strictly from `t=0`.  The static VOD playlist tells the player segment N exists at any timestamp the user picks, but disk-backed segment N only appears after FFmpeg has linearly encoded its way there.

For **stream-copy** sources (H.264, HEVC), encoding is just remuxing, so the `(N × hls_time)` second wait is bearable for short seeks but kills mid-movie jumps.

For **transcode** sources (anything else, including any HDR→SDR tonemap session at 0.6× realtime), the wait can exceed 1 minute even for modest seeks.

**Server-side bandage:** [`stream.py:374`](../../apps/server/routers/stream.py#L374) waits 5 s for a missing segment to appear before 404.  That's enough to absorb the gap between "playlist ready" and "first segment flushed" but does nothing for genuine seek-ahead.

**Player-side amplification:** mobile player uses `media_kit` which retries 404s a small number of times before giving up.  `ffmpeg`-the-encoder doesn't know the user seeked, so it never even tries to catch up to the requested position.

**Code targets:**
- [`apps/server/routers/stream.py`](../../apps/server/routers/stream.py) — new `POST /api/v1/stream/{session_id}/seek` endpoint.
- [`apps/server/services/ffmpeg_service.py`](../../apps/server/services/ffmpeg_service.py) — new `restart_stream(session_id, seek_sec)` that kills and respawns with `-ss` + `-hls_start_number`.
- [`apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart) — debounce seek-bar drag → call seek endpoint → re-open `Media` with the new playlist URL.

---

### 3.2 HDR → SDR toggle: "code error 1", video does not play

**Symptom (verbatim):** "if i change hdr stream to sdr via toggle video dont even play gives code error 1"

**Root cause:** The 10 s playlist-appearance timeout in [`_spawn_ffmpeg_attempt`](../../apps/server/services/ffmpeg_service.py#L588) kills FFmpeg before it produces its first tonemapped segment.  `proc.terminate()` on Windows calls `TerminateProcess(handle, 1)`, so the **returncode appears as 1** even though FFmpeg never voluntarily exited with that code.

**Confirmed by reproduction:** running the exact tonemap pipeline manually on a real HDR10 source (`Genshin Impact 2026.04.28 - 01.45.00.02.mp4`) succeeds with `exit code 0` after ~80 wall-seconds for 47 source-seconds (0.595× realtime).  First HLS segment of 6 source-seconds at 0.595× = ~10 wall-seconds — exactly when the timeout fires.

**Why stderr is empty:** the `-loglevel error` filter combined with FFmpeg's stderr buffering means nothing reaches our captured tempfile before the kill.  Operator sees `<no stderr captured>` instead of a real diagnostic.

**Why the cuvid retry doesn't save it:** [`start_stream`](../../apps/server/services/ffmpeg_service.py#L657) sets `first_attempt_gpu_input = not apply_hdr_tonemap`, so the second-attempt retry path is gated on `used_gpu_input` which is False for tonemap sessions.  The retry exists for cuvid failures, not tonemap-slowness failures.

**Code targets:**
- [`apps/server/services/ffmpeg_service.py`](../../apps/server/services/ffmpeg_service.py#L630) — make the playlist-appearance timeout pipeline-aware: 60 s for tonemap sessions, 30 s for non-NVENC transcode, 10 s for stream-copy / NVENC.
- Same file — distinguish "killed by us" from "exited on its own" in the diagnostic; "exit code 1" on a process we just terminated is misleading.

---

### 3.3 GPU/CPU pegs on every stream

**Symptom (verbatim):** "for each stream gpu and cpu going crazy"

**Root cause(s) — three contributors:**

#### 3.3a · Zombie FFmpeg from rapid session re-spins

`PlayerCubit.setTonemap()` calls `startStream()` which calls `_disposeCurrentSession()` first → `await _repository.stopStream(_sessionId!)` → server kills the previous FFmpeg.  But:

- The await is inside a try/catch that **swallows network errors**, so a transient network blip leaves the previous server-side session running.
- On rapid re-toggling (HDR toggle, file change), the dispose is sequential: ~1 s of wall time during which the old FFmpeg is still encoding.
- When mobile is backgrounded mid-toggle, Android's process priority can suspend the cubit before its `stopStream` call completes — the old FFmpeg orphans server-side until next startup's `_close_orphaned_sessions` housekeeping (which only marks the DB row, doesn't kill the process).

#### 3.3b · Tonemap is CPU-only

`zscale` + `tonemap=hable` filters run on the CPU.  On any HDR10 source ≥1080p, that's enough work to peg multiple cores even on a 12-core box.  Independent of session count.

#### 3.3c · Encoder priority chain may pick software fallback silently

When the priority chain falls through `nvenc → qsv → libx264` on a machine where QSV self-test failed (the user's case — old Intel driver predates oneVPL, classifier in `transcoding_service.classify_encoder_failure` recognises this and surfaces a notification), the chain advances to libx264 — software encode at full HD pegs the CPU at 100 %.  Operator can't tell from the player whether they're on hardware or software.

**Code targets:**
- [`apps/server/services/ffmpeg_service.py`](../../apps/server/services/ffmpeg_service.py) — `start_stream` should reject (or kill-and-replace) any prior active session for the same `(client_id, file_id)` before spawning a new FFmpeg.
- [`apps/server/main.py`](../../apps/server/main.py) — `_close_orphaned_sessions` startup hook should also kill any tracked subprocess, not just stamp `ended_at`.
- Mobile cubit — `_disposeCurrentSession` should treat `stopStream` failures as fatal-for-the-old-session and stamp it locally so the next start doesn't pile on.
- (Lower priority) Desktop — Active-session card should label hardware vs software encoder visibly so operator notices CPU-mode immediately.

---

### 3.4 HDR is "not even working"

**Symptom (verbatim):** "hdr is not even working"

**Root cause:** when the tonemap toggle is OFF and the source is HDR10 HEVC, the server stream-copies the bitstream.  The player receives raw BT.2020 PQ (HDR10) HEVC.  **`media_kit` (libmpv on Android) does not perform display-side tonemap on most consumer Android devices** — it renders the BT.2020 frames straight to a BT.709 SDR display.  Result: washed-out, low-contrast, muted colors.  Looks "broken" even though playback is technically working.

**Why the toggle exists:** server-side tonemap (issue #2) is the only working path.  Once issue #2 is fixed, the toggle does what users expect.

**iOS path:** AVPlayer-backed stacks do display tonemap.  Mobile uses media_kit on both platforms, so iOS likely has the same issue.

**This is not a server bug** — it's a player-renderer limitation that the server-side tonemap toggle is supposed to compensate for.  Documenting here for completeness; remediation = ship #2 cleanly + UX work to surface the toggle prominently when source is HDR + display is SDR.

**Code targets:**
- (After #2 ships) [`apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart`](../../apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart) — auto-suggest tonemap when `hdrFormat != null` on first playback; persist user's choice per device so we don't keep suggesting after they've answered.
- (Stretch) Detect display HDR capability (Android `Display.getHdrCapabilities()`); only suggest tonemap when display is SDR.

---

## 4 · Issues — Spotted During Investigation

These weren't user-reported but came out of the same code paths.

### 4.1 `<no stderr captured>` for at least three distinct failure modes

**Where:** [`ffmpeg_service.py:927`](../../apps/server/services/ffmpeg_service.py#L927) and `:938`.

**Failure modes that hit this:**
- **Timeout-kill** (issue #2 root) — FFmpeg is alive, we terminate it, stderr never flushed.
- **Fast-exit failures** under `-loglevel error` — e.g. unsupported pixel format, missing decoder.  FFmpeg writes to stderr at non-error level, then exits before we drain.
- **stderr tempfile race** — on Windows, `os.close(stderr_fd)` happens in the parent right after spawn; if the child writes immediately and the file handle isn't fully transferred yet, early writes can be lost (rare but observed in logs).

**Impact:** every failure looks identical to the operator.  The notification body is a generic "FFmpeg failed: exit code N" with no diagnostic info.

**Fix:**
- Drop `-loglevel error` (use default = info for transcode sessions; we already redirect to a tempfile so log volume isn't an issue).
- Distinguish "killed-by-us" from "exited" in the diagnostic — emit "FFmpeg killed after Ns timeout (no first segment)" instead of "exit code 1".
- Add an explicit `proc.stderr` flush hook before drain (`proc.wait()` should already do this on POSIX; on Windows wait extra 200 ms before reading the tempfile).

---

### 4.2 No cleanup of `session_dir` on FFmpeg startup failure

**Where:** [`ffmpeg_service.py:920-944`](../../apps/server/services/ffmpeg_service.py#L920) — when `_spawn_ffmpeg_attempt` returns failure, the function raises `RuntimeError` without removing the partially-written `<hls_root>/<session_id>/` directory.

**Impact:** orphan dirs accumulate in `%APPDATA%\Fluxora\hls\` between failed attempts.  Cleaned up at next server startup by `_cleanup_orphaned_hls`, but during a long uptime + heavy failure rate, the dir can grow and silently consume disk.

**Fix:** wrap the failure path in `try/finally` that calls `cleanup_session_dir(session_id, hls_root)`.

---

### 4.3 The 5 s "wait for segment to appear" blocks an HTTP worker

**Where:** [`stream.py:379-382`](../../apps/server/routers/stream.py#L379).

**Impact:** during a seek-ahead the player typically requests 3–5 unfetched segments in parallel.  Each blocks a uvicorn worker for 5 s.  With 3 streaming clients seeking simultaneously, the worker pool can saturate and other endpoints (notifications, settings, info) start backing up.

**Fix (after seek-restart ships):** keep the 5 s wait only as a safety net; with seek-restart the gap-window shrinks to a sub-second.  Optionally return `503 + Retry-After: 1` on miss instead of holding the worker.

---

### 4.4 `update_progress` writes `last_progress_sec` for every stream tick

**Where:** [`stream.py:235-238`](../../apps/server/routers/stream.py#L235) — every progress PATCH writes both `stream_sessions.progress_sec` and `media_files.last_progress_sec`.

**Impact:** mobile cubit polls progress every 5 s.  That's 12 writes/min/active-stream to two tables, with WAL fsync each time.  On three concurrent streams, ~36 wal entries/minute solely for progress.  Not a bug per se, but combined with no rotation policy on `fluxora.db-wal` (currently sitting at 4 MB on the user's machine after one day), this needs a cap.

**Fix:** debounce writes — only persist `last_progress_sec` every 30 s of source time (or on `stop_stream`).  `stream_sessions.progress_sec` is fine to update every tick because it's transient.

---

### 4.5 The static VOD playlist over-promises segments

**Where:** [`ffmpeg_service.py:434-487`](../../apps/server/services/ffmpeg_service.py#L434) — `_write_static_vod_playlist` lists `ceil(duration / hls_time)` segments and assumes FFmpeg will produce exactly that many.

**Impact:** stream-copy of HEVC sources aligns segments to source keyframes.  If the source has GOPs of, say, 240 frames @ 24 fps = 10 s, and we ask for `hls_time=10`, FFmpeg may produce slightly fewer or more segments than predicted.  The tail segment can mismatch by 5-15 %.  Player hits a 404 on the over-promised final segment(s).

**Fix:** compute segment count using a tighter heuristic — for stream-copy mode, query FFmpeg's actual segment list once `seg00000` has been written and rewrite the playlist with the observed pattern.  Or accept the imprecision and have the route quietly serve `EXT-X-ENDLIST` when the actually-existing tail segment is found.

---

### 4.6 No throttling on rapid `startStream` calls per client

**Where:** [`stream.py:75`](../../apps/server/routers/stream.py#L75).  The `max_streams` check counts active stream_sessions but doesn't deduplicate by `(client_id, file_id)`.

**Impact:** a buggy client (or a malicious one) can fire `POST /stream` repeatedly for the same file, each call spawning a new FFmpeg before `stop_stream` is called on the prior session.  Saturates GPU/CPU.

**Fix:** before inserting the new session row, check for `(client_id, file_id, ended_at IS NULL)`.  If found, kill that prior session first (issue #3.3a's fix delivers this).

---

### 4.7 Tonemap chain hardcoded — no nightmare-mode tonemap (BT.2390 PQ)

**Where:** [`ffmpeg_service.py:301`](../../apps/server/services/ffmpeg_service.py#L301) — `_HDR_TO_SDR_VF` uses Hable tonemap.  Hable is a fine general-purpose curve but loses highlight detail in HDR10 sources mastered at 4000 nits or above.

**Impact:** Genshin Impact captures (HDR10 mastered around 1000 nits) look fine through Hable; movie HDR10 (often mastered at 4000 nits) loses highlights.

**Fix (low priority):** add `transcoding_tonemap_method` to `user_settings` (default Hable); offer Mobius / BT.2390 as alternatives in desktop Transcoding screen.

---

### 4.8 The HEVC fmp4 init segment generator is always invoked, even when FFmpeg wrote one

**Where:** [`ffmpeg_service.py:828-842`](../../apps/server/services/ffmpeg_service.py#L828) — `_ensure_fmp4_init_segment` runs unconditionally when `use_fmp4` is True.

**Impact:** a redundant ffprobe + ffmpeg subprocess spawn on every stream-copy HEVC stream, even when FFmpeg's HLS muxer already wrote the init segment correctly (which is most of the time on modern builds).  Adds ~200–500 ms latency to first-segment availability.

**Fix:** check `init.mp4` existence (and non-zero size) first; skip the generator when present.  The generator is already idempotent so this is purely a startup-latency optimisation.

---

### 4.9 No log rotation on `fluxora.log`

**Where:** [`main.py`](../../apps/server/main.py) `_setup_logging`.

**Impact:** the user's `fluxora.log` was at 9 MB after one day of dev usage; `fluxora.log.1` at 10 MB.  No size cap, no time-based rotation in code.  In production, this fills the data dir.

**Fix:** wrap the file handler in `RotatingFileHandler(maxBytes=10*1024*1024, backupCount=5)`.  Already noted in [`docs/10_planning/04_manual_tasks.md`](./04_manual_tasks.md) §"Cache management" but worth re-pointing here since it's the same blast radius.

---

### 4.10 `last_progress_sec ≥ 0.95 × duration` excludes the file from "Continue Watching" — but doesn't reset

**Where:** [`library_service.py:362-371`](../../apps/server/services/library_service.py#L362) — Continue-Watching query excludes near-end rows.

**Impact:** correct UX (don't suggest a file the user finished), but if the user re-watches the same file, the new session's progress writes overwrite the resume marker.  When they want to start over, there's no "reset progress" button — they have to seek back to 0 manually.

**Fix:** small UX item; add a "Start over" affordance to the file detail screen that PATCHes `last_progress_sec = 0`.

---

## 5 · Remediation Plan

### Sequencing

```
Commit 1 — HDR→SDR unblock + diagnostic upgrade   │ ~2 hours      │ low risk    │ ✅ landed 2026-05-05
Commit 2 — Seek-restart server side               │ ~4–6 hours    │ medium risk │ pending
Commit 3 — Seek-restart mobile player wire-up     │ ~3 hours      │ medium risk │ pending
Commit 4 — Zombie cleanup + dedup + log polish    │ ~2 hours      │ low risk    │ pending
─────────────────────────────────────────────────  │ ────────      │ ────────    │
Total                                              │ ~1.5 days     │
```

Each commit is independently shippable.  Commit 1 unblocks the user's immediate HDR pain; commits 2–3 are paired (they're useless individually).  Commit 4 is hygiene and depends on no others.

### Commit 1 — Tonemap unblock + diagnostic upgrade ✅ landed 2026-05-05

**Goal:** HDR→SDR toggle works end-to-end.  No more `<no stderr captured>` for the cases we cause ourselves.

**Shipped changes:**
- [`ffmpeg_service.py:_spawn_ffmpeg_attempt`](../../apps/server/services/ffmpeg_service.py) — accepts `playlist_timeout_sec` (default 10 s); `start_stream` selects 60 s when `apply_hdr_tonemap` is True, 30 s for software transcode, 10 s otherwise.  The cuvid-retry path bumps to ≥30 s since software-decode-into-NVENC is materially slower than the GPU-input first attempt.
- Same function — return tuple now includes `killed_after_timeout: bool`.  When True, the error path emits "FFmpeg killed after Ns timeout (no first segment — likely a slow tonemap or software transcode on this CPU)" instead of the misleading "exit code 1" that comes from Windows `TerminateProcess(handle, 1)`.
- [`ffmpeg_service.py:_build_ffmpeg_cmd`](../../apps/server/services/ffmpeg_service.py) — `-loglevel warning` for transcode sessions, `-loglevel error` for stream-copy.  Transcode failures (unsupported pixel format, missing decoder, hwaccel rejection) often surface only at WARNING and were being swallowed under ERROR.
- Tests in [`apps/server/tests/test_stream.py`](../../apps/server/tests/test_stream.py):
  - `test_build_ffmpeg_cmd_uses_warning_loglevel_for_transcode`
  - `test_build_ffmpeg_cmd_uses_error_loglevel_for_stream_copy`
  - `test_spawn_attempt_succeeds_when_playlist_appears`
  - `test_spawn_attempt_returns_killed_after_timeout_when_playlist_never_appears`
  - `test_spawn_attempt_returns_not_killed_when_process_exits_prematurely`
  - `test_spawn_attempt_respects_supplied_timeout`

**Acceptance (still to verify on user's box):** toggle HDR→SDR on a Genshin HDR clip; first segment appears in <90 s; mobile player starts playback.

**Caveat:** the cuvid-retry path uses `playlist=playlist` (the served path) instead of `ff_playlist` and so writes FFmpeg's growing playlist directly to the served URL on retry.  Pre-existing behaviour, not introduced by Commit 1, but flagged here so Commit 2 picks it up cleanly when adding seek-restart.

---

### Commit 2 — Seek-restart server side

**Goal:** Server can re-spin FFmpeg from an arbitrary timestamp without losing the session.

**New endpoint:** `POST /api/v1/stream/{session_id}/seek?seek_sec=<float>`

- Validates session exists, belongs to caller, not ended.
- Calls new `ffmpeg_service.restart_stream(session_id, seek_sec)`:
  1. Kill the active FFmpeg for this session (`stop_stream` minus DB stamp).
  2. Wipe `<hls_root>/<session_id>/seg*.{ts,m4s}` and `init.mp4` (keep playlist for atomic-swap step 5).
  3. Compute `start_segment_index = floor(seek_sec / hls_time)`.
  4. Re-spawn FFmpeg with: `-ss <start_segment_index * hls_time>` before `-i` (input-side seek = decoder-fast for transcode, keyframe-snap for stream-copy), `-hls_start_number <start_segment_index>`.
  5. Re-emit static VOD playlist starting from `start_segment_index`, with `#EXT-X-DISCONTINUITY-SEQUENCE: 1` and `#EXT-X-DISCONTINUITY` before the first segment so the player flushes its decode buffer.

**Why segment numbering must shift:** if the player has already loaded segments 0–6 and we restart from segment 50, the playlist transitioning from `seg00006.m4s, seg00007.m4s, ...` to `seg00000.m4s, seg00001.m4s, ...` confuses media_kit's segment cache.  Forwarding segment numbers + a discontinuity marker is the standards-compliant way.

**Stream-copy seek precision:** input-side `-ss <T>` keyframe-snaps for stream-copy.  If the user seeks to 10:35 and the nearest preceding keyframe is at 10:30, FFmpeg starts there.  Player sees segment N starting at 10:30 — close enough; nothing we can do without re-encoding which defeats the point.

**Concurrent-seek protection:** lock the session during restart so two `POST /seek` calls in flight don't double-spawn.  In-process asyncio Lock keyed by `session_id`.

**Tests:**
- `test_restart_stream_kills_prior_ffmpeg`
- `test_restart_stream_resets_segment_directory`
- `test_restart_stream_writes_playlist_with_discontinuity_marker`
- `test_seek_endpoint_authz` (must own the session)
- `test_seek_endpoint_serializes_concurrent_calls`

**Acceptance:** issuing two seeks within 200 ms results in only the second restart taking effect; segments produced match `seg<N>.m4s` where N starts at the seek index.

---

### Commit 3 — Seek-restart mobile player wire-up

**Goal:** Mobile player calls the seek endpoint when the user drags the seek bar; gracefully resumes playback at the new position.

**Changes in [`player_cubit.dart`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart):**
- Add `Future<void> seekTo(Duration position)` method.
- Debounce drag-end events (300 ms) — many small movements during scrub don't each trigger a restart.
- On commit:
  1. Pause player.
  2. POST to `/stream/{sid}/seek?seek_sec=<position.inSeconds>`.
  3. On success, call `_player.open(Media(<same playlistUrl>))` again — playlist URL is unchanged, segments are different.
  4. Resume play.
  5. On failure (network / 404 / 5xx), fall back to in-player seek (current behaviour) — still bad UX but no worse than today.
- Keep the existing in-player `seek(Duration)` for tiny seeks (<5 s) that don't warrant a restart.  Expose `_seekRestartThresholdSec` constant.

**Changes in [`flux_player_controls.dart`](../../apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart):**
- Wire seek-bar drag-end + double-tap-skip-±10 s through the cubit's new `seekTo` method (currently they go directly to `_player.seek`).
- Show a small "buffering" overlay while the restart is in flight so the user doesn't think it hung.

**Tests:**
- `seekTo calls repository.seekStream when delta > threshold` (existing player_cubit_test pattern)
- `seekTo falls back to in-player seek on threshold miss`
- `seekTo handles repository errors without crashing the cubit`

**Acceptance:** user seeks from 0:30 to 5:00 on a tonemap session; first segment appears in ≤90 s, playback resumes.

---

### Commit 4 — Zombie cleanup + dedup + log polish

**Goal:** Stop accumulating runaway FFmpeg processes; tighter resource lifecycle.

**Changes:**
- [`stream.py:start_stream`](../../apps/server/routers/stream.py) — before INSERT, query for any active session with same `(client_id, file_id)`; if found, call `stop_stream(prior_session_id)` first (kill FFmpeg + cleanup dir + stamp ended_at).
- [`main.py:_close_orphaned_sessions`](../../apps/server/main.py#L110) — extend to also kill any leftover FFmpeg subprocess that managed to outlive the parent.  Best-effort `taskkill /F /IM ffmpeg.exe /T` on Windows is too aggressive (would kill operator-launched FFmpegs); instead, track subprocess PIDs in a sidecar file and reap on startup.
- [`ffmpeg_service.py:start_stream`](../../apps/server/services/ffmpeg_service.py#L920) — failure path wraps in `try/finally cleanup_session_dir(...)` so partial dirs don't pile up.
- [`stream.py:update_progress`](../../apps/server/routers/stream.py#L202) — debounce `last_progress_sec` writes to once per 30 s.
- [`main.py`](../../apps/server/main.py) — switch the file handler to `RotatingFileHandler(maxBytes=10MB, backupCount=5)`.

**Tests:**
- `test_start_stream_kills_prior_session_for_same_client_file`
- `test_start_stream_failure_cleans_session_dir`
- `test_progress_writes_debounced_to_30s`
- `test_log_rotation_caps_at_10mb`

---

## 6 · Test Strategy

### Unit tests
Each commit lands with focused unit tests against the service layer (no real FFmpeg).  We mock `_spawn_ffmpeg_attempt` to deterministically simulate timeout/exit/success scenarios.

### Integration smoke (manual, post-each-commit)
Three scripted runs per commit on the user's machine:
1. **Stream-copy HEVC** — Avicii music video, 3-minute file.  Play → seek to 1:30 → seek to 2:50 → end.
2. **Transcode AV1** — any AV1 file with NVENC fallback.  Play → toggle quality preset mid-stream → end.
3. **HDR→SDR tonemap** — Genshin Impact HDR10 capture.  Play → toggle tonemap → seek to 1:00 → toggle off → seek to 0:30 → end.

### Regression matrix
After commit 4 lands, run the full server pytest (currently 391 tests) + `flutter analyze` × 3 packages.  Net new tests should land at +20 to +30 across the four commits.

### What we deliberately don't test
- Real FFmpeg invocations in CI — FFmpeg startup time + GPU dependencies make these flaky.  CI mocks at the subprocess boundary.
- iOS player paths — covered manually when an iOS device is available (already tracked in [`04_manual_tasks.md`](./04_manual_tasks.md)).

---

## 7 · Risks & Open Questions

| Risk | Mitigation |
|---|---|
| **Seek-restart breaks WebRTC streaming path** when it ships (Phase 3+) | WebRTC bypasses HLS entirely; the seek endpoint is HLS-only.  Document explicitly in the endpoint docstring. |
| **Discontinuity markers crash older Android media_kit** | Test against the current floor (`media_kit ^1.3`).  If broken, fall back to "delete-and-renumber from 0" segments at the cost of breaking the player's segment cache (fine for the user-initiated seek case). |
| **`-ss` precision differs across encoders** — NVENC may snap to keyframes, libx264 honors precise frame-accurate seek | Document the imprecision; not a regression because existing behaviour was "no seek at all". |
| **Killing FFmpeg mid-write leaves a corrupt segment** | The wipe step in commit 2 removes seg files; only init.mp4 might be partial.  Generator handles re-creation. |
| **Mobile cubit's debounce interacts badly with audio_service lockscreen scrub** | Scope to mobile-app only; lockscreen seeks are rare and small; don't trigger restart for them. |

**Open question — should desktop control panel get a "force kill all FFmpegs" button?**  Useful for ops but adds a destructive-button surface area.  Defer until v1 ship.

---

## 8 · Out of Scope (this plan)

- WebRTC streaming path defects — separate work, separate plan.
- Browser web player — not in v1 scope.
- Per-encoder cuvid widening tuning — covered by [`04_manual_tasks.md`](./04_manual_tasks.md) §cuvid validation per GPU generation.
- AV1 software decode (libdav1d) — separate manual task.
- Subtitle rendering — Phase 3+.
- Multiple-audio-track selection during stream — works at start_stream time but no mid-stream switch; defer.

---

## 9 · Cross-references

- Roadmap milestones: [`01_roadmap.md`](./01_roadmap.md) — this plan slots under M5.5 polish.
- Ship-readiness gating: [`05_ship_readiness.md`](./05_ship_readiness.md) — none of these are hard blockers, but #3.1 (seek) and #3.2 (HDR toggle) are visible-in-demo regressions and should ship before v1 is announced publicly.
- Manual tasks already tracking related items: [`04_manual_tasks.md`](./04_manual_tasks.md) — log rotation, cache mgmt, FFmpeg bundling.
- ADRs: none of the decisions here rise to ADR level (they're tactical fixes within an existing architecture).  When seek-restart ships, capture the design choice "kill-and-restart vs. spawn-secondary-FFmpeg" in [`02_decisions.md`](./02_decisions.md).

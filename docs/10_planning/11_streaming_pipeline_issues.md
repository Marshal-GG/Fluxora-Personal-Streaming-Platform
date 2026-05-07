# Streaming Pipeline — Issue Audit & Remediation Plan

> **Category:** Planning
> **Status:** ✅ All four commits shipped 2026-05-05; §4 leftovers (4.3 / 4.5 / 4.8 / 4.10 closed; 4.7 explicitly deferred as low priority) closed 2026-05-08.  No outstanding tactical work in this plan.
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

### 4.3 The 5 s "wait for segment to appear" blocks an HTTP worker ✅ landed 2026-05-08

**Where:** [`stream.py`](../../apps/server/routers/stream.py) — segment-serve handler.

**Impact (pre-fix):** during a seek-ahead the player typically requests 3–5 unfetched segments in parallel.  Each blocks a uvicorn worker for 5 s.  With 3 streaming clients seeking simultaneously, the worker pool can saturate and other endpoints (notifications, settings, info) start backing up.

**Shipped fix (2026-05-08):** worker-pinning budget tightened from 50 iterations × 100 ms (5 s) → 20 iterations × 100 ms (2 s).  The seek-restart pipeline (Commits 2/3) shrinks the realistic gap between a player request and the segment landing on disk to sub-second for stream-copy + ~1 s for transcode; the 2 s budget still absorbs that with margin.  Tonemap restarts (≥10 s gap) stay bridged client-side by the mobile player's `_SeekingOverlay` + media_kit's 404-retry loop, which together hammer the segment until FFmpeg catches up.  Three concurrent seekers used to chew 15 worker-seconds; now ≤6.  Response stays `404` (rather than `503 + Retry-After`) to keep media_kit's existing 404-retry path live — no client-side change needed.

---

### 4.4 `update_progress` writes `last_progress_sec` for every stream tick

**Where:** [`stream.py:235-238`](../../apps/server/routers/stream.py#L235) — every progress PATCH writes both `stream_sessions.progress_sec` and `media_files.last_progress_sec`.

**Impact:** mobile cubit polls progress every 5 s.  That's 12 writes/min/active-stream to two tables, with WAL fsync each time.  On three concurrent streams, ~36 wal entries/minute solely for progress.  Not a bug per se, but combined with no rotation policy on `fluxora.db-wal` (currently sitting at 4 MB on the user's machine after one day), this needs a cap.

**Fix:** debounce writes — only persist `last_progress_sec` every 30 s of source time (or on `stop_stream`).  `stream_sessions.progress_sec` is fine to update every tick because it's transient.

---

### 4.5 The static VOD playlist over-promises segments ✅ landed 2026-05-08

**Where:** [`ffmpeg_service.py`](../../apps/server/services/ffmpeg_service.py) — `_write_static_vod_playlist` (spawn-time over-promise) + new `_finalize_vod_playlist` + `_finalize_vod_playlist_on_exit` watcher (post-natural-exit truth).

**Impact (pre-fix):** stream-copy of HEVC sources aligns segments to source keyframes.  If the source has GOPs of, say, 240 frames @ 24 fps = 10 s, and we ask for `hls_time=10`, FFmpeg may produce slightly fewer or more segments than predicted.  The tail segment can mismatch by 5-15 %.  Player hits a 404 on the over-promised final segment(s).

**Shipped fix (2026-05-08, follow-on to the morning's §4 close-out):**

The spawn-time playlist is still pre-emitted as an upper bound (so the player's seek bar spans the full duration immediately on first load).  After FFmpeg exits naturally (`returncode == 0`), a background watcher replaces the served playlist with FFmpeg's own incremental playlist (`_ff_playlist.m3u8`) which holds the truth — accurate per-segment `#EXTINF` durations + only the segments actually written.

- **New `_finalize_vod_playlist(session_dir, *, served_playlist_name, ff_playlist_name, discontinuity_seq)`** — copies `_ff_playlist.m3u8` over `playlist.m3u8`.  Preserves seek-restart bookkeeping by re-injecting `#EXT-X-DISCONTINUITY-SEQUENCE:N` after the `#EXT-X-VERSION` line (FFmpeg won't have set it; the inline `#EXT-X-DISCONTINUITY` marker is unnecessary post-finalisation since the player already consumed the boundary at restart time).  Returns False without touching the served playlist when the FFmpeg playlist is missing or empty — better an over-promised playlist than a broken one.
- **New `_finalize_vod_playlist_on_exit(session_id, proc, session_dir, discontinuity_seq)`** — async background task that awaits `proc.wait()` then fires the finalise.  Self-cleans from a new module-level `_finalize_watchers: dict[str, asyncio.Task]` registry on completion.  No-op when the process exits non-zero (kill or crash) or when the session dir has been torn down between exit and finalise (race with `stop_stream`).
- **Hook in `start_stream` success path:** spawns the watcher right after the static VOD playlist write.  Replaces any prior watcher entry first (defensive against an in-flight cancel from `restart_stream`).
- **`_terminate_ffmpeg` cancels the watcher** before tearing down the active process — both `stop_stream` and `restart_stream` paths flow through `_terminate_ffmpeg`, so a single cancel point covers both.

11 new tests in [`test_stream.py`](../../apps/server/tests/test_stream.py): finalise replaces with truth / no-op when ff missing / no-op on empty ff / discontinuity-sequence injection / no injection when seq=0 / watcher fires on natural exit / watcher skips on kill / watcher skips when dir gone / watcher self-cleans from registry / `_terminate_ffmpeg` cancels the watcher / cancellation propagates `CancelledError`.  Server suite **641 → 652 passing.**

**In-progress playback caveat:** clients that already loaded the over-promised list before FFmpeg finished encoding (typical for active sessions) won't pick up the truthful playlist until they re-fetch — `media_kit` / `libmpv` cache VOD playlists.  For those clients the original 404 + retry-then-skip behaviour still kicks in on the over-promised tail.  The fix's main wins are: (a) future loads of the same session URL (resume flows, cross-session reuse); (b) media_kit's small-N retry budget no longer eats the player's confidence in the playlist when the over-promise is severe.

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

### 4.8 The HEVC fmp4 init segment generator is always invoked, even when FFmpeg wrote one ✅ already in place (closed 2026-05-08)

**Where:** [`ffmpeg_service.py:_ensure_fmp4_init_segment`](../../apps/server/services/ffmpeg_service.py).

**2026-05-08 audit finding:** the existence-check the original triage proposed is **already at lines 633-635** of the function:
```python
init_path = session_dir / "init.mp4"
if init_path.exists() and init_path.stat().st_size > 0:
    return True
```
The spawn-loop call at line 1015 IS unconditional on `use_fmp4`, but the function itself short-circuits when init.mp4 is present.  The triage's claim of "redundant ffprobe + ffmpeg subprocess spawn" misread the function — there's no ffprobe involved, and the ffmpeg subprocess only spawns when the init file is missing or zero-byte.

**On the bundled FFmpeg the regen still fires often** because the bundled build's HLS muxer routinely doesn't write init.mp4 under stream-copy.  That regen is necessary safety, not redundancy — without it, playback fails with 404 on init.mp4.  The 200-500 ms cost is the price of a working fmp4 stream on the bundled build.

**No code change needed.**  Remove from the leftovers list.

---

### 4.9 No log rotation on `fluxora.log`

**Where:** [`main.py`](../../apps/server/main.py) `_setup_logging`.

**Impact:** the user's `fluxora.log` was at 9 MB after one day of dev usage; `fluxora.log.1` at 10 MB.  No size cap, no time-based rotation in code.  In production, this fills the data dir.

**Fix:** wrap the file handler in `RotatingFileHandler(maxBytes=10*1024*1024, backupCount=5)`.  Already noted in [`docs/10_planning/04_manual_tasks.md`](./04_manual_tasks.md) §"Cache management" but worth re-pointing here since it's the same blast radius.

---

### 4.10 `last_progress_sec ≥ 0.95 × duration` excludes the file from "Continue Watching" — but doesn't reset ✅ landed 2026-05-08

**Where:** [`library_service.py`](../../apps/server/services/library_service.py) — Continue-Watching query excludes near-end rows.

**Impact (pre-fix):** correct UX (don't suggest a file the user finished), but if the user re-watches the same file, the new session's progress writes overwrite the resume marker.  When they want to start over, there's no "reset progress" button — they have to seek back to 0 manually.

**Shipped fix (2026-05-08):**
- New server route [`POST /api/v1/files/{file_id}/reset-progress`](../../apps/server/routers/files.py) — zeroes `last_progress_sec` + bumps `updated_at`.  Returns 204; consumes the same visibility check `get_file` uses (404 — not 403 — when caller's groups don't expose the file's library, to prevent id-enumeration of gated content).  Localhost callers skip the visibility filter.
- New `Endpoints.fileResetProgress(fileId)` constant + `LibraryRepository.resetProgress(String)` method.  Mobile impl POSTs through `ApiClient.post`.
- Mobile [`detail_screen.dart`](../../apps/mobile/lib/features/detail/presentation/screens/detail_screen.dart): `_PrimaryActions` row now renders a secondary "Start over" `FluxButton` next to "Resume" when `file.resumeSec > 0`.  Tapping opens an `AlertDialog` confirmation (titled "Start over?", quoting the file title), then calls `resetProgress` → reloads the cubit → shows a "Progress reset." SnackBar.  Failure path shows "Could not reset progress." SnackBar; cubit state stays as-is.  Message + cubit refs captured pre-await for `use_build_context_synchronously` cleanliness.
- 4 new server tests in [`tests/test_files.py`](../../apps/server/tests/test_files.py): zero-out happy path, 404 on unknown file, localhost skips visibility, 404 when library not visible (mocks `group_service.get_visible_libraries` empty + sends `CF-Connecting-IP` header to bypass the loopback dep shortcut).
- Verification: server suite **637 → 641 passing**; mobile **64 still passing**; `flutter analyze` clean × `apps/mobile` + `packages/fluxora_core`.

---

## 5 · Remediation Plan

### Sequencing

```
Commit 1 — HDR→SDR unblock + diagnostic upgrade   │ ~2 hours      │ low risk    │ ✅ landed 2026-05-05
Commit 2 — Seek-restart server side               │ ~4–6 hours    │ medium risk │ ✅ landed 2026-05-05
Commit 3 — Seek-restart mobile player wire-up     │ ~3 hours      │ medium risk │ ✅ landed 2026-05-05
Commit 4 — Zombie cleanup + dedup + log polish    │ ~2 hours      │ low risk    │ ✅ landed 2026-05-05
─────────────────────────────────────────────────  │ ────────      │ ────────    │
Total                                              │ ~1.5 days     │ all four shipped 2026-05-05
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

### Commit 2 — Seek-restart server side ✅ landed 2026-05-05

**Goal:** Server can re-spin FFmpeg from an arbitrary timestamp without losing the session.

**Shipped changes:**

- **New endpoint** [`POST /api/v1/stream/{session_id}/seek?seek_sec=<float>&tonemap=<bool>`](../../apps/server/routers/stream.py) — validates ownership (403 on someone else's session, 404 on unknown / ended session, 400 on negative `seek_sec`), looks up the session's file path, calls `restart_stream`.  Rate-limited to 30/min per IP via the existing `slowapi` Limiter so a runaway scrubber can't melt the encoder.  Returns 204; the playlist URL is unchanged but its *contents* are rewritten — clients re-open the same URL.  The `tonemap` query param preserves session state across seeks (mobile passes whatever value it received from `/start` or last toggled).

- **New `ffmpeg_service.restart_stream(file_path, session_id, hls_root, seek_sec, *, tonemap_hdr=False)`** — extracted helper [`_terminate_ffmpeg(session_id)`](../../apps/server/services/ffmpeg_service.py) (kill-only, no encoder-slot release), per-session `asyncio.Lock` from `_seek_locks`, wipes `seg*.{ts,m4s}` + `init.mp4` (keeps `_ff_playlist.m3u8`), bumps `_discontinuity_seq[session_id]` counter, then tail-calls `start_stream` with `seek_sec` + `discontinuity_seq` arguments.

- **`start_stream` extended with `seek_sec` + `discontinuity_seq` parameters.**  The seek is aligned to a segment boundary (`int(seek_sec // hls_time) * hls_time`) so FFmpeg's `-start_number` and the static VOD playlist's media-sequence stay in lockstep.  Also fixes a pre-existing inconsistency in the cuvid-retry path (was using `playlist=playlist` for FFmpeg; now uses `ff_playlist` like the first attempt).

- **`_build_ffmpeg_cmd` extended with `seek_sec` + `start_segment_index`** — emits `-ss <seek_sec>` *before* `-i` (input-side seek; decoder-fast for transcode, keyframe-snap for stream-copy) and `-start_number <K>` so segments land on disk as `seg<K>.{ts,m4s}` matching the rewritten playlist.  Both default to 0; defaults preserve initial-spawn behaviour byte-for-byte.

- **`_write_static_vod_playlist` extended with `start_segment_index` + `discontinuity_seq`** — when `start_segment_index > 0`, lists segments `<K>..N-1` only and shifts `#EXT-X-MEDIA-SEQUENCE` to `K`.  When `discontinuity_seq > 0`, emits `#EXT-X-DISCONTINUITY-SEQUENCE:<seq>` in the header and `#EXT-X-DISCONTINUITY` immediately before the first listed segment so the player flushes its decode buffer on re-load.  Defensive: `start_segment_index >= n_total` (seek past EOF) emits a valid empty VOD playlist instead of an empty file.

- **`stop_stream` cleans up `_seek_locks[session_id]` + `_discontinuity_seq[session_id]`** so they don't accumulate on a long-running server.

- **18 new tests in [`apps/server/tests/test_stream.py`](../../apps/server/tests/test_stream.py):**
  - `test_build_ffmpeg_cmd_inserts_ss_before_input_when_seek_requested`
  - `test_build_ffmpeg_cmd_omits_ss_when_seek_is_zero`
  - `test_build_ffmpeg_cmd_emits_start_number_when_index_nonzero`
  - `test_build_ffmpeg_cmd_omits_start_number_when_index_zero`
  - `test_static_vod_playlist_shifts_media_sequence_for_seek`
  - `test_static_vod_playlist_emits_discontinuity_marker_on_restart`
  - `test_static_vod_playlist_no_discontinuity_when_initial_spawn`
  - `test_static_vod_playlist_handles_seek_past_end_of_file`
  - `test_restart_stream_terminates_prior_ffmpeg`
  - `test_restart_stream_wipes_segments_and_init`
  - `test_restart_stream_bumps_discontinuity_sequence`
  - `test_restart_stream_serializes_concurrent_calls` (in-process Lock guarantees max 1 inflight per session)
  - `test_stop_stream_cleans_up_seek_lock_and_counter`
  - `test_seek_endpoint_calls_restart_stream`
  - `test_seek_endpoint_rejects_non_owner` (403)
  - `test_seek_endpoint_rejects_negative_seek` (400)
  - `test_seek_endpoint_404s_on_unknown_session`
  - `test_seek_endpoint_forwards_tonemap_flag`

**Why segment numbering must shift:** if the player has already loaded segments 0–6 and we restart from segment 50, the playlist transitioning from `seg00006.m4s, seg00007.m4s, ...` to `seg00000.m4s, seg00001.m4s, ...` confuses media_kit's segment cache.  Forwarding segment numbers + a discontinuity marker is the standards-compliant way.

**Stream-copy seek precision:** input-side `-ss <T>` keyframe-snaps for stream-copy.  If the user seeks to 10:35 and the nearest preceding keyframe is at 10:30, FFmpeg starts there.  Player sees segment N starting at 10:30 — close enough; nothing we can do without re-encoding which defeats the point.

**Caveat — Commit 3 still required:** the rewritten playlist URL is unchanged, but `media_kit` / `libmpv` cache the VOD playlist on first load (`#EXT-X-PLAYLIST-TYPE:VOD` + `#EXT-X-ENDLIST` tells them it's immutable) and won't re-fetch on their own.  The mobile cubit must explicitly re-open the `Media` object after the `/seek` POST returns 204 — that's what Commit 3 wires up.

---

### Commit 3 — Seek-restart mobile player wire-up ✅ landed 2026-05-05

**Goal:** Mobile player calls the seek endpoint when the user drags the seek bar; gracefully resumes playback at the new position.

**Shipped changes:**

- **`PlayerRepository.seekStream(sessionId, seekSec, {tonemap})`** — new method on the domain interface.  Impl in [`player_repository_impl.dart`](../../apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart) POSTs to `Endpoints.streamSeek(sessionId)` with `seek_sec` formatted to 3 decimal places + `tonemap=true` only when set.  New `Endpoints.streamSeek` constant in [`endpoints.dart`](../../packages/fluxora_core/lib/network/endpoints.dart).
- **`PlayerCubit.seekTo(Duration position)`** in [`player_cubit.dart`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart) — top-level entry that decides between in-player and server-restart based on the seek delta:
  - **Backward seeks + forward seeks under 5 s**: in-player only (`_player.seek(position)`).  Backward is always safe (segments exist on disk); small forward seeks fit in libmpv's prefetch + the server's 5 s segment-wait absorbing a brief miss.
  - **Forward seeks ≥ 5 s**: stored as `_pendingSeekTarget`, debounced through a 300 ms `Timer`.  When the timer fires, `_commitServerSeek(target)` runs the kill→POST→re-open→resume sequence.
  - The threshold constant `_kSeekRestartThresholdSec` is intentionally conservative — bumping it after field reports is cheap, but a too-large threshold leaves the user staring at a 404 retry storm if the buffer is empty.
- **`_commitServerSeek(target)`** — pauses the player, calls `repository.seekStream`, re-opens the same `Media(playlistUrl, httpHeaders)` (libmpv cached the VOD list and won't re-fetch on its own), seeks within the new playlist to the precise target, resumes.  On any failure falls back to in-player seek + play so the drag never feels totally dead.  Wraps the entire restart in `PlayerReady.copyWith(isSeeking: true)` so the UI shows a buffering overlay while the new first segment is being produced.
- **`PlayerReady.isSeeking: bool`** added to [`player_state.dart`](../../apps/mobile/lib/features/player/presentation/cubit/player_state.dart) + included in `copyWith`.
- **`_disposeCurrentSession`** cancels the seek-debounce timer and clears `_pendingSeekTarget`, `_lastPlaylistUrl`, `_lastPlaylistHeaders` so a stale seek target can't fire after a session ends.
- **`FluxPlayerControls`** in [`flux_player_controls.dart`](../../apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart) gains `onSeek: ValueChanged<Duration>?` prop.  All three seek call sites (double-tap skip ±10 s, side-rail skip buttons, scrubber `onChangeEnd`) now route through the new `_emitSeek` funnel which calls `widget.onSeek` when set, falls back to direct `player.seek` otherwise.  Scrubber's `onChanged` (live drag) keeps doing direct in-player seek so the preview tracks the drag fluidly; only `onChangeEnd` triggers the cubit (which then debounces another 300 ms before the actual restart).  `_ProgressBar` gains an `onSeekCommit` callback for the same purpose.
- **`_VideoView`** in [`player_screen.dart`](../../apps/mobile/lib/features/player/presentation/screens/player_screen.dart) gains `onSeek: (d) => context.read<PlayerCubit>().seekTo(d)` and `isSeeking: state.isSeeking`.  When `isSeeking` is true a new private `_SeekingOverlay` widget paints a translucent scrim + violet `CircularProgressIndicator` + "Seeking…" label.  Distinct from media_kit's own buffering signal because the server restart needs ≥10 s of FFmpeg startup before the new first segment lands — without the overlay the user sees a frozen frame and assumes the player crashed.
- **Tests** in [`player_cubit_test.dart`](../../apps/mobile/test/features/player/player_cubit_test.dart):
  - `seekTo no-ops when state is PlayerInitial` — must never call repository.seekStream when no session is active.
  - `seekTo no-ops when state is PlayerFailure` — same invariant for the post-failure recovery path.
  - `seekTo no-ops when state is PlayerTierLimit` — same for the 429-rejected path (covered separately because the cubit emits a different state class).
  - `seekTo clamps negative durations to zero` — defensive against caller bugs.

  Full happy-path tests of the threshold-based dispatch + debounce + server-restart flow require a real `Player` to read position and pause/open/seek/play through, which native media_kit libs make unavailable in headless unit tests.  Field validation by manual integration test (seek from 0:30 → 5:00 on a tonemap session — see acceptance below).

**Acceptance (still to verify on the user's box):** user seeks from 0:30 to 5:00 on a tonemap session; first segment appears in ≤90 s, "Seeking…" overlay shows during the wait, playback resumes from the new position.

**`flutter analyze` clean across all 3 packages.  Mobile suite 41 → 45 passing.  Desktop 84 + core 8 unchanged.**

---

### Commit 4 — Zombie cleanup + dedup + log polish ✅ landed 2026-05-05

**Goal:** Stop accumulating runaway FFmpeg processes; tighter resource lifecycle.

**Shipped changes:**

- **`(client_id, file_id)` dedup in [`stream.py:start_stream`](../../apps/server/routers/stream.py)** — runs *before* the per-client concurrency check.  When the caller already has an active session on the same file (a buggy / restarting client double-posting `/start` is the common case), the prior FFmpeg is terminated, its session dir cleaned, and its row stamped `ended_at`.  Logs at INFO so the operator can see the dedup firing.  Cross-client sessions on the same file are NOT affected (two paired devices in the same household can both stream the same movie).  The dedup intentionally bypasses the concurrency cap for this case so a re-start doesn't get rejected for "exceeding" a slot the caller already owns.
- **Failure-path session-dir cleanup in [`ffmpeg_service.py:start_stream`](../../apps/server/services/ffmpeg_service.py)** — the `if not succeeded` block now `cleanup_session_dir(session_id, hls_root)` before raising the diagnostic.  Wrapped in its own try/except so a cleanup failure can't mask the original error.  The orphan-on-startup hook still catches stragglers across restarts; this is the steady-state housekeeping for long-running servers.
- **Progress-write debounce in [`stream.py:update_progress`](../../apps/server/routers/stream.py)** — new module-level `_last_persisted_progress: dict[str, float]` and `_PROGRESS_DEBOUNCE_SEC = 30.0`.  `stream_sessions.progress_sec` is updated every tick (transient live value; drives the active-sessions UI on desktop); `media_files.last_progress_sec` updates only when |delta| ≥ 30 s of source-time.  `stop_stream` flushes the live `stream_sessions.progress_sec` to `media_files.last_progress_sec` on a clean close so resume position stays exact when the user closes properly — and pops the in-memory dict entry so long-running servers don't accumulate one float per ended session.  Worst-case staleness on a non-clean close (app killed mid-watch without `stopStream`) is the debounce interval; before this change, three concurrent streams produced ~36 WAL writes/min just on progress polling.
- **Log rotation already in place** — `_LOG_CONFIG_COMMON["handlers"]["file"]` was already configured as `RotatingFileHandler(maxBytes=10MB, backupCount=5)`.  The original triage's "no rotation in code" assertion was inaccurate; the user's `fluxora.log` at 9 MB + `fluxora.log.1` at 10 MB was rotation working, not absent.  Total disk cap is 60 MB (current + 5 backups × 10 MB) — fine for v1.  Pinned with a regression test so a future "let's just use FileHandler" refactor breaks immediately.
- **Out of scope (deferred):** the "kill leftover FFmpeg subprocesses across server-process restarts" piece — would require a sidecar PID file written by the spawn path and reaped on startup, and `taskkill /F /IM ffmpeg.exe /T` on Windows is too aggressive (would kill operator-launched FFmpegs unrelated to Fluxora).  The OS reaps orphaned children on parent exit in practice; logging an issue if real cases ever surface is cheaper than the file-tracking layer.

**Tests in [`apps/server/tests/test_stream.py`](../../apps/server/tests/test_stream.py) (+6 cases, 58 → 64 in this file):**

- `test_start_stream_kills_prior_session_for_same_client_and_file`
- `test_start_stream_does_not_kill_other_clients_sessions`
- `test_ffmpeg_start_stream_cleans_session_dir_on_failure`
- `test_update_progress_debounces_media_files_writes`
- `test_stop_stream_flushes_final_progress_to_media_files`
- `test_log_config_uses_rotating_file_handler_with_10mb_cap`

Plus a fix to the pre-existing [`test_settings.py::test_free_tier_blocks_second_stream`](../../apps/server/tests/test_settings.py) — it was using the same `(client, file)` for the active session and the about-to-be-rejected start, which the new dedup correctly intercepts before the concurrency check.  Updated to use distinct file_ids so it actually exercises the cap.

**Server suite 415 → 421 passing.**

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

---

## 10 · Close-out (2026-05-08)

The §4 leftovers from the 2026-05-05 commit batch were closed out on 2026-05-08:

| Issue | Status | Notes |
|---|---|---|
| §4.3 5 s segment-wait | ✅ shortened to 2 s | Worker-pinning down 60 %; client retry path unchanged. |
| §4.5 VOD over-promise tail | ✅ shipped | Originally deferred earlier on 2026-05-08; picked back up the same day after the §4 close-out.  Spawn-time playlist still pre-emitted as upper bound; new `_finalize_vod_playlist` + `_finalize_vod_playlist_on_exit` watcher replaces it with FFmpeg's accurate playlist on natural exit (`returncode == 0`).  Watcher tracked in `_finalize_watchers` registry; `_terminate_ffmpeg` cancels it on stop / restart paths.  +11 tests; server suite 641 → 652 passing. |
| §4.7 alternative tonemap methods | ⏸ low priority — left as-is | Hable is fine for the user's ≤ 1000-nit HDR content; revisit when 4000-nit-mastered movie sources surface as a complaint. |
| §4.8 redundant `_ensure_fmp4_init_segment` | ✅ no-op (existence check already in place) | Triage misread; the function short-circuits when init.mp4 is present.  The unconditional call is necessary on the bundled FFmpeg. |
| §4.10 "Start over" affordance | ✅ shipped | New `POST /files/{id}/reset-progress` server route + Endpoints + LibraryRepository method + detail-screen secondary button + 4 tests.  Server 637 → 641 passing. |

After this close-out, the streaming pipeline plan has **no outstanding tactical work**.  The remaining items are out-of-scope (WebRTC, browser web player, AV1-libdav1d swap) and live in [`04_manual_tasks.md`](./04_manual_tasks.md) or future plans.

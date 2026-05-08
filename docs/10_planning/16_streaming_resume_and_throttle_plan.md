# Streaming Pipeline — Resume + Throttle Remediation Plan

> **Category:** Planning
> **Status:** Drafted 2026-05-08; **M1 + M3 + M4 ✅ landed 2026-05-08**; **M2 reverted same day** after two real-device 503 regressions; **M2 retried + landed via successor plan [`17_ffmpeg_diagnostics_and_m2_retry_plan.md`](./17_ffmpeg_diagnostics_and_m2_retry_plan.md) the same evening** — investigation showed system FFmpeg is 8.0 (no upgrade needed); the original M2 retries failed because `-loglevel error` was suppressing FFmpeg's actual complaints (`<no stderr captured>` was a diagnostic blind-spot, not a version issue).  Sliding-window encoder still v1.1 (plan §6).  **Two follow-on patches shipped 2026-05-08 evening from real-device feedback:** (1) HDR-with-tonemap audio-drop fix — force audio re-encode when tonemap is active so copied AAC packets don't mux-drift against transcoded video; (2) scrubber-offset patch — server returns `applied_seek_sec` from /start + /seek; mobile cubit stores `playlistOffsetSec`; FluxPlayerControls renders source-time = `playerPosition + offset` so forward-seek doesn't visually reset to 0:00.  **Plus the §17 same-day post-retry follow-ons** (transcode-only `-readrate` gate after stream-copy 404 storm; `_ProgressBar` Stateful drag-preview to fix scrubber rubber-band).
> **Scope:** Three real-world streaming defects reported by the operator after M11/M12 mobile work landed:
>   - Seeker stuck at 0:00 on a resume-from-progress play (player buffers from t=0 even when `last_progress_sec > 0`).
>   - Video takes a long time to start; sometimes audio is noticeably delayed; scrubber position drifts from on-screen frame.
>   - The home server's CPU/GPU pegs for the duration of a long stream because FFmpeg encodes the entire file at full speed regardless of how much the player has actually consumed.
> **Triggered by:** operator report 2026-05-08 — *"when i play video on mobile, the seeker goes to starting position, video loads for long, sometimes audio is very delayed too, and seeker dont align with video, fix delay, audio, seeker posi, only render video that a mobile can consume like for ex. 15 sec ahead only, then that way pc dont have to load so much, at once"*.
> **Predecessor:** [`11_streaming_pipeline_issues.md`](./11_streaming_pipeline_issues.md) — the seek-restart architecture this plan builds on (`POST /seek` + `restart_stream` + segment-boundary alignment + discontinuity-sequence injection) all shipped 2026-05-05 and stays as-is. This plan extends the same machinery to the **initial-spawn** path, which was overlooked.

---

## 1 · Executive Summary

The seek-restart pipeline shipped in May 2026-05-05 (commits 2 + 3 of `11_streaming_pipeline_issues.md`) is correct for **operator-driven seeks during playback** — `POST /seek` lands FFmpeg at the right segment via `-ss <T>` + segment-numbering shift. But the **initial spawn** path was never updated to use the same mechanism. Result: when a paired client opens a half-watched file, the server starts FFmpeg from `t=0` and tells the client *"your resume position is N seconds, please seek there"*. The client opens the playlist, calls `player.seek(N)`, and stalls — the static VOD playlist over-promises the segment exists, but FFmpeg is encoding from `t=0` and won't reach `seg(N/hls_time).m4s` for many minutes (or never, on a 1× transcode).

Compounding: FFmpeg currently encodes flat-out. On stream-copy that's ~10× realtime, on transcode 0.5–2×. Either way, the home server burns through the whole file as fast as it can produce segments, even though the player consumes them at exactly 1× realtime. CPU/GPU/disk get hammered for ~10–30 wall-minutes per 2-hour stream. The operator's *"only render 15 seconds ahead"* instinct is the right shape — FFmpeg has a built-in flag for it (`-readrate`) and the simplest path to honor that intent is one new argument plus tests.

**Headline failures (in operator-impact order):**

1. **Resume from progress is broken on the initial-spawn path.** Server passes nothing for `seek_sec`; FFmpeg starts at `t=0`. Player UI shows scrubber at `0:00` until FFmpeg slowly catches up, OR forever on a 1× tonemap.
2. **HDR↔SDR toggle restarts from `t=0` even mid-playback.** Operator-confirmed 2026-05-08. Same root cause as #1 with one twist: the cubit captures the live position correctly but never sends it to the server, so the server falls back to FFmpeg-from-zero and the client-side `player.seek` runs into the same 404-storm trap.
3. **Server CPU/GPU pegs whether or not the player needs the data right now.** No throttling; FFmpeg races to the end of the file.
4. **Long initial buffer.** media_kit's default startup-buffer is 3–5 segments before play; with `hls_time=6` for transcode, that's 18–30 s of source material gated behind FFmpeg's first-segment latency.
5. **Audio delay / AV desync** — likely a different issue (codec or container packaging); needs real-device diagnostic before changing FFmpeg's audio handling. Symptom-first instrumentation, not blind tweaks.

**Sequenced remediation:** four shippable milestones; **M1 alone fixes 4 of the 5 reported symptoms** (resume + HDR-toggle + scrubber-misalignment + most of "video loads for long"). ~1 day end-to-end. Detail in [§4](#4--sequenced-remediation-plan).

---

## 2 · Current Architecture (one-page)

### 2.1 Initial-spawn flow (today, broken on resume)

```
Mobile player                       Server                                  FFmpeg subprocess
──────────────                      ──────                                  ──────────────────
POST /api/v1/stream/start/{id}  ──▶ start_stream router
                                      ├── auth + tier-limit check
                                      ├── ffmpeg_service.start_stream(
                                      │     file_path, session_id,
                                      │     hls_root, tonemap_hdr=…)
                                      │     ⚠ never passes seek_sec
                                      └── INSERT stream_sessions  ────────▶ ffmpeg -hide_banner \
                                                                              -i <file> \
                                                                              -c:v copy/<encoder> \
                                                                              -hls_time 6/10 \
                                                                              -hls_list_size 0 \
                                                                              -hls_segment_type … \
                                                                              <session_dir>/seg00000…N.m4s
                                                                                  ↓ encodes from t=0
                                                                                  at max throughput
◀── { playlist_url, resume_sec=N, … }   ⚠ tells client to seek N forward
open(playlist_url)              ──▶ GET /hls/{sid}/playlist.m3u8           (over-promised VOD list of all segments)
seek(N seconds)                                                            (player asks for segment ⌊N / hls_time⌋)
GET seg00284.m4s                ──▶ wait-2s-then-404 loop fires            (segment doesn't exist; FFmpeg at seg7)
                                    media_kit retries, gives up
                                    player stalls at 0:00 on the scrubber
                                    user sees "loading…" forever
```

### 2.2 Seek-restart flow (works since 2026-05-05)

```
operator-initiated seek mid-playback ──▶ POST /api/v1/stream/{sid}/seek?seek_sec=T  ──▶ restart_stream(file, sid, hls_root, T)
                                                                                          ├── _terminate_ffmpeg(sid)
                                                                                          ├── wipe seg*.m4s
                                                                                          ├── bump _discontinuity_seq
                                                                                          └── start_stream(seek_sec=T, …)  ✓ correct
```

The asymmetry between (2.1) and (2.2) is the bug. **Same machinery, just not invoked at start time.**

### 2.3 Key files

| Concern | Path |
|---|---|
| Stream router (REST surface) | [`apps/server/routers/stream.py`](../../apps/server/routers/stream.py) |
| FFmpeg command builder + spawn loop | [`apps/server/services/ffmpeg_service.py`](../../apps/server/services/ffmpeg_service.py) |
| Mobile PlayerCubit (resume-seek path) | [`apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart) |
| Server-side stream tests | [`apps/server/tests/test_stream.py`](../../apps/server/tests/test_stream.py) |
| Mobile cubit tests | [`apps/mobile/test/features/player/player_cubit_test.dart`](../../apps/mobile/test/features/player/player_cubit_test.dart) |

---

## 3 · Issues — Per-symptom Root-cause Audit

### 3.1 Seeker stuck at 0:00 on resume-from-progress · long startup latency · scrubber off-by-N

**Symptom (verbatim):** *"the seeker goes to starting position, video loads for long, ... and seeker dont align with video"*

**Root cause:** [`stream.py:172-177`](../../apps/server/routers/stream.py#L172) calls `ffmpeg_service.start_stream(file_path, session_id, hls_root, tonemap_hdr=tonemap)` and **does not pass `seek_sec`**, even though the same function returns `resume_sec=file_row.get('last_progress_sec') or 0.0` to the client at [line 250](../../apps/server/routers/stream.py#L250). The client then performs a client-side `player.seek(resume_sec)` at [`player_cubit.dart:154-157`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart#L154):

```dart
final seekSec = response.resumeSec > 0 ? response.resumeSec : resumeSec;
if (seekSec > 0) {
  await _player!.seek(Duration(milliseconds: (seekSec * 1000).toInt()));
}
```

This means the player asks for segment `⌊resume_sec / hls_time⌋`, which the static VOD playlist promises exists (it lists every segment FFmpeg will eventually write), but FFmpeg is encoding from `t=0` so the segment file doesn't exist on disk for a long time. The 2 s wait-loop in `stream.py` fires, returns 404, media_kit retries a small number of times, then gives up. The player UI is stuck at 0:00 because that's the only segment range that actually has bytes.

**Why the seeker doesn't align with the picture:** when FFmpeg eventually does catch up (or media_kit gives up + restarts from segment 0), the cubit's pending `player.seek(resume_sec)` may have already lapsed or partially landed, so on-screen frame is from segment 0 while the scrubber's pending target was segment N. State desync.

**Fix:** apply the resume seek **server-side at start_stream**. Mirror what `restart_stream` already does — pass `seek_sec=last_progress_sec` to the existing function, drop the client-side `player.seek` since FFmpeg now lands at the right segment directly. The static VOD playlist's `start_segment_index` machinery already shifts media-sequence numbering correctly when `seek_sec > 0`.

### 3.2 Server CPU / GPU pegging during a stream

**Symptom (verbatim):** *"only render video that a mobile can consume like for ex. 15 sec ahead only, then that way pc dont have to load so much, at once"*

**Root cause:** `_build_ffmpeg_cmd` does not pass `-readrate` or `-re`. FFmpeg defaults to reading the input as fast as the demuxer + decoder + encoder pipeline can manage:

| Pipeline | Encode rate | 2 h movie wall-time |
|---|---|---|
| Stream-copy h264/hevc | 5–10× realtime | 12–24 min |
| NVENC transcode | 3–6× realtime | 20–40 min |
| Software transcode | 0.5–2× realtime | 60–240 min |
| HDR→SDR tonemap (CPU) | 0.4–0.8× realtime | 150–300 min |

For everything except CPU tonemap, FFmpeg races ahead of the player and produces gigabytes of segments the player won't read for 30+ minutes. The home server's GPU/CPU/fan/disk all run at peak during that window. After playback ends, the segments are deleted (the work was wasted).

**Why this matters in practice:** the operator's home server is a single shared machine. Streaming a 4K HEVC clip while the operator is on a Zoom call shouldn't make the fan audible. Today it does.

**Fix:** add `-readrate <multiplier>` to throttle FFmpeg's input-reader to a small multiple of source rate. FFmpeg upstream supports this via the `-readrate <N>` flag for native-rate reads. **`-readrate 1.5`** is the sweet spot: player sees ~30 s buffer ahead at all times, FFmpeg's CPU usage drops to ~5–8% of one core for stream-copy, GPU encoder utilisation drops similarly. The server stops being a heater.

**What about a real sliding-window encoder?** It's better in narrow cases (user pauses for an hour → FFmpeg actually pauses) but adds ~300–500 LoC of state-machine work. Deferred to [§6](#6--future-work-deferred-to-v11) — the data we'd need to justify it (peak disk per session, idle-while-paused minutes per session) isn't in the DB yet.

### 3.3 Long initial buffer

**Symptom:** first frame appears 10–30 s after tap-to-play.

**Root cause:** media_kit / libmpv's default startup-buffer is 3–5 segments queued before play begins. With `hls_time = 6` (transcode) or `hls_time = 10` (stream-copy), that's 18–30 s of source material that has to be on disk before playback starts. On a 1× tonemap session, the 30 s of source material takes ~50 s of wall time to encode, so the operator stares at a "Loading…" spinner for nearly a minute.

**Fix:** lower media_kit's startup-buffer — libmpv supports `--cache-secs` / `--demuxer-readahead-secs`. media_kit exposes these via `Player(configuration: PlayerConfiguration(...))`. Settle on a value that survives short network hiccups (~6–10 s readahead) without requiring a big initial buffer.

### 3.4 HDR↔SDR toggle restarts from t=0 (operator-confirmed 2026-05-08)

**Symptom (verbatim):** *"yes when i toggle sdr to hdr or reverse stream start from start"*

**Root cause:** Same shape as §3.1, with one twist. [`PlayerCubit.setTonemap`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart#L277) **does** capture the live playhead correctly (`_player?.state.position.inMilliseconds`) and **does** call `startStream(fileId, fileName, livePos, tonemap: enabled)`. But [`PlayerCubit.startStream`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart#L122) only forwards `tonemap` to `_repository.startStream(fileId, tonemap: tonemap)` — **it never sends the `resumeSec` argument across the wire**. The server then starts FFmpeg from `t=0`, returns the stale DB-stored `last_progress_sec` (which lags by up to 5 s due to the progress-write debounce), and the client-side `player.seek(...)` runs into the same "segment doesn't exist yet on disk" trap as §3.1.

The twist: for setTonemap the live player position is **more accurate** than the DB value (live = current frame; DB = last progress-tick). Even after M1 lands (server reads DB on initial spawn), setTonemap needs the cubit to override the server's DB reading with the live position. Otherwise toggling at 47:23 might land FFmpeg at 47:18 — close enough for resume, but not what the user expects mid-toggle.

**Fix:** add an optional `?seek_sec=<float>` query param on `POST /api/v1/stream/start/{file_id}`. When present, the server uses it instead of `last_progress_sec`. When absent, behaviour matches M1 (read DB). The cubit's `_repository.startStream` gains an optional `seekSec` argument, defaulted by `setTonemap` to the live player position. Initial-spawn paths pass nothing → server falls back to DB → resume works.

### 3.5 Audio delay / AV desync

**Symptom (verbatim):** *"sometimes audio is very delayed too, and seeker dont align with video"*

**Root cause:** **unknown without a real-device repro**. The seeker-misalignment portion is a confirmed downstream effect of §3.1. The audio-delay portion is most likely one of:

1. Source audio sample rate ≠ 48 kHz; FFmpeg's AAC encode at default rate introduces drift.
2. Stream-copy of HEVC + AAC re-encode mismatch — `_build_ffmpeg_cmd` always passes `-c:a aac -b:a 128k` even on stream-copy paths, forcing audio re-encode while video is copied. Timestamp drift can creep in during re-encode.
3. media_kit / libmpv's known ~200–500 ms audio offset on Android with HLS fmp4 (upstream issue, not Fluxora-specific).

**Fix:** **diagnose first, patch second**. Instrument `start_stream` to log source audio params (codec/rate/channels/bitrate) and mobile `PlayerCubit` to log `player.state.audioParams` post-load. With one offending clip's logs in hand, the right fix is one of (a) `-ar 48000` resample, (b) `-c:a copy` for AAC sources to skip re-encode, (c) `-muxdelay 0`, or (d) document it as upstream and move on.

---

## 4 · Sequenced Remediation Plan

```
M1 — Server-side resume seek                      │ ~1 hour       │ low risk    │ ✅ landed 2026-05-08
M2 — `-readrate 1.5` throttle                     │ ~30 min       │ —           │ ⛔ REVERTED 2026-05-08 → v1.1
M3 — Reduce mobile startup buffer                 │ ~30 min       │ low risk    │ ✅ landed 2026-05-08
M4 — Audio diagnostics (instrumentation)          │ ~1 hour       │ low risk    │ ✅ landed 2026-05-08
M4 — Audio fix (smart codec branch)               │ ~30 min       │ low risk    │ ✅ landed 2026-05-08 (proactive fix)
─────────────────────────────────────────────────  │ ────────      │ ────────    │
Total                                              │ ~3 hours      │ M1+M3+M4 done; M2 → v1.1 │
```

### M1 — Server-side resume seek (covers the HDR-toggle bug too) ✅ **landed 2026-05-08**

**Goal:** make both the initial-spawn path AND the setTonemap re-spawn path land FFmpeg at the right segment, using the same `seek_sec` plumbing the seek-restart path already uses.

**Server changes:**
- [`apps/server/routers/stream.py`](../../apps/server/routers/stream.py) `POST /stream/start/{file_id}` — accept optional `?seek_sec=<float>` query param.
  - When **present**, validate `0 <= seek_sec <= duration_sec`; pass it to `ffmpeg_service.start_stream(seek_sec=...)`. Caller authority — used by setTonemap to specify the live playhead.
  - When **absent**, fall back to `seek_sec=file_row.get("last_progress_sec") or 0.0`. This is the resume-from-progress case (initial play of a half-watched file).
- The function signature already accepts `seek_sec` (default 0.0); `_build_ffmpeg_cmd` already inserts `-ss <T>` before `-i`; `_write_static_vod_playlist` already shifts `start_segment_index = int(seek_sec // hls_time)` and emits `#EXT-X-MEDIA-SEQUENCE` correctly. **No new architecture — just call the existing machinery on the initial path.**
- Update the response: `resume_sec` returned to the client should reflect what FFmpeg actually applied (the segment-aligned value), not the raw DB column. Prevents the cubit from doing a redundant client-side seek to a slightly different timestamp.

**Mobile changes:**
- [`apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart`](../../apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart) — `startStream(fileId, {tonemap, seekSec})` gains an optional `seekSec` parameter. When non-null + > 0, append `?seek_sec=<value>` to the request URL.
- [`apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart::setTonemap`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart#L277) — when calling `startStream`, pass the **live player position** (`_player?.state.position.inMilliseconds / 1000.0`) as the `seekSec` argument. Falls through to `_repository.startStream(fileId, tonemap: enabled, seekSec: livePos)`.
- [`PlayerCubit.startStream`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart#L122) — gains an optional internal `serverSeekSec` argument (named-parameter); when present, forwards to the repo. Initial-spawn callers don't pass it (server reads DB).
- [`PlayerCubit.startStream:154-157`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart#L154) — drop the post-open `player.seek(seekSec)` call. The server now lands at the right segment directly; client-side seek is at best a no-op, at worst racing with the initial buffer fill.
- Keep `PlayerReady.resumeSec` for the UI's "resumed at 47:23" badge — informational only.

**Tests:**
- New `test_start_stream_uses_query_seek_sec_when_provided` (server: assert `ffmpeg_service.start_stream` called with the query value, not the DB value).
- New `test_start_stream_falls_back_to_db_progress_when_no_query` (server: half-watched file, no query param → uses `last_progress_sec`).
- New `test_start_stream_passes_zero_when_file_is_fresh_and_no_query` (server: never-watched file → `seek_sec=0`).
- New `test_start_stream_rejects_negative_seek_sec` (server: 400 on negative).
- New `test_start_stream_rejects_seek_sec_beyond_duration` (server: 400 on seek past EOF).
- New mobile `PlayerCubit` test `test_setTonemap_passes_live_position_to_server` (mock the repo; assert `seekSec` matches `_player.state.position`).
- New mobile `PlayerCubit` test `test_startStream_does_not_call_player_seek_after_open` (the fix — was the source of the §3.1 bug).
- New mobile `PlayerCubit` test `test_setTonemap_re_seeks_to_live_position_then_resumes_playback` (end-to-end happy path; covers the §3.4 / Q4 scenario).

**Acceptance:**
- Open a half-watched file on mobile → player starts at the resume position with no "stuck at 0:00" intermediate state. Wall-time-to-first-frame matches starting fresh.
- Toggle HDR→SDR mid-playback at 47:23 → after the brief tonemap-restart wait, playback resumes from ~47:23 (segment-snap precision; ±`hls_time`), not from 0:00.

### M2 — `-readrate 1.5` throttle ⛔ **REVERTED 2026-05-08 — carried forward to v1.1**

**Two attempts shipped + both regressed:**

1. **Attempt 1 (raw `-readrate 1.5`)** — operator hit `503 — FFmpeg killed after 10s timeout (no first segment)` on first real-device test. Initial diagnosis blamed FFmpeg startup + first-segment timing math (cold-start §5.1 was too optimistic).
2. **Attempt 2 (`-readrate 1.5 -readrate_initial_burst 30`)** — added the burst window to give FFmpeg breathing room for the first segment. Operator hit the **same 503** on retry, with `<no stderr captured>` — strongly suggesting the bundled FFmpeg silently rejects or hangs on `-readrate_initial_burst` (FFmpeg 5.1+ feature; bundled build's actual version unknown).

**Why we stopped retrying and reverted:**

- The empty stderr (`<no stderr captured>`) means we can't diagnose without an FFmpeg-version probe + a loglevel bump. Both are themselves new code.
- Operator's primary symptom is "video won't play at all" — the M2 CPU/heat optimisation is a nice-to-have; primary playback is regressing.
- M1 (resume seek), M3 (mobile buffer), and M4 (audio fix) are independent of M2 and continue to ship — they don't need the throttle to work.

**Reverted state:** `_build_ffmpeg_cmd` no longer emits `-readrate` or `-readrate_initial_burst`. Two regression-guard tests (`test_build_ffmpeg_cmd_omits_readrate_in_v1` + `_omits_readrate_for_transcode_too`) pin the disabled state so future re-introduction must be intentional.

**Pre-conditions for re-enabling in v1.1:**

1. **FFmpeg-version probe at server startup.** `ffmpeg -version` → parse → log + persist. Refuse `-readrate*` flags on builds < 5.1.
2. **Stream-copy diagnostics: switch to `-loglevel info` (or add explicit `-stats` flushing).** The "FFmpeg killed after 10s timeout: <no stderr captured>" failure mode is currently undiagnosable; bumping the loglevel for at least the failure path so init-time errors reach our captured stderr.
3. **Bump `_spawn_ffmpeg_attempt` timeout when `-readrate` is on.** Even with a working burst, the wall-time floor for the first segment is `(hls_time / readrate) + FFmpeg startup overhead` — ~8–12 s for typical hls_time + readrate. The 10 s default is too tight.
4. **Real-device verification.** Once 1–3 are in, ship `-readrate 1.5` (without burst, since burst seemed to be the problem) and confirm a real stream plays. If still failing, drop the throttle entirely and revisit only if telemetry shows real heat/fan complaints.

**Lesson logged:** when a "1-line FFmpeg flag" fix regresses on real device with empty stderr, STOP. Don't add a second flag to fix the first. Fix the diagnostic path first (loglevel + version probe), THEN re-attempt with information. Both attempts at M2 cost ~1 hour each on the optimistic path; the diagnostic-first path would have cost ~1 hour total. Carried forward as a process note for future "single-flag" optimisations.

**Goal:** stop FFmpeg from racing to the end of the file. Cap encode pace at 1.5× source rate.

**Server changes:**
- [`apps/server/services/ffmpeg_service.py::_build_ffmpeg_cmd`](../../apps/server/services/ffmpeg_service.py) — emit `-readrate 1.5` immediately after `-hide_banner -loglevel <…>` and before `-i`. (Place before pre-input HW-accel flags is fine; FFmpeg parses input-side flags positionally relative to `-i`.)
- Skip `-readrate` when `apply_hdr_tonemap` is True — tonemap is already CPU-bound at <1× realtime, throttling further would cause buffer starvation.
- Skip `-readrate` when `seek_sec > 0` for the **first** segment cycle after a restart — the player's buffer is empty post-restart and benefits from a brief burst-fill. This is a v1.1 refinement; ship plain `-readrate 1.5` for everything else.
- Make the multiplier configurable via a new `transcoding_readrate_multiplier` `user_settings` column (default 1.5; min 1.0; max 4.0). Keeps the door open for operators on slow boxes who want 1.0 strict throttling.

**Tests:**
- `test_build_ffmpeg_cmd_includes_readrate_for_stream_copy` (assert `-readrate 1.5` present).
- `test_build_ffmpeg_cmd_includes_readrate_for_transcode_without_tonemap` (assert present).
- `test_build_ffmpeg_cmd_omits_readrate_when_tonemap_active` (assert absent — tonemap is already throttled below 1×).
- `test_build_ffmpeg_cmd_uses_settings_multiplier` (assert custom 2.0 from `user_settings`).

**Acceptance:** start a 10-min stream-copy session of a 1080p HEVC clip; observe `nvidia-smi` / `Activity Monitor` / fan noise. CPU/GPU usage should bound at single-digit percentages instead of pegging.

### M3 — Reduce mobile startup buffer ✅ **landed 2026-05-08**

**Goal:** first-frame latency of <5 s on stream-copy, <12 s on transcode.

**Mobile changes:**
- [`apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`](../../apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart) — at `Player()` construction, pass:
  ```dart
  Player(
    configuration: const PlayerConfiguration(
      bufferSize: 4 * 1024 * 1024,   // 4 MiB cap (default is ~32 MiB)
    ),
  )
  ```
- For finer libmpv control if needed (after instrumenting actual times), pass MPV CLI flags via the `MPVConfiguration` extension or set them after construction.
- Document the trade-off inline: smaller buffer = faster start, but a >2 s network stall mid-playback will rebuffer instead of riding through.

**Tests:** behavioural — instrument time-to-first-frame in a real-device smoke test; no automated test (media_kit doesn't run in headless test environment).

**Acceptance:** stopwatch from "tap play" to "first frame visible" on a 720p stream-copy → ≤5 s on LAN. On 4K HDR→SDR tonemap → unchanged from today (CPU-bound encoder is the floor; can't be optimised further client-side).

### Follow-on patches — real-device feedback 2026-05-08 evening

After the M1+M3+M4 round shipped, operator's real-device test surfaced two distinct symptoms not anticipated in the original plan:

#### A · HDR-with-tonemap shows NO AUDIO

**Cause:** the M4 audio-branch picked `-c:a copy` for AAC@48k sources — correct optimisation in stream-copy mode, but **wrong** when tonemap is active. Tonemap forces full video re-encode + a heavy `_HDR_TO_SDR_VF` filter chain; the regenerated video PTS doesn't align with the source's audio packet timestamps, and the HLS muxer drops the audio rather than emit a misaligned segment.

**Fix:** when `apply_hdr_tonemap=True`, force audio re-encode (`-c:a aac -b:a 128k`) even on AAC@48k. Resample is omitted since source is already 48 kHz; only the PTS-regeneration is needed. CPU cost is negligible vs the tonemap chain itself. New regression test `test_build_ffmpeg_cmd_re_encodes_audio_when_tonemap_active_aac_48khz` pins the fix.

#### B · Forward seek → scrubber resets to 0:00 (works correctly underneath)

**Cause:** the seek-restart pipeline rewrites the static VOD playlist with `start_segment_index=K` + `#EXT-X-MEDIA-SEQUENCE:K`, listing only segments K..N. libmpv treats the playlist's t=0 as the start of the first listed segment — so playback IS correct (frames are from source-time `K * hls_time`), but the player's REPORTED position is in playlist-local time (0..(N-K)*hls_time). The mobile cubit was calling `p.seek(target)` post-restart with target = source-time, which is invalid in playlist-local coordinates — libmpv either clamped or reset, manifesting as "scrubber jumps to 0".

**Fix (server side):**
- `start_stream` / `restart_stream` write the segment-snapped value to a new `_applied_seek_sec[session_id]` module dict after computing `aligned_seek_sec`.
- `POST /api/v1/stream/start/{file_id}` response gains `applied_seek_sec` field.
- `POST /api/v1/stream/{session_id}/seek` changes from 204 No Content → 200 with body `{ applied_seek_sec: <float> }`.
- `_applied_seek_sec.pop(session_id, None)` added to `stop_stream` cleanup alongside the other per-session dicts.

**Fix (mobile side):**
- `StreamStartResponse` gains `appliedSeekSec` field (defaults to 0.0 for back-compat).
- `PlayerRepository.seekStream` returns `Future<double>` — the segment-snapped value.
- `PlayerReady` state gains `playlistOffsetSec` field; cubit emits it from `response.appliedSeekSec` on initial start AND updates it on every server seek-restart.
- `_commitServerSeek` now seeks within the new playlist to `(target - appliedSeekSec)` instead of `target` — sub-segment precision fix.
- `seekTo` re-baselines its delta math: `current_source = playerPosition + offset`, `target_source = position`, `delta = target - current`. In-player seek path converts back to player-time via `target - offset` before calling `p.seek`.
- `FluxPlayerControls._ProgressBar` accepts `playlistOffsetSec`; displays `_format(playerPos + offset)` for current, `_format(playerDur + offset)` for total. Slider's `onChanged` (live drag preview) and `onChangeEnd` (commit) both convert source-time fractions back to player-time before calling `player.seek`.
- Threaded through `_VideoView` constructor and the BlocBuilder in `player_screen.dart` reads `state.playlistOffsetSec`.

Server suite: 681 passing (+5 from the renamed M4 audio re-encode test + the changed /seek tests). Mobile suite: 78 still passing.

### M4 — Audio diagnostics + targeted fix ✅ **fully landed 2026-05-08**

**What shipped:**

1. **Instrumentation (already documented above) — `audio_probe` + `audio_negotiated` log lines** so any future audio-delay report has a paper trail.

2. **Proactive fix — smart audio branch in `_build_ffmpeg_cmd`** based on the source's audio params (probed at session start by `_probe_audio_params`):
   - **AAC at 48 kHz → `-c:a copy`.** Skips re-encode entirely. HLS clients all support AAC + 48 kHz directly, and skipping the re-encode eliminates the timestamp drift that was the most likely cause of the operator's "audio is very delayed" symptom (covers root causes #1 + #2 from §3.5).
   - **Anything else (DTS, AC3, FLAC, AAC-but-not-48 kHz, unknown) → `-c:a aac -b:a 128k -ar 48000`.** The `-ar 48000` resample is the new piece — without it, the AAC encoder's default sample rate produces drift on non-48 kHz sources (root cause #1 from §3.5, but applied proactively).
   - **Defaults (when audio params aren't known) fall through to the safe re-encode path** — copying an unknown stream into HLS that expects AAC produces a broken playlist or works only by luck.
3. **Why we didn't wait for the repro clip:** the two highest-probability root causes were both addressable at the cmd-line level without runtime data, and `_probe_audio_params` already runs at session start (M4 instrumentation), so we have the source-codec info needed to branch correctly. Shipping the proactive fix means the operator's next stream attempt either (a) plays cleanly with no audio delay, or (b) reveals it's a different root cause (libmpv-side AV-sync, not server-side encoding) that the diagnostic logs will pinpoint.

**Tests (+4):** `test_build_ffmpeg_cmd_uses_c_a_copy_when_source_is_aac_at_48khz` / `_resamples_to_48khz_when_source_is_44100hz_aac` / `_resamples_when_source_is_dts_or_ac3` / `_falls_back_to_safe_re_encode_when_audio_unknown`.

**If the operator still reports audio delay after this:** the fix is libmpv-side, not server-side. Diagnostic log lines (`audio_probe` + `audio_negotiated`) will tell us whether the negotiated audio sample-rate / channel layout matches what FFmpeg sent — if so, the delay is in libmpv's audio output path on Android. v1.1 evaluation: `media_kit` configuration tweak or switch to ExoPlayer for Android-only playback.

**Goal:** confirm whether the audio delay is server-side (FFmpeg muxing), client-side (libmpv on Android), or content-specific. Land the right one-flag fix once we know.

**Step 1 — instrumentation only:**
- Server: log source audio params (codec / sample rate / channels / bitrate) at `start_stream` from `_resolve_source_metadata` (already runs ffprobe).
- Mobile: in `PlayerCubit` post-`PlayerReady` emit, read `_player!.state.tracks.audio` + `_player!.state.audioParams` and log them once.

**Step 2 — gather one repro clip's logs from the operator** (the file path + the mobile log line + the server log line for that session_id). Pattern-match:
- Source audio is 44.1 kHz / 96 kHz → likely sample-rate drift from AAC re-encode at 48 kHz default. Fix: `-ar 48000` resample at FFmpeg.
- Source audio is AAC at 48 kHz already → unnecessary re-encode introducing drift. Fix: switch to `-c:a copy` when source is AAC + 48 kHz.
- Source audio is otherwise normal but Android players consistently delay → upstream libmpv. Fix: document; consider switching to ExoPlayer on Android in v1.1 (large change).

**Tests:** none until a fix is identified. Instrumentation alone has no behaviour to test.

**Acceptance:** operator reports they can't tell audio is delayed (or the delay is below their perception threshold).

---

## 5 · Decisions Locked In

These were drafted as "open questions" but all have clear defaults — folded into the milestone work as resolved.

1. **`-readrate` applies uniformly to every session** — cold start, resume, post-seek-restart. The cost is ~4 s extra wait for the first segment on stream-copy / ~6.7 s on transcode; imperceptible vs the existing playlist-readiness wait.
2. **Post-seek buffer-fill at `-readrate 1.5` is acceptable** — 30 s of source buffer needs ~20 s wall to fill, the existing `_SeekingOverlay` covers that gap. Verify during M2 acceptance; only revisit if real-device testing exposes a stutter.
3. **Mobile buffer goes in bytes first** — media_kit's `PlayerConfiguration.bufferSize` is the simpler knob. If M3 doesn't hit its first-frame target, escalate to raw MPV options (`--demuxer-readahead-secs=8`).
4. **M1's seek-on-start path must not break the HDR→SDR toggle.** `setTonemap` calls `startStream` again with the file's current `last_progress_sec`; the server now applies `-ss` to that, which should work cleanly (mid-playback toggle was already a session restart). Covered by a new `test_setTonemap_re_seeks_to_resume_position` test in M1.

---

## 6 · Future Work — deferred to v1.1

### Sliding-window encoder (kill-and-resume FFmpeg every N seconds)

**Why deferred:** see §3.2 — `-readrate 1.5` covers the operator's stated concern (CPU/GPU/heat) at 5 LoC. A real sliding-window encoder would be another ~300–500 LoC of state-machine work for a marginal benefit in a narrow case (user pauses for an hour and FFmpeg should also pause).

**What it would look like (when we build it):**

1. New session-state field: `encoder_paused` (bool) + `encoder_paused_at_segment` (int).
2. Background task per active session monitoring the gap between (a) FFmpeg's last-produced segment and (b) the player's last-requested segment.
3. When gap exceeds `target_buffer_segments` (default 5 = ~30 s) → kill FFmpeg, mark session paused.
4. When player's last-requested segment approaches the encoded-up-to mark (within 2 segments) → respawn FFmpeg with `-ss <next_segment_start>` and continue.
5. On `stop_stream`: cancel the monitor + tear down as today.

**Pre-requisites for the v1.1 sliding-window milestone:**
- Add `peak_disk_bytes_per_session` + `idle_minutes_while_paused_per_session` telemetry to `stream_sessions` so we have data justifying the rewrite.
- Confirm the seek-restart path's `_terminate_ffmpeg` + `_seek_locks` machinery survives high-frequency invocation (each buffer cycle = one restart).
- Spec the "player approaching end of buffer" trigger — naive `last_requested_segment` isn't enough (player pre-buffers; we need a proper margin).

**When to revisit:** if real-user telemetry post-M2 shows >50 % of sessions exceed 1 GB peak disk OR >25 % of sessions have idle-while-paused windows > 5 min. Until then, the simple flag wins on cost-benefit.

### Other parked items

- `-c:a copy` audio short-circuit when source is AAC at 48 kHz — likely lands as the M4 fix; promoted out of "future" once the diagnostic clip arrives.
- Adaptive `-readrate` based on real-time fan / power telemetry (e.g. throttle harder when fan RPM exceeds threshold). Cute but premature.

---

## 7 · Test Strategy Summary

| Layer | M1 | M2 | M3 | M4 |
|---|---|---|---|---|
| Server unit (`pytest`) | ✅ 5 tests on `start_stream` query param + DB fallback | ✅ 4 tests on `_build_ffmpeg_cmd` | — | — (instrumentation only) |
| Mobile unit (`flutter test`) | ✅ 3 tests on PlayerCubit (no-double-seek + setTonemap-live-position + setTonemap-resumes-from-live) | — | — | — |
| Manual / smoke | open half-watched file → resume-from-progress instant; toggle HDR→SDR at 47:23 → resumes from ~47:23 not 0:00 | run a full-movie session, monitor CPU/GPU | stopwatch tap-to-frame | gather one repro clip's logs |

Expected suite delta: **+9 server tests, +3 mobile tests**. Server `669 → 678`, mobile `75 → 78`.  *Actual at close-out (with §16 + §17 + same-day follow-on combined):* server `669 → 695` (+26 across the full streaming-pipeline batch), mobile `75 → 78`.

---

## 8 · Sequenced summary (TL;DR)

1. **M1 — server-side `seek_sec` plumbing for both initial-spawn (DB fallback) and setTonemap (live-position query param); drop client-side `player.seek` on resume.** ~60 LoC, unblocks resume **and** the HDR-toggle bug entirely.
2. **M2 — add `-readrate 1.5` to `_build_ffmpeg_cmd`.** ~5 LoC, eliminates server-pegging.
3. **M3 — lower media_kit's startup buffer to 4 MiB.** ~3 LoC mobile, faster first-frame.
4. **M4 — instrument audio params; defer fix until repro clip arrives.** Logging only.
5. **(v1.1) Sliding-window encoder** — only if telemetry post-M2 justifies the complexity.

After M1–M3 land, the player should resume instantly, the home server should stay quiet during long streams, and the first frame should appear in single-digit seconds on stream-copy.

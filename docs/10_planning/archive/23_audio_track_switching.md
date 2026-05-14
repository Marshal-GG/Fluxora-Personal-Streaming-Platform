# Plan 23 — Server-restart audio track switching (FFmpeg-pinned tracks)

> **Status:** ✅ Archived 2026-05-15 — code shipped, end-to-end real-device verification deferred. Effectively **superseded by [plan 24](../24_player_audio_reliability_plan.md)** which replaces the Android engine with Media3 ExoPlayer and removes the need for the workaround. The `/audio-track` endpoint stays in the codebase as a fallback for future clients that can't do client-side track switching.
> **Shipped:** 2026-05-15 (commits `089f091` server, `d4e18bf` mobile)
> **Reactive plan** — no upfront design doc; this archive captures what shipped and why.

## Why this plan existed

Plan 22 added multi-audio-track support: server emits every audio track in the segments; mobile picks one via `media_kit.Player.setAudioTrack`. Tested fine in isolation — broke on a real Oplus device with a 5.1 AC3 multi-audio file. Symptoms (operator-reported 2026-05-15):

1. **Pause → switch audio → resume:** audio dies for ~20 s, then libmpv stalls completely; only a manual seek recovers.
2. **Switch audio while playing:** video plays with no audio for ~20 s, then the stream stalls; seeking recovers.

Multiple cubit-level workarounds attempted, all failed:
- Bare `setAudioTrack`
- `pause + setAudioTrack + seek + play`
- `setAudioTrack + seek-to-current`
- `setAudioTrack + 1s-back seek`
- libmpv `ao=audiotrack` AO override (kept — independently helpful for channel-mask / focus issues on Android)
- Wakelock fix (kept — independently helpful for play/pause audio dropouts)

Root cause (confirmed during plan 24 scoping): libmpv's HLS demuxer on Android can't recover from a fmp4 init-segment vs. segments contract change mid-session, and switching tracks in libmpv-on-HLS requires a demuxer reset that the bundled Android build doesn't ship cleanly.

## What plan 23 ships instead

**Server-side track pinning + FFmpeg restart.** Mobile asks server to switch the track; server pins the chosen audio track in FFmpeg via `-map 0:a:<index>?` and respawns from the current playhead. The playlist URL is unchanged but its contents are rewritten with a new init.mp4 declaring only the pinned track. Mobile re-opens the playlist on the player so libmpv flushes its cached HLS state.

Sidesteps the libmpv-on-HLS track-switch path entirely — the player sees a clean new playlist that only declares one audio track, which is the case it already handles correctly.

## What shipped

### Server

- **`apps/server/services/ffmpeg_service.py`** — new module-level `_session_pinned_audio_track: dict[str, int] = {}` cache; new helpers `set_session_pinned_audio_track(session_id, index)`, `clear_session_pinned_audio_track(session_id)`, `get_session_pinned_audio_track(session_id) -> int | None`. `_build_ffmpeg_cmd` accepts new `pinned_audio_track_index: int | None = None` param — when non-None it emits `-map 0:a:<index>?` (single-track) instead of `-map 0:a?` (all tracks). `_ensure_fmp4_init_segment` matches with the same shape so init.mp4 declares only the pinned track. `stop_stream` calls `clear_session_pinned_audio_track` to free cache.
- **`apps/server/routers/stream.py`** — new endpoint `POST /api/v1/stream/{session_id}/audio-track`. Reads `{index, current_position_sec}` from body, pins the track, unlinks the existing `init.mp4` so libmpv re-fetches the rewritten init declaring the single pinned track (without this step the stale multi-track init mismatched the new single-track segments and libmpv hung), and respawns FFmpeg from the segment-snapped seek position. Returns `applied_seek_sec` so the cubit updates `_playlistOffsetSec` for the source-time scrubber.
- **`apps/server/models/stream_session.py`** — new `AudioTrackSwitchRequest(index: int, current_position_sec: float)` and `AudioTrackSwitchResponse(session_id, playlist_url, pinned_audio_track_index, applied_seek_sec)` Pydantic models.

### Mobile

- **`apps/mobile/lib/features/player/domain/repositories/player_repository.dart`** — new `Future<double> switchAudioTrack({required String sessionId, required int index, required double currentPositionSec})` interface; docstring documents the server-restart contract.
- **`apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart`** — POSTs to `/audio-track`; defensive fall-back to caller-supplied position if `applied_seek_sec` is missing from the response.
- **`apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`** — `selectAudioTrack` rewritten to call `switchAudioTrack`, re-open the playlist with `player.open(Media(url, httpHeaders: headers), play: wasPlaying)`, and update state with the new `selectedAudioTrackIndex` + `playlistOffsetSec`. Also: libmpv `ao=audiotrack` AO override for Android sessions (Android's OpenSL ES default emulates channel mask incorrectly on Oplus / OnePlus and churns AudioTrack on every play/pause).
- **`apps/mobile/test/features/player/player_cubit_test.dart`** — updated expectations for the new switch path.

## Test counts at ship

- Server: 827 → 830 (+3 around the new endpoint) — full count to be confirmed once plan 24 docs sweep tallies.
- Mobile: 97 → 99 (+2, cubit_test updates) — same caveat.

(Operator did not run a fresh post-init.mp4-unlink-fix log; counts above are based on local pre-push runs. CI on `main` after push will be authoritative.)

## Sharp edges

1. **Switch latency.** Server-restart costs the FFmpeg respawn delay (~200-500 ms on a warm cache) + the segment-wait (`hls_time` floor, currently 2 s) before the playlist is ready for libmpv to re-fetch. UX is closer to a seek than a click — acceptable for an explicit operator action, would not be acceptable for any auto-switch behaviour.
2. **`-map 0:a:N?` vs `-map 0:a?`.** Switching from "all tracks" to "one track" mid-session would force libmpv into the same demuxer-reset path that hangs the original `setAudioTrack` call. The endpoint sidesteps this by unlinking init.mp4 — but a future plan that re-uses `_build_ffmpeg_cmd` for some other purpose needs to honour the pin cache or it will re-emit multi-track segments under a single-track init.
3. **Plan 22 picker still draws all tracks.** The cubit's `availableAudioTracks` comes from `StreamStartResponse.audio_tracks` (probed at scan, persisted in `media_files.audio_tracks`). That doesn't change when a track is pinned — the picker still shows every track in the source. The selected-row highlight tracks `selectedAudioTrackIndex` which is the source-stream index (not a position in the pinned set).
4. **Effectively dead code after plan 24 ships.** The endpoint stays in the codebase as a fallback for future non-Android clients that can't do native track switching. Mobile cubit will stop calling it once `ExoPlayerEngine.setAudioTrack` is live (Media3 `TrackSelectionParameters` overrides do the switch client-side without any server roundtrip).
5. **End-to-end real-device verification is incomplete.** The init.mp4 unlink fix landed late in the session; operator didn't run a fresh log against it. Plan 24 obviates this work, so we are not blocking on plan 23 verification — the code stays in the tree because removing it now would add churn before plan 24 lands.

## What this plan does NOT fix (and why plan 24 exists)

- The libmpv-on-Android underlying brittleness — channel-mask emulation, AudioTrack churn, mid-stream demuxer reset failures — is unchanged.
- The HDR-multi-audio-silent bug (separate symptom from track switching) is unaddressed; plan 24 M6 captures it.
- Pause / resume audio dropouts: mitigated by the wakelock fix (shipped with plan 23 in `apps/mobile/lib/features/player/presentation/screens/player_screen.dart`) but not root-caused — plan 24 makes the wakelock fix redundant by removing the surface-recreate-on-flag-toggle that triggered the dropouts.

## Files touched

```
apps/server/services/ffmpeg_service.py                                     (pin cache + _build_ffmpeg_cmd + _ensure_fmp4_init_segment + stop_stream clear)
apps/server/routers/stream.py                                              (POST /api/v1/stream/{session_id}/audio-track + init.mp4 unlink)
apps/server/models/stream_session.py                                       (AudioTrackSwitchRequest + AudioTrackSwitchResponse)
apps/mobile/lib/features/player/domain/repositories/player_repository.dart (switchAudioTrack interface)
apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart (switchAudioTrack POST impl)
apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart       (selectAudioTrack server-restart + libmpv ao=audiotrack)
apps/mobile/test/features/player/player_cubit_test.dart                    (updated expectations)
```

## Out of scope / future work

- **Multi-track + re-encode paths** — plan 22's carry-forward. Re-encode paths still emit single-track (`-map 0:a:0?`); plan 23's pin cache is bypassed there.
- **Plan 24 will deprecate the cubit-side caller.** Endpoint stays as future-client fallback.
- **HDR-multi-audio silent bug** — separate. Plan 24 M6.

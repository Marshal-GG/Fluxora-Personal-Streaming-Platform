# Plan 21 — Client-side audio decoding (audio stream-copy + audio-only auto-fallback)

> **Status:** 🚧 Drafted 2026-05-12 — awaiting M1 sign-off
> **Layers on top of:** plan 19 §M7 (client-decode default), plan 20 (auto-mode fallback mechanism).

## Context

Plan 19 §M7 + plan 20 made **video** stream-copy the default and added a transparent fallback to server transcode for clients that can't decode the source codec. Operator confirmed playback works; server CPU/GPU drops to near-zero on supported sources.

But **audio is still being transcoded server-side** in every session that uses a non-AAC source — by design of the current `ffmpeg_service.py` audio pipeline (see paths 2 + 3 of the three-path branch around line 600). That means:

- **FLAC libraries** (lossless source) are silently downgraded to AAC 128 kbps — ~85 % of the audio data thrown away on every play
- **AC3 / EAC3 surround** is re-encoded and may be downmixed to stereo (encoder defaults vary)
- **DTS / TrueHD** sources hit the same path (will be excluded from this plan — see Q1 below)
- **Opus** sources are converted to AAC at 128 k, which is a quality *regression* relative to Opus at the same bitrate (Opus is more efficient at low bitrates)

CPU cost of the audio re-encode is small (~3 % vs the tonemap chain), but the **quality cost is real** — on a high-end audio setup, lossless → AAC 128 k is audible. The bandwidth cost is also real for an operator with multiple devices on the same LAN.

This plan adds audio stream-copy for a curated allowlist of well-supported codecs, with the same auto-fallback machinery plan 20 introduced for video.

## Design decisions (locked in 2026-05-12)

| Q | Decision |
|---|---|
| Audio codec allowlist | `{aac, ac3, eac3, opus, flac}`. DTS / TrueHD / Atmos stay server-transcoded — licensed decoders, spotty mobile support, high failure rate not worth the optimization. |
| HLS container for non-AAC audio | Switch the session to **fmp4 (CMAF)** when audio stream-copy is in play and the audio codec is not AAC. MPEG-TS doesn't carry AC3/Opus/FLAC cleanly across all clients; fmp4 (HLSv7+) handles all of them and is already used for HEVC/AV1/VP9 video stream-copy. |
| Blocklist granularity | Separate `client_audio_codec_blocklist` table, mirroring plan 20's `client_codec_blocklist`. Audio decode failure is independent of video decode failure; combining them in one table would force unnecessary fallbacks. |
| Audio fallback scope | Audio-only re-encode — keep video stream-copying when only audio failed. Requires a third pipeline state (`_session_force_audio_transcode`) orthogonal to plan 20's `_session_force_transcode`. |
| Audio re-encode bitrate | **Bump from 128 k → 256 k** in all three existing audio re-encode paths. 256 k AAC is "transparent" for most listeners (Apple Music's high-quality tier). Cost: ~2× the audio bandwidth on re-encode sessions; trivial vs the video stream. After plan 21 ships, the re-encode path is only hit for DTS/TrueHD sources, tonemap-on sessions, and auto-mode audio fallbacks — but for those it should sound as good as possible. |
| Channel preservation | Re-encode paths preserve source channel count via `-ac:a:0 <source_channels>`. Stops the silent 5.1 → stereo downmix that the system AAC encoder sometimes does at default settings. Stream-copy already preserves channels by definition. |

## Behavior matrix

| Mode (plan 20) | Source audio codec | Audio path first attempt | On audio decode error within 6 s |
|---|---|---|---|
| `client-decode` | ∈ allowlist, tonemap OFF | Stream-copy | Error surfaces to user (operator picked strict mode) |
| `client-decode` | not in allowlist, OR tonemap ON | Transcode (existing 3-path branch) | N/A |
| `auto` | ∈ allowlist, tonemap OFF | Stream-copy | Server restarts with `_session_force_audio_transcode=True`; video stays stream-copy; blocklist row written for `(client_id, audio_codec)` |
| `auto` | not in allowlist, OR tonemap ON | Transcode | N/A |
| `server-transcode` (legacy) | any | Transcode | N/A |

Tonemap forcing audio re-encode is the existing path-2 behavior (the 2026-05-08 PTS-drift fix). Plan 21 preserves it — when tonemap is on, the video filter chain regenerates PTS, and stream-copied audio packets won't align cleanly, so audio must re-encode to get clean PTS.

## Migration

### 034 — `client_audio_codec_blocklist` table

```sql
CREATE TABLE client_audio_codec_blocklist (
    client_id    TEXT NOT NULL,
    audio_codec  TEXT NOT NULL,
    reason       TEXT,
    created_at   TEXT NOT NULL,
    PRIMARY KEY (client_id, audio_codec),
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);
```

Same shape as plan 20's `client_codec_blocklist`. Looked up at `/stream/start` time **only when `streaming_mode='auto'`**. Strict `client-decode` and legacy `server-transcode` ignore it.

## Server changes

### `services/ffmpeg_service.py`

- New module-level constant:
  ```python
  _AUDIO_STREAM_COPY_ALLOWLIST = frozenset({"aac", "ac3", "eac3", "opus", "flac"})
  ```
- New module-level `_session_force_audio_transcode: dict[str, bool]` — keyed by `session_id`; set to True after an audio fallback. Orthogonal to plan 20's `_session_force_transcode` (which forces full transcode); this only forces audio re-encode.
- New helper `set_session_force_audio_transcode(session_id: str, value: bool = True)` exposed to the router.
- New resolver `_resolve_audio_passthrough(...)` — returns `True` (stream-copy) when:
  - `apply_hdr_tonemap` is False
  - `source_audio_codec in _AUDIO_STREAM_COPY_ALLOWLIST`
  - `_session_force_audio_transcode.get(session_id, False)` is False
- `start_stream` audio path becomes (with 256k bump + channel preservation):
  ```python
  audio_passthrough = _resolve_audio_passthrough(...)
  source_channels = source_audio_channels or 2  # safe default if probe failed
  if audio_passthrough:
      cmd.extend(["-c:a", "copy"])
  elif audio_is_aac_48khz and apply_hdr_tonemap:
      cmd.extend(["-c:a", "aac", "-b:a", "256k", "-ac", str(source_channels)])
  else:
      cmd.extend(["-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", str(source_channels)])
  ```
  Existing path 1 (`aac@48kHz, tonemap OFF → copy`) folds into the new `audio_passthrough` branch — same outcome, single decision point. Bitrate jumps from 128 k to 256 k on the two re-encode paths; `-ac` is added on both to stop the silent 5.1 → stereo downmix that the system AAC encoder sometimes does at default settings. `_probe_audio_stream` will need to return `channels` alongside the existing `codec_name` / `sample_rate`.
- fmp4 trigger extends to cover non-AAC audio stream-copy:
  ```python
  use_fmp4 = (
      direct_remux_hevc or direct_remux_av1 or direct_remux_vp9
      or (audio_passthrough and source_audio_codec != "aac")
      or (not direct_remux and meta.segment_fmt == "fmp4")
  )
  ```
  Result: an H.264 video + AC3 audio session that previously ran MPEG-TS + AAC-re-encoded now runs fmp4 + AC3 passthrough.
- `stop_stream` clears the audio-force flag alongside the existing video-force flag.
- New diagnostic — extend the existing `stream_decision` log line:
  ```
  stream_decision session=<id> source_codec=<v> audio_codec=<a> mode=<auto|client-decode|server-transcode>
                  video_path=<stream-copy|transcode> audio_path=<stream-copy|transcode>
                  reason=<global|library-override|client-blocklist|forced-fallback|audio-forced-fallback>
  ```

### `services/client_audio_codec_service.py` (new)

Mirror of `client_codec_service.py`:

- `is_blocked(db, client_id: str, audio_codec: str) -> bool`
- `add_block(db, client_id: str, audio_codec: str, reason: str)` — idempotent (`INSERT OR IGNORE`)

### `routers/stream.py`

- `/start` consults `client_audio_codec_service.is_blocked` **only when `streaming_mode='auto'`**. When blocked → `set_session_force_audio_transcode(session_id, True)` before `ffmpeg_service.start_stream`. Independent of the existing video blocklist lookup; both can fire.
- `StreamStartResponse` adds:
  - `audio_streaming_mode: Literal["stream-copy", "transcode"]` — what the server actually picked for this session, so the mobile client knows whether to arm its audio-fallback watcher.
- New endpoint `POST /api/v1/stream/{session_id}/fallback-audio-transcode`:
  - 404 if session not found / ended
  - 403 if session isn't owned by caller
  - **409 if `streaming_mode` is not `'auto'`** — strict modes surface errors to user
  - Records `(client_id, source_audio_codec)` in `client_audio_codec_blocklist` (idempotent)
  - Sets `_session_force_audio_transcode[session_id] = True`
  - Calls `restart_stream` from the live playhead position (`current_position_sec` in body)
  - Returns 200 with `{session_id, playlist_url, forced_audio_transcode: true}`

### `models/stream_session.py`

- `StreamStartResponse` gains `audio_streaming_mode: Literal["stream-copy", "transcode"]`.
- New `FallbackAudioTranscodeRequest{current_position_sec: float ≥ 0}`.
- New `FallbackAudioTranscodeResponse{session_id: str, playlist_url: str, forced_audio_transcode: bool}`.

## Mobile + desktop player

### Mobile (`apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`)

- **Only when `response.streamingMode == 'auto'` AND `response.audioStreamingMode == 'stream-copy'`** — subscribe to audio-related errors within 6 s after `PlayerReady`. Audio errors look different across platforms; pragmatic detection:
  - `_player!.stream.error` events whose payload mentions audio (heuristic match on `'audio'`/`'aac'`/`codec` keywords)
  - `audioParams` stream not emitting non-empty values within 4 s (proxy for "audio track failed to initialize")
- On any audio error in the window → `PlayerRepository.reportFallbackAudioTranscode(sessionId, currentPositionSec)`.
- On success → `_player!.open(Media(streamPath))` reload — audio is now transcoded, video still stream-copy.
- Cancel the watcher on first non-empty `audioParams` (proves audio track is live).
- Independent of plan 20's video watcher — both can fire in the same session.

### Desktop (`apps/desktop/lib/features/player/...`)

Mirror the cubit change. Same pattern, same 6 s window, same conditions.

### Repositories (mobile + desktop)

- Add `reportFallbackAudioTranscode(sessionId, currentPositionSec)` to `PlayerRepository`:
  ```dart
  _apiClient.post('/api/v1/stream/$sessionId/fallback-audio-transcode',
                   body: {'current_position_sec': pos})
  ```

## Desktop UI

No new settings. The `_StreamingModeCard` 3-option control from plan 20 still applies — the audio-fallback behavior is inferred from the existing `streaming_mode` setting; nothing new for the operator to choose.

The Operator-facing description on the **Auto** card body should be revised to mention audio: *"Tries client decoding first for near-zero server load. If a device cannot play the original video or audio codec, the server transparently falls back to transcoding just the affected stream for that session."*

## Tests

### Server (~10 new tests)

- `test_client_audio_codec_service.py` (new) — `is_blocked` / `add_block` round-trip; idempotent insert; cascade delete when client is deleted.
- `test_stream.py` additions:
  - `test_audio_passthrough_resolver_allowlist` — every codec in the allowlist resolves to True with tonemap OFF and no session-force flag.
  - `test_audio_passthrough_resolver_blocklist_codecs` — DTS / TrueHD / unknown codecs resolve to False.
  - `test_audio_passthrough_resolver_tonemap_forces_transcode` — even with allowlist codec, tonemap ON → False.
  - `test_audio_passthrough_resolver_session_force_overrides` — `_session_force_audio_transcode[sid] = True` → False even with allowlist codec.
  - `test_start_stream_consults_audio_codec_blocklist` — pre-seed blocklist row; assert `_session_force_audio_transcode[sid] = True` after start under `auto` mode.
  - `test_fallback_audio_transcode_endpoint_records_blocklist_and_restarts` — POST endpoint, assert blocklist row + restart_stream call.
  - `test_fallback_audio_transcode_409_under_strict_mode` — strict mode rejects the endpoint.
  - `test_start_stream_response_includes_audio_streaming_mode` — response payload has the new field.
  - `test_fmp4_forced_when_non_aac_audio_passthrough` — ffmpeg cmd includes fmp4 muxer when audio = ac3/opus/flac and audio_passthrough is True.
  - `test_reencode_paths_use_256k_bitrate` — both re-encode paths emit `-b:a 256k` (not 128k).
  - `test_reencode_paths_preserve_source_channels` — `-ac:a:0 <n>` matches probed source channel count; defaults to 2 when probe failed.
  - `test_codec_name_normalization_excludes_variants` — `aac_lc`, `dts_hd_ma`, `flac` (various ffprobe outputs) all resolve correctly against the allowlist; specifically, `dts*` always excluded, `aac*` always included.

### Mobile (~3 new tests)

- `player_cubit_test.dart` additions:
  - `audio-fallback watcher arms only when streamingMode=auto AND audioStreamingMode=stream-copy`
  - `audio-fallback watcher fires fallback-audio-transcode and reloads playlist on audio error within 6 s`
  - `audio-fallback watcher cancels on first non-empty audioParams`

### Desktop (~3 new tests)

Same shape, mirrored to desktop player cubit.

## Milestones

| M | Title | Est. | Files |
|---|---|---|---|
| **M1** | Migration 034 + `client_audio_codec_service` | 1.5 h | `034_client_audio_codec_blocklist.sql`, `services/client_audio_codec_service.py`, `tests/test_client_audio_codec_service.py` |
| **M2** | `ffmpeg_service` audio passthrough + fmp4 switch + session-force flag + 256 k bitrate bump + `-ac` channel preservation + `_probe_audio_stream` channels return | 3.5 h | `services/ffmpeg_service.py`, `tests/test_stream.py` (passthrough resolver tests + fmp4 trigger test + 256 k bitrate assertion + channel-preservation assertion + codec-name normalization edge-case test) |
| **M3** | `/start` response + `/fallback-audio-transcode` endpoint | 2 h | `routers/stream.py`, `models/stream_session.py`, `models/settings.py` (if any types touched), `tests/test_stream.py` (endpoint tests) |
| **M4** | Mobile + desktop player audio watcher | 3 h | `apps/mobile/lib/features/player/...`, `apps/desktop/lib/features/player/...`, both `player_repository*.dart`, both cubit tests |
| **M5** | Tests sweep + doc-update-protocol sweep | 2 h | All `docs/` touched (api_contracts, backend_architecture, frontend_architecture, database_schema, migration_guide, current_status, gotchas, roadmap), AGENT_LOG entry |

**Total: ~12 h** — slightly larger than plan 20 (~10 h) due to the bundled bitrate/channels work.

## Files touched

```
apps/server/database/migrations/034_client_audio_codec_blocklist.sql            (new)
apps/server/models/settings.py                                                  (if Literal types extend)
apps/server/models/stream_session.py                                            (StreamStartResponse + new request/response)
apps/server/services/ffmpeg_service.py                                          (audio passthrough + fmp4 + session-force)
apps/server/services/client_audio_codec_service.py                              (new)
apps/server/routers/stream.py                                                   (audio blocklist consult + fallback endpoint)
apps/server/tests/test_stream.py                                                (passthrough resolver + endpoint tests)
apps/server/tests/test_client_audio_codec_service.py                            (new)
apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart  (Auto card body text revised)
apps/mobile/lib/features/player/domain/repositories/player_repository.dart      (reportFallbackAudioTranscode method)
apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart   (POST call)
apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart            (audio watcher)
apps/desktop/lib/features/player/...                                            (mirror mobile)
docs/00_overview/current_status.md
docs/03_data/02_database_schema.md
docs/03_data/04_migration_guide.md
docs/04_api/01_api_contracts.md
docs/08_frontend/01_frontend_architecture.md
docs/09_backend/01_backend_architecture.md
docs/10_planning/01_roadmap.md
docs/12_guidelines/03_gotchas.md
```

## Sharp edges to watch

1. **Audio-error heuristic on mobile** — media_kit/libmpv don't emit a clean "audio decode failed" event; the `stream.error` payload is opaque. The plan uses a keyword heuristic + `audioParams` not arriving as a proxy. If both signals are unreliable, fall back to a stricter "first 6 s with no audio frames" timer. M4 will need real-device testing.
2. **Channel layout preservation** — when audio stream-copies a 5.1 AC3 track, players must handle 5.1 output. Most modern phones downmix to stereo at the OS audio output level (correct behavior). Verify on Android with AAudio + iOS with AVAudioEngine. No code change expected for stream-copy, but **re-encode paths now pass explicit `-ac:a:0 <n>` to prevent the encoder defaulting to stereo** when source is 5.1.
3. **fmp4 switch is per-session not per-track** — when audio forces fmp4, video also rides fmp4 even if it would have been MPEG-TS. This is fine for H.264 (fmp4 carries H.264 without issue) but the `use_fmp4` decision must happen before the video filter chain is assembled. M2 test `test_fmp4_forced_when_non_aac_audio_passthrough` guards this.
4. **PTS alignment with mixed pipelines** — video stream-copy + audio transcode (the fallback path) is novel for this codebase. Existing path 1 (audio stream-copy + video stream-copy) and existing paths 2-3 (audio transcode + video transcode) are exercised; the new combo is not. M2 should add an explicit smoke test that a fallback-audio-transcode-restarted session produces a playlist with aligned audio/video segment timestamps.
5. **FFprobe codec name normalization** — the allowlist uses exact string match against `{aac, ac3, eac3, opus, flac}`. Verify ffprobe doesn't report variants like `aac_lc`, `aac_he`, `ac3_fixed`, `flac_be`. If it does, normalize before the membership check (e.g., split on `_` and take the first token). Add an M2 test with a sample of `_probe_audio_stream` outputs covering edge cases — particularly Bluray rips, where DTS-HD MA shows as `dts` (which is correctly excluded from the allowlist, but worth asserting).
6. **DD+ Atmos passthrough is a side effect, not a feature** — EAC3 in the allowlist means Atmos-over-EAC3 streams will stream-copy. On Atmos-capable devices (Apple TV, flagship Android, Dolby-licensed soundbars over HDMI passthrough) this gives full Atmos. On non-Atmos devices the OS gracefully downmixes. Worth noting in docs as a positive side effect, but not a behavior to advertise — Fluxora doesn't sniff Atmos metadata, it just doesn't get in the way.
7. **Stream-copy bandwidth ≠ transcode bandwidth** — a FLAC source at 1000 kbps + a 50 Mbps Blu-ray video stream-copies at the full source bitrate. On LAN this is fine. On a marginal internet connection (mobile cellular, weak Wi-Fi) the combined audio + video may exceed available throughput where the prior 128 k AAC re-encode + segmented video previously fit. This is consistent with plan-19's existing video-stream-copy bandwidth profile (which already has this issue) — no new code, but flag in `gotchas.md` so operators understand that the "near-zero server CPU" win comes with "no server-side bitrate cap" as the trade.
8. **Audio-only files (music libraries)** — the streaming pipeline is built for video. If/when Fluxora supports music playback (out of scope for v1), audio stream-copy for music files is even higher-value than for video soundtracks. Plan 21's resolver should work unchanged for audio-only sessions; M5 docs should call out that this surfaces a v1.1 lane.
9. **Mid-stream codec changes** — rare but real: some files (concatenated rips, DVD VOBs) change audio codec partway through. FFmpeg handles this for transcode but stream-copy may produce a broken segment at the boundary. Detection is impractical without scanning the whole file first; accept the failure mode and rely on auto-mode fallback to recover. Document in gotchas.

## Out of scope / future work

Deliberately not in plan 21; surface as separate plans if needed:

- **Audio track selection** — files with multiple audio tracks (English + commentary + foreign-language dub) currently always play track 0. A "pick audio track" feature is a separate UX + protocol change, not a stream-copy concern.
- **Buffer-stall extension to auto-fallback watcher** — plan 20's Next-Agent #3 flagged this as a "plan-21 candidate." Plan 21 stays scoped to *decode errors* only. If real-device testing shows that audio-decode failures *also* manifest as buffer stalls (player hangs without emitting an error), revisit in plan 22.
- **Source-bitrate-aware re-encode** — instead of fixed 256 k, scale to `min(source_bitrate, 256k)` so a 96 k Opus source doesn't get *upcoded* to 256 k AAC (which is wasteful, not lossy). Trivial to add later; not a v1 priority.
- **libfdk_aac encoder** — better quality than the system `aac` encoder at every bitrate, but GPL-incompatible and would require shipping a custom FFmpeg build. Distribution headache outweighs the marginal quality gain over `aac@256k`.
- **HLS hi-res audio (≥ 96 kHz)** — `-ar 48000` on the re-encode path downsamples 96/192 kHz FLAC sources. Stream-copy paths preserve original sample rate via fmp4. If hi-res-aware re-encode ever matters, this is where to look.

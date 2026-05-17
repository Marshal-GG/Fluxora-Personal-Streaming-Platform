# Plan 21 — Client-side audio decoding (audio stream-copy + audio-only auto-fallback)

> **Status:** ✅ Archived 2026-05-12 — all 5 milestones shipped
> **Shipped:** 2026-05-12
> **Layers on top of:** plan 19 §M7 (client-decode default), plan 20 (auto-mode fallback mechanism).
>
> **What shipped:**
> - Migration 034 — `client_audio_codec_blocklist` table (composite PK client_id+audio_codec; FK CASCADE to clients)
> - `services/client_audio_codec_service.py` — `is_blocked` / `add_block` (idempotent); consulted only under `streaming_mode='auto'`
> - `ffmpeg_service.py` — `_AUDIO_STREAM_COPY_ALLOWLIST = frozenset({"aac","ac3","eac3","opus","flac"})`, `_session_force_audio_transcode` dict, `_resolve_audio_passthrough` resolver, fmp4 forced for non-AAC audio stream-copy, 128k → 256k AAC re-encode bitrate, `-ac` channel preservation, `stream_decision` log extended with audio fields
> - `routers/stream.py` — `/start` consults audio blocklist under auto mode; new `POST /{session_id}/fallback-audio-transcode` (404/403/409 semantics)
> - `models/stream_session.py` — `StreamStartResponse.audio_streaming_mode`, `FallbackAudioTranscodeRequest`, `FallbackAudioTranscodeResponse`
> - `apps/mobile/lib/features/player/` — `audioStreamingMode` entity field, `reportFallbackAudioTranscode` repository method + impl, `_scheduleAutoAudioFallbackWatcher` cubit logic (arms when streaming_mode='auto' AND audio_streaming_mode='stream-copy'; 6 s window; audioParams-silence + keyword-error heuristics; 4 new cubit tests)
> - `apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart` — Auto card body text revised to mention audio; no desktop player code added (desktop has no player feature)
> - **Test counts at ship: server 814 (+22 vs 792 pre-plan-21); mobile player cubit 25 (+4 vs 21)**
> - **Sharp edges documented in `docs/12_guidelines/03_gotchas.md`:** audio stream-copy bandwidth uncapped; mid-stream codec changes; audioParams-silence heuristic fragility; `_ensure_fmp4_init_segment` audio codec mismatch; duplicate `_probe_audio_params` per `/start`; desktop has no player

---

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

### Desktop

**Desktop has no player feature.** `apps/desktop/lib/features/player/` does not exist. Desktop is a pure control panel — encoder settings, libraries, clients, transcoding, storage. Plan 21's "Mirror cubit change for desktop" was based on an incorrect assumption confirmed by the M4 agent. Desktop scope was limited to the Auto card body text revision in `encoder_settings_screen.dart`.

### Repositories (mobile)

- Add `reportFallbackAudioTranscode(sessionId, currentPositionSec)` to `PlayerRepository`:
  ```dart
  _apiClient.post('/api/v1/stream/$sessionId/fallback-audio-transcode',
                   body: {'current_position_sec': pos})
  ```

## Desktop UI

No new settings. The `_StreamingModeCard` 3-option control from plan 20 still applies — the audio-fallback behavior is inferred from the existing `streaming_mode` setting; nothing new for the operator to choose.

The Operator-facing description on the **Auto** card body was revised: *"Tries client decoding first for near-zero server load. If a device cannot play the original video or audio codec, the server transparently falls back to transcoding just the affected stream for that session."*

## Tests

### Server (22 new tests across M1–M3)

- `test_client_audio_codec_service.py` (new, 6 tests) — `is_blocked` / `add_block` round-trip; idempotent insert; cascade delete when client is deleted.
- `test_stream.py` additions (9 tests in M2 + 7 tests in M3):
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

### Mobile (4 new tests in M4)

- `player_cubit_test.dart` additions:
  - `audio-fallback watcher arms only when streamingMode=auto AND audioStreamingMode=stream-copy`
  - `audio-fallback watcher fires fallback-audio-transcode and reloads playlist on audio error within 6 s`
  - `audio-fallback watcher cancels on first non-empty audioParams`
  - Entity-level JSON round-trip test + gating regression guard (headless; libmpv can't be instantiated in tests)

### Desktop (0 new tests)

Desktop has no player code to test.

## Milestones

| M | Title | Est. | Status |
|---|---|---|---|
| **M1** | Migration 034 + `client_audio_codec_service` | 1.5 h | ✅ shipped |
| **M2** | `ffmpeg_service` audio passthrough + fmp4 switch + session-force flag + 256 k bitrate bump + `-ac` channel preservation + `_probe_audio_stream` channels return | 3.5 h | ✅ shipped |
| **M3** | `/start` response + `/fallback-audio-transcode` endpoint | 2 h | ✅ shipped |
| **M4** | Mobile player audio watcher (desktop has no player) | 3 h | ✅ shipped |
| **M5** | Tests sweep + doc-update-protocol sweep | 2 h | ✅ shipped |

**Total: ~12 h** — slightly larger than plan 20 (~10 h) due to the bundled bitrate/channels work.

## Files touched

```
apps/server/database/migrations/034_client_audio_codec_blocklist.sql            (new)
apps/server/models/stream_session.py                                            (StreamStartResponse + new request/response)
apps/server/services/ffmpeg_service.py                                          (audio passthrough + fmp4 + session-force)
apps/server/services/client_audio_codec_service.py                              (new)
apps/server/routers/stream.py                                                   (audio blocklist consult + fallback endpoint)
apps/server/tests/test_stream.py                                                (passthrough resolver + endpoint tests)
apps/server/tests/test_client_audio_codec_service.py                            (new)
apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart  (Auto card body text revised)
apps/mobile/lib/features/player/domain/entities/stream_start_response.dart      (audioStreamingMode field)
apps/mobile/lib/features/player/domain/repositories/player_repository.dart      (reportFallbackAudioTranscode method)
apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart   (POST call)
apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart            (audio watcher)
apps/mobile/test/features/player/player_cubit_test.dart                         (4 new tests)
docs/00_overview/current_status.md
docs/03_data/02_database_schema.md
docs/03_data/04_migration_guide.md
docs/04_api/01_api_contracts.md
docs/08_frontend/01_frontend_architecture.md
docs/09_backend/01_backend_architecture.md
docs/10_planning/01_roadmap.md
docs/10_planning/archive/21_client_audio_decoding.md (this file — moved from 21_client_audio_decoding.md)
docs/12_guidelines/03_gotchas.md
```

## Sharp edges (all documented in `docs/12_guidelines/03_gotchas.md`)

1. **Audio-error heuristic on mobile** — `audioParams` silence watchdog is fragile on slow WAN; honest network stalls can cause a ~1 s false-positive transcode restart. Acceptable failure mode; real-device testing required.
2. **Channel layout preservation** — 5.1 AC3 stream-copy output; phones downmix at OS level. Verify on Android AAudio + iOS AVAudioEngine.
3. **fmp4 switch is per-session not per-track** — when audio forces fmp4, video also rides fmp4.
4. **PTS alignment with mixed pipelines** — video stream-copy + audio transcode fallback path is novel; not a confirmed defect but smoke-test worthy.
5. **FFprobe codec name normalization** — allowlist uses exact match; `_normalize_audio_codec` helper added.
6. **DD+ Atmos passthrough is a side effect, not a feature** — EAC3 allowlist entry passes Atmos-over-EAC3 through.
7. **Stream-copy bandwidth uncapped** — FLAC at 1000+ kbps + full video bitrate may exceed marginal WAN. Documented in gotchas.
8. **Audio-only files (music libraries)** — plan 21's resolver should work unchanged; surfaces as a v1.1 lane.
9. **Mid-stream codec changes** — concatenated rips may produce broken segment at codec-change boundary under stream-copy; auto-mode fallback recovers. Documented in gotchas.
- **`_ensure_fmp4_init_segment` audio codec mismatch** — init segment's hard-coded `-c:a aac` won't match non-AAC stream-copy segments. Latent defect; needs real-device audit. Documented in gotchas.
- **Extra `_probe_audio_params` per `/start`** — ~50-100 ms duplicate probe. Future fix: thread result or persist on `media_files`. Documented in gotchas.
- **Desktop has no player** — "mirror to desktop" = net-new architecture. Documented in gotchas.

## Out of scope / future work

- **Audio track selection** — files with multiple audio tracks always play track 0 in v1.
- **Buffer-stall extension to auto-fallback watcher** — plan 21 scoped to decode errors only.
- **Source-bitrate-aware re-encode** — fixed 256 k; `min(source_bitrate, 256k)` deferred to future.
- **libfdk_aac encoder** — GPL-incompatible; distribution headache outweighs marginal quality win.
- **HLS hi-res audio (≥ 96 kHz)** — `-ar 48000` downsamples; stream-copy paths preserve original rate.

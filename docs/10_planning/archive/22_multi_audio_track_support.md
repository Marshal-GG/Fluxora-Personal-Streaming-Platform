# Plan 22 — Multi-audio-track support (multiplex all + client-side picker)

> **Status:** 🚧 Drafted 2026-05-14 — awaiting M1 sign-off
> **Layers on top of:** plan 21 (audio stream-copy allowlist + auto-fallback). Builds on the same fmp4 + stream-copy pipeline.
> **Bandaid landed 2026-05-14** ahead of this plan — `_build_ffmpeg_cmd` was pinned to `-map 0:v:0 -map 0:a:0?` so segments match the init.mp4 fallback's single-audio-track contract. Multi-track files play their first track but the operator has no way to pick. This plan removes the bandaid and adds the picker.

## Context

The 2026-05-14 bandaid (`-map 0:v:0 -map 0:a:0?` in `_build_ffmpeg_cmd`) shipped because of a real bug: FFmpeg's HLS muxer with no explicit `-map` includes every audio stream from the source, but `_ensure_fmp4_init_segment` (the manual init.mp4 fallback) only declared `0:a:0?` in its moov. On multi-audio-track sources — **NVIDIA Game Bar dual-track captures (game audio + mic), multi-language movie rips, anime with JP/EN/commentary tracks** — media_kit on Android silently drops all audio because the init segment's track count disagrees with the segments'.

The bandaid restored playback but at the cost of every multi-track file being effectively single-track to the operator. There's no audio-language switch, no commentary toggle, no "swap to the mic-only track to hear the commentary clearly" affordance.

This plan adds proper multi-track support: **every audio track lives in the fmp4 output; the mobile player picks which to decode via the existing Audio bottom-sheet (plan §M14)**. Server doesn't restart on switch — the picker is purely client-side.

## Design decisions (locked in 2026-05-14)

| Q | Decision |
|---|---|
| Default track when operator hasn't picked | **Track 0 always.** Simplest; matches FFmpeg default; the picker handles the rest. No "preferred language" profile setting in v1 — added if a real operator needs it. |
| Switching mid-playback | **Multiplex all tracks into fmp4; client-side switch via media_kit's `setAudioTrack` API.** No server restart on switch → zero-latency change. Bandwidth cost is every track's bitrate combined on the wire — acceptable for stream-copy paths where audio is a fraction of video. |
| Re-encode paths | **Single-track in v1.** When audio is being re-encoded (tonemap on, DTS/TrueHD source, audio-fallback fired), only the source's `0:a:0?` is mapped to the re-encoded output. Multi-track + re-encode = v1.1 concern. |
| Track metadata exposure | **`audio_tracks: list[...]` on `StreamStartResponse`**. Probed once at scan time, cached on `media_files`. Mobile renders this in the Audio sheet. |
| Persistence | **New JSON column `audio_tracks` on `media_files` (migration 035).** Avoids re-probing on every `/start` (currently ~50-100 ms per call — separate plan 21 sharp-edge follow-up). |
| Subtitles | **Out of scope.** Plan 21's "out of scope" carry-forward. Subtitles + multi-audio share UX surface but are decoupled feature-wise. |

## Behavior matrix

| Source audio | Streaming mode | Audio path | Tracks exposed to mobile |
|---|---|---|---|
| Single AAC track | client-decode | Stream-copy | 1 track (Track 0) |
| Dual AAC tracks (NVIDIA Game Bar) | client-decode | Stream-copy both | 2 tracks (Track 0 + Track 1 in picker) |
| Multi-language AAC (movie rip) | client-decode | Stream-copy all | N tracks with language labels |
| Single FLAC track | client-decode | Stream-copy via fmp4 | 1 track |
| Single DTS track | any | Re-encode to AAC | 1 track (re-encoded) — multi-track + re-encode is v1.1 |
| Tonemap ON, any audio | client-decode/auto | Re-encode to AAC | 1 track — re-encode path forces single-track |
| Auto-mode audio fallback fired | auto | Re-encode to AAC | 1 track — fallback path forces single-track |

## Migration

### 035 — `audio_tracks` JSON column on `media_files`

```sql
ALTER TABLE media_files ADD COLUMN audio_tracks TEXT;
-- JSON array, populated at scan time by `library_service.scan`.
-- Schema: [{"index": int, "codec": str, "language": str | null,
--          "title": str | null, "channels": int, "sample_rate": int,
--          "bit_rate": int | null}, ...]
-- NULL for legacy rows; lazily backfilled on next /stream/start probe.
```

Why JSON over a separate `media_audio_tracks` table:
- Read pattern is "fetch all tracks for one file in one query" — JSON column = one row read; relational table = N+1 or join
- Cardinality is bounded (typical files have 1-5 audio tracks; max we'd ever see is ~10)
- No need to query across files by track property (e.g. "all files with a German track")

If those query needs surface later we can normalise into a `media_audio_tracks` table in a future migration.

## Server changes

### `services/ffmpeg_service.py`

- **Remove the bandaid `-map 0:v:0 -map 0:a:0?` pin** when audio is stream-copy. Replace with `-map 0:v:0 -map 0:a?` (all audio tracks, optional). Trailing `?` preserves silent-video graceful handling.
- **Keep the single-track pin when audio is re-encode** — re-encode paths still use `-map 0:v:0 -map 0:a:0?` because re-encoding N tracks would require N separate `-c:a` flag groups, and the use case (DTS / tonemap / fallback) is single-track in v1.
- New helper `_probe_audio_tracks(file_path) -> list[dict]` — returns every audio stream's metadata (index, codec, language, title, channels, sample_rate, bit_rate). Extends the existing `_probe_audio_params` which only returns track 0's info.
- Persist the probed track list to `media_files.audio_tracks` (JSON) the first time `/start` runs against a file, so subsequent calls read from DB.

### `services/ffmpeg_service.py` — `_ensure_fmp4_init_segment`

- Change `-map 0:a:0?` to `-map 0:a?` so the init segment declares every audio track in its moov. Each track's `tkhd` + `mdia` boxes describe codec, sample rate, channel layout — media_kit can then expose each track via `Player.state.tracks.audio`.
- Keep the `-c:a aac -b:a 128k` re-encode in this helper (init segment is tiny, only used as a moov template; segments still carry source AAC stream-copy).

### `routers/stream.py`

- **`StreamStartResponse` gains `audio_tracks: list[AudioTrackInfo]`** — populated from `media_files.audio_tracks` (or fresh probe on miss). Each entry: `index`, `codec`, `language`, `title`, `channels`, `sample_rate`, `bit_rate`.
- Backfill path: if `media_files.audio_tracks IS NULL`, call `_probe_audio_tracks` once and write back. Defensive — never blocks playback; on probe failure the response field is `[]` and mobile renders "Audio tracks unavailable".

### `models/stream_session.py`

- New `AudioTrackInfo(BaseModel)` with fields above.
- `StreamStartResponse.audio_tracks: list[AudioTrackInfo] = []` (default for backward compat; old mobile clients still parse).

### `services/library_service.py`

- Scan path probes audio tracks alongside the existing video metadata probe. Writes JSON to `media_files.audio_tracks` at scan completion. Library re-scan refreshes; no manual backfill needed.

## Mobile changes

### `apps/mobile/lib/features/player/domain/entities/stream_start_response.dart`

- Add `audioTracks: List<AudioTrackInfo>`. New `AudioTrackInfo` entity (index, codec, language, title, channels).
- Default `[]` for compat with pre-plan-22 servers.

### `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`

- New cubit state field: `availableAudioTracks: List<AudioTrackInfo>` + `selectedAudioTrackIndex: int` (default 0).
- New cubit method `selectAudioTrack(int index)`:
  - Calls `_player.setAudioTrack(_player.state.tracks.audio[index])` — pure client-side switch via media_kit.
  - Persists the choice for the current session only (next playback defaults back to track 0).
  - No server roundtrip.

### `apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart`

- The existing **Audio sheet** (plan 21 quick-action target) becomes a real picker. Renders the `availableAudioTracks` list as a `FluxBottomSheet` with one row per track:
  - `Language · Channels · Codec` (e.g. "English · 5.1 · ac3", "Japanese · 2.0 · aac", "Commentary · 2.0 · aac")
  - Checkmark on the selected row
  - Tap → `cubit.selectAudioTrack(index)`
- When `availableAudioTracks.length <= 1`, the Audio action in `PlayerQuickActions` is greyed out with a tooltip "Only one audio track in this file".

## Desktop changes

None. Desktop has no player feature (plan 21 §17.3 #4 gotcha). The audio track JSON is still persisted at scan time from the server, so when/if a desktop player ships it inherits the metadata.

## Tests

### Server (~6 new tests)

- `test_probe_audio_tracks_single_track` — file with one AAC track returns `[{index:0, codec:"aac", ...}]`.
- `test_probe_audio_tracks_dual_track` — NVIDIA-style file with two AAC tracks returns both with correct indices.
- `test_probe_audio_tracks_with_language_tags` — file with `tags.language = "eng"` / `"jpn"` returns those.
- `test_build_ffmpeg_cmd_maps_all_audio_tracks_under_stream_copy` — `-map 0:a?` (no index) when `audio_passthrough=True`.
- `test_build_ffmpeg_cmd_pins_single_audio_track_under_reencode` — `-map 0:a:0?` (with index) when audio is being re-encoded.
- `test_start_stream_response_includes_audio_tracks` — response payload has the new list.

### Mobile (~3 new tests)

- `player_cubit_test.dart`: `selectAudioTrack updates state and calls Player.setAudioTrack` with the right track.
- `player_cubit_test.dart`: `availableAudioTracks is populated from StreamStartResponse.audioTracks`.
- Entity: `StreamStartResponse.fromJson parses audio_tracks` (incl. empty default).

### `_ensure_fmp4_init_segment`

- `test_ensure_fmp4_init_segment_declares_all_audio_tracks` — generate the helper's output against a multi-track fixture; ffprobe the resulting init.mp4; assert track count matches source.

## Milestones

| M | Title | Est. | Files |
|---|---|---|---|
| **M1** | Server `-map` relaxation + `_ensure_fmp4_init_segment` fix + `_probe_audio_tracks` helper | 2 h | `services/ffmpeg_service.py`, `tests/test_stream.py` |
| **M2** | Migration 035 + persist `audio_tracks` JSON on scan | 2 h | `database/migrations/035_media_files_audio_tracks.sql`, `services/library_service.py`, `tests/test_library_service.py` |
| **M3** | `/stream/start` response field + `AudioTrackInfo` model + server tests | 1.5 h | `routers/stream.py`, `models/stream_session.py`, `tests/test_stream.py` |
| **M4** | Mobile entity + cubit state + Audio sheet picker UI + media_kit track switch | 3 h | `apps/mobile/lib/features/player/domain/entities/stream_start_response.dart`, `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`, `apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart`, mobile tests |
| **M5** | Tests sweep + doc-update-protocol sweep + AGENT_LOG entry | 1.5 h | All docs touched (api_contracts, backend_architecture, frontend_architecture, database_schema, migration_guide, current_status, gotchas, roadmap), AGENT_LOG entry |

**Total: ~10 h** — same shape as plan 21, two more files than plan 20.

## Files touched

```
apps/server/database/migrations/035_media_files_audio_tracks.sql       (new)
apps/server/models/stream_session.py                                   (AudioTrackInfo + StreamStartResponse.audio_tracks)
apps/server/services/ffmpeg_service.py                                 (-map relaxation + _ensure_fmp4_init_segment fix + _probe_audio_tracks helper)
apps/server/services/library_service.py                                (persist audio_tracks on scan)
apps/server/routers/stream.py                                          (response field + backfill probe)
apps/server/tests/test_stream.py                                       (M1 + M3 tests)
apps/server/tests/test_library_service.py                              (M2 scan-persistence test)
apps/mobile/lib/features/player/domain/entities/stream_start_response.dart  (audioTracks field + AudioTrackInfo)
apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart        (selectAudioTrack + availableAudioTracks state)
apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart  (Audio sheet picker)
apps/mobile/test/features/player/player_cubit_test.dart               (M4 tests)
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

1. **media_kit track-switching latency** — `Player.setAudioTrack` swaps the decoded track on libmpv's audio thread. On Android (MediaCodec backend) the swap can produce a 200-500 ms gap. Acceptable UX for a picker tap; document it. Pre-buffering both tracks isn't an option (memory cost, OS audio routing isn't track-aware).
2. **NVIDIA Game Bar mic-track levels** — game + mic captures often have huge level mismatches (game at -6 dB, mic at -30 dB). The picker can't normalise; document that selecting the mic track may sound quiet. v1.1 could add a "boost mic track" gain control.
3. **Init segment regeneration cost** — `_ensure_fmp4_init_segment` re-runs FFmpeg with `-t 0.04` per session. Today that's one re-encode; multi-track means the init also has to re-encode every audio track to AAC for the moov. Re-encoding is still cheap (~50 ms wall time for a 40 ms slice) but worth measuring on a 5-track file.
4. **Track index stability across re-probes** — if the operator re-scans the library and FFmpeg's stream ordering changes (rare but possible on some MKV files), the saved `selectedAudioTrackIndex` from a prior session points at a different track. v1 accepts this — playback defaults back to 0 per session. v1.1 could persist by `(language, codec, channels)` tuple instead of index.
5. **DTS / TrueHD multi-track files** — DTS isn't in the stream-copy allowlist (plan 21). When DTS is one of N tracks, FFmpeg can't `-c:a copy` all of them under fmp4 (HLS spec rejects DTS in fmp4). M1 must check the probe results and force re-encode when any track is non-allowlist. In that case only track 0 is emitted (re-encoded to AAC) and the Audio sheet shows one entry.
6. **Audio track count > 8** — fmp4 boxes have no formal limit but some player implementations cap at 8. Cap server-side at 8 and log a warning when source has more; the rest are dropped. Document in gotchas.
7. **Backward compatibility** — old mobile clients without the `audioTracks` field handling still parse the response (default `[]`); they just don't render the picker. Pre-plan-22 servers don't return the field; mobile defaults to `[]` and greys out the Audio action.
8. **Auto-fallback interaction** — plan 20's audio fallback fires on first-6s-decode-error under `streaming_mode='auto'`. With multi-track stream-copy, a decode error on track 0 doesn't necessarily mean track 1 also fails (different codecs / sample rates). v1 fires the fallback on any audio error regardless of selected track — fallback path re-encodes to single-track AAC. v1.1 could try the next track before re-encoding.

## Out of scope / future work

Deliberately not in plan 22; surface as separate plans if needed:

- **Audio language preference setting** — profile-level "I want English by default". Real ask if multi-language families share a device; trivial to add once the picker exists.
- **Subtitle track support** — distinct feature from audio tracks, distinct UX. Plan §subtitles when v1 ships caption rendering.
- **Multi-track + re-encode** — re-encoding N tracks to N AAC outputs in one FFmpeg run. Possible but doubles complexity in the cmd builder; deferred until a real ask.
- **Audio-level normalisation** — game/mic mix balance, dialog boost. Belongs in playback prefs UI, not this plan.
- **Per-track bitrate display** — currently exposed in the response but not rendered in the picker (clutters the row). Could show on long-press if anyone asks.
- **Server-side track muxing for export** — "save this file with the commentary track muted" — out of scope; Fluxora doesn't do export.

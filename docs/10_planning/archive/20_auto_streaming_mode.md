# Plan 20 — Auto streaming mode (third toggle + opt-in client-error fallback)

> **Status:** ✅ shipped — 2026-05-12
> **Supersedes nothing.** Layers on top of plan 19 §M7/§M8.

## Context

Plan 19 §M7 introduced a two-value `streaming_mode` setting:

- **`client-decode`** (default) — server stream-copies AV1/VP9/HEVC/H.264 via fmp4; client hardware-decodes.
- **`server-transcode`** (legacy) — server live-transcodes AV1/VP9 to H.264.

Real-world report (2026-05-12): operator on `client-decode` still saw server GPU/CPU climb during playback. Root cause was either (a) a source codec outside the stream-copy whitelist (mpeg4 / prores / mjpeg / wmv → forced transcode) or (b) HDR + tonemap enabled (forces transcode). Both are correct behavior — but invisible to the operator, and there was no way to say *"prefer client-decode, but transparently fall back if the client actually can't play the stream-copied stream."*

This plan adds a third opt-in mode — **`auto`** — that does the transparent fallback. `client-decode` keeps the Recommended badge and stays the default; `auto` is for operators with mixed device pools who want the server to learn each device's capabilities on first failure.

## Behavior matrix

| Mode | Default | First attempt | On client decode error |
|------|---------|---------------|------------------------|
| `client-decode` | ✅ **Recommended** | Stream-copy when source codec ∈ {h264, hevc, av1, vp9}; transcode otherwise (no choice) | Player error surfaces to the user. No fallback. Operator picked strict mode deliberately. |
| `auto` | opt-in | Stream-copy (same as `client-decode`) | Within first 6 s of `PlayerReady`, server restarts the session in transcode mode; flag stays set for the session's lifetime + a `(client, source_codec)` blocklist row is written so the next session for this client + codec starts directly in transcode |
| `server-transcode` | opt-in (legacy) | Transcode AV1/VP9; stream-copy H.264/HEVC | N/A — already transcoded |

Per-library codec passthrough overrides (plan 19 §M8) keep working exactly as before. Per-client cached fallback decisions are consulted **only under `auto`** — in strict modes the operator's pick wins.

## Migration

### 032 — extend `streaming_mode` CHECK to include `auto`

(Numbering: 031 was already taken by `031_sidecar_source_mtime.sql` on `main`; migrations are append-only.)

```sql
ALTER TABLE user_settings ADD COLUMN streaming_mode_new TEXT NOT NULL
    DEFAULT 'client-decode'
    CHECK(streaming_mode_new IN ('auto', 'client-decode', 'server-transcode'));
UPDATE user_settings SET streaming_mode_new = streaming_mode;
ALTER TABLE user_settings DROP COLUMN streaming_mode;
ALTER TABLE user_settings RENAME COLUMN streaming_mode_new TO streaming_mode;
```

Default stays `client-decode`. Existing rows keep their saved value. Migration is the minimal change needed to widen the CHECK constraint.

### 033 — `client_codec_blocklist` table

```sql
CREATE TABLE client_codec_blocklist (
    client_id TEXT NOT NULL,
    source_codec TEXT NOT NULL,
    reason TEXT,            -- 'player_error_within_6s' / future extensions
    created_at TEXT NOT NULL,
    PRIMARY KEY (client_id, source_codec),
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);
```

Look up at `/start` time **only when `streaming_mode='auto'`**. Strict `client-decode` and legacy `server-transcode` ignore the blocklist — the operator's pick wins. When a hit is recorded under `auto`, that session goes straight to transcode without the optimistic stream-copy probe.

## Server changes

### `models/settings.py`
- `streaming_mode: Literal["auto", "client-decode", "server-transcode"] = "auto"` (both `UserSettingsResponse` and `UpdateSettingsBody`).

### `services/settings_service.py`
- `_defaults()` returns `"streaming_mode": "auto"`.

### `services/ffmpeg_service.py`
- New module-level `_session_force_transcode: dict[str, bool]` — keyed by `session_id`; set to True after a fallback.
- `_resolve_codec_passthrough` now takes an optional `session_force_transcode: bool` arg. When True, returns False unconditionally (transcode wins).
- `start_stream` reads the flag at the top:
  ```python
  force_transcode = _session_force_transcode.get(session_id, False)
  ```
  Passes it through to `_resolve_codec_passthrough`, AND overrides the H.264/HEVC stream-copy gates so the fallback session is fully transcoded (the case the user reported was AV1 + audio-decoder-not-found, but the same path covers HEVC-with-10-bit-fail on under-spec clients).
- `stop_stream` clears the flag.
- New `set_session_force_transcode(session_id: str, value: bool = True)` helper exposed for the router.

### `services/client_codec_service.py` (new)
- `is_blocked(db, client_id, source_codec) -> bool`
- `add_block(db, client_id, source_codec, reason)`

### `routers/stream.py`
- `/start` consults `client_codec_service.is_blocked` **only when `streaming_mode='auto'`**. When blocked → `set_session_force_transcode(session_id, True)` before `ffmpeg_service.start_stream`.
- `/start` response (`StreamStartResponse`) now includes `streaming_mode` so the client knows whether to arm its auto-fallback watcher.
- New `POST /api/v1/stream/{session_id}/fallback-transcode` endpoint:
  - 404 if session not found / ended.
  - 403 if session isn't owned by caller.
  - **409 if `streaming_mode` is not `'auto'`** — strict modes surface errors to the user rather than silently switching pipelines.
  - Records `(client_id, source_codec)` in `client_codec_blocklist` (idempotent — INSERT OR IGNORE).
  - Sets `_session_force_transcode[session_id] = True`.
  - Calls `restart_stream` from the live playhead position (caller supplies `current_position_sec` in the body so server doesn't have to guess).
  - Returns 200 with the unchanged playlist URL.

### Diagnostic
- One INFO line at session start:
  ```
  stream_decision session=<id> source_codec=<codec> mode=<auto|client-decode|server-transcode> path=<stream-copy|transcode> reason=<global|library-override|client-blocklist|forced-fallback>
  ```
  So when the operator next sees GPU climb, one grep tells them why.

## Mobile + desktop player

### Mobile (`apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart`)
- **Only when `response.streamingMode == 'auto'`**: subscribe to `_player!.stream.error` for the first 6 seconds after `PlayerReady`. Other modes skip the watcher entirely so a player error bubbles up unchanged.
- On any error within the window, call new `PlayerRepository.reportFallbackTranscode(sessionId, currentPositionSec)`.
- On success of that POST, call `_player!.open(Media(streamPath))` to reload the playlist — segments are now transcoded.
- Cancel the 6-second watcher on first successful frame (libmpv's `videoParams` first non-empty value).

### Desktop player (same pattern)
- Player feature exists at `apps/desktop/lib/features/player/`; mirror the cubit change.

### Repositories
- Add `reportFallbackTranscode` to `PlayerRepository` (mobile + desktop) → `_apiClient.post('/api/v1/stream/$sessionId/fallback-transcode', body: {'current_position_sec': pos})`.

## Desktop UI

### `apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart`
- 3-option `_StreamingModeCard`:
  1. **Client decodes** — *Recommended.* Body unchanged from plan 19; subtitle `'Recommended'`.
  2. **Auto** — Body: "Tries client decoding first for near-zero server load. If a device cannot play the original codec, the server transparently falls back to transcoding for that session." Subtitle `'Mixed device pools'`.
  3. **Server transcodes** — body unchanged; subtitle `'Legacy / every device'`.

### `settings_cubit.dart` / `settings_state.dart`
- Default `streamingMode` stays `'client-decode'` (matches the Recommended badge).

## Tests

### Server
- `test_settings.py` — extend default-value asserts to `'auto'`; extend `Literal` accept-list.
- `test_stream.py`:
  - `test_codec_passthrough_session_force_transcode_overrides_all` — set `_session_force_transcode[sid] = True`; resolver returns False even when global=client-decode + library override=1.
  - `test_fallback_transcode_endpoint_records_blocklist_and_restarts` — POST `/fallback-transcode`, assert `client_codec_blocklist` row appears + ffmpeg restart_stream called with `_session_force_transcode` set.
  - `test_start_stream_consults_codec_blocklist` — pre-seed blocklist row; assert `_session_force_transcode[sid] = True` after start.
- `test_client_codec_service.py` (new) — `is_blocked` / `add_block` round-trip.

### Desktop
- Settings cubit default test (if one exists) flips to `'auto'`.

## Files touched

```
apps/server/database/migrations/032_streaming_mode_auto.sql            (new)
apps/server/database/migrations/033_client_codec_blocklist.sql         (new)
apps/server/models/settings.py
apps/server/services/settings_service.py
apps/server/services/ffmpeg_service.py
apps/server/services/client_codec_service.py                           (new)
apps/server/routers/stream.py
apps/server/models/stream_session.py                                   (new response/body)
apps/server/tests/test_settings.py
apps/server/tests/test_stream.py
apps/server/tests/test_client_codec_service.py                         (new)
apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart
apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart
apps/mobile/lib/features/player/domain/repositories/player_repository.dart
apps/mobile/lib/features/player/data/repositories/player_repository_impl.dart
apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart
apps/desktop/lib/features/player/...                                   (mirror mobile)
docs/00_overview/current_status.md
docs/03_data/02_database_schema.md
docs/04_api/01_api_contracts.md
docs/08_frontend/01_frontend_architecture.md
docs/09_backend/01_backend_architecture.md
docs/12_guidelines/03_gotchas.md                                       (auto-mode diagnostic line)
docs/10_planning/01_roadmap.md
```

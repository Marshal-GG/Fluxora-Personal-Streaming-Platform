# Plan 24 — Android ExoPlayer Migration

> **Status:** Active — operator approved 2026-05-15 after stacking
> three layers of mid-stream track-switch workarounds (plan 22 cubit-
> level seek, wakelock fix, plan 23 server-restart) failed to produce
> reliable multi-audio playback on a real device.
>
> **Decision:** Stop fighting libmpv-on-Android.  Replace the Android
> playback engine with the same Media3 ExoPlayer that Plex, Jellyfin,
> Netflix, YouTube and every modern Android HLS player uses under the
> hood.  Keep `media_kit` (libmpv) on desktop where it works fine, and
> on iOS where AVPlayer is the underlying engine and we have no
> reported issues.

---

## Symptoms this plan removes

Consolidated from operator logs 2026-05-14 → 2026-05-15:

1. **Multi-audio AC3 5.1 file — pause/resume kills audio.**
   Mitigated by the wakelock fix (player_screen.dart `Video(wakelock:
   false)` + screen-lifetime `WakelockPlus.enable()`).  ExoPlayer will
   make this fix redundant but harmless.
2. **Multi-audio AC3 5.1 file — switching audio mid-playback hangs the
   player.**  Persists across every workaround we tried (bare
   setAudioTrack, pause+swap+seek+play, self-seek, 1-s-back seek,
   `ao=audiotrack`, server-restart with track pinned + init.mp4
   regenerated).  Root cause: libmpv's HLS demuxer on Android cannot
   recover when the fmp4 init segment vs. segments contract changes
   mid-session, and switching tracks in libmpv-on-HLS requires a
   demuxer reset that the bundled Android build doesn't ship cleanly.
3. **HDR multi-audio file — audio silent from session start.**
   Possibly a separate bug (server-side init.mp4 codec for HDR
   sources) but ExoPlayer's HLS parser is strict-but-recoverable and
   would surface the actual error rather than silently dropping audio.

---

## Why ExoPlayer (Media3)

| Need | Media3 ExoPlayer | libmpv-on-Android (media_kit) |
|------|------------------|-------------------------------|
| HLS spec compliance | First-party Google implementation | Imported via media_kit_libs_video_android |
| Multi-audio HLS mid-stream switch | `TrackSelectionParameters` — one API call, no restart | Broken in our build |
| fmp4 init handling | Strict + diagnostic errors | Silent stall on mismatch |
| HDR (HDR10, HLG, Dolby Vision) | Native pipeline integration | Works but tonemap requires CPU path |
| Subtitle rendering | Built-in CEA-608/708 + WebVTT | Works |
| Audio focus + AudioManager | First-party | OpenSL ES path is brittle on Oplus |
| Bug reports + fixes | Google, monthly releases | Effectively volunteer-maintained |
| Use in production | Plex, Jellyfin, Netflix, YouTube, Spotify, every Google video app | A handful of Flutter desktop tools |

Media3 is the **right tool**, not an exotic third-party choice.  It is
what the AOSP recommends for HLS playback today (the legacy ExoPlayer
2.x line is in maintenance; Media3 is the active development).

---

## Decisions

### D1 — Per-platform playback strategy

| Platform | Engine | Reason |
|----------|--------|--------|
| Android | **Media3 ExoPlayer** (new) | Fixes every reported audio bug |
| iOS | media_kit_video (unchanged) | No bug reports against iOS path; AVPlayer underneath is solid |
| Windows / macOS / Linux desktop | media_kit (unchanged) | libmpv on desktop is the right tool; desktop is the platform media_kit was built for |

iOS migration is **out of scope for plan 24**.  If operator-side bugs
emerge against iOS, a follow-up plan can either reuse Media3-style
AVPlayer or migrate everything to a unified abstraction.

### D2 — Abstraction layer

Introduce a `PlayerEngine` interface (Dart, in `packages/fluxora_core`)
so the rest of the player code doesn't depend on whether the engine is
libmpv or ExoPlayer.  Two implementations:

- `MediaKitEngine` — wraps the current `media_kit` calls.  Used by
  desktop + iOS.
- `ExoPlayerEngine` — talks to a new Android platform channel.  Used
  by Android.

A platform-aware factory at `_player = await PlayerEngine.create()`
picks the right implementation.  Cubit + controls + sheets see only
the interface.

### D3 — Native bridge approach for ExoPlayer

Two options, ordered by my recommendation:

**Option A: Hand-rolled platform channel (RECOMMENDED)**.  Write a
small Kotlin module under `apps/mobile/android/` that:

- Owns one `androidx.media3.exoplayer.ExoPlayer` instance per Flutter
  player.
- Renders frames into a `Surface` produced by Flutter's
  `TextureRegistry.SurfaceProducer` (the same path
  `media_kit_video_android` uses).
- Exposes a `MethodChannel` Dart→Kotlin with a small command set
  (`open`, `play`, `pause`, `seek`, `setAudioTrack`, `setRate`,
  `setVolume`, `dispose`).
- Exposes an `EventChannel` Kotlin→Dart for position / duration /
  state / track-list emissions.

Pros: zero third-party dependency in the playback critical path, full
control over the Media3 API surface (so we can use newer ExoPlayer
APIs without waiting on plugin updates), Kotlin code is small (~400
lines) and self-contained.

Cons: ~3 days of native Android engineering up front.

**Option B: `flutter_video_player_native` or `better_player_plus` or
similar community wrappers**.  Faster to integrate but reintroduces
the third-party-package risk we just escaped — the older `better_player`
went unmaintained in 2022 and that's exactly the trap we'd be re-
entering.

Operator preference (from chat 2026-05-15): "use 3rd party if needed".
We *can* use a wrapper, but Option A is what every serious Flutter
video product ships and the Kotlin scope is small enough that it pays
off in week one.

**Provisional choice: Option A.**  M1 produces a 1-h spike to validate
the platform-channel + SurfaceProducer plumbing; if M1 hits a wall
we'll re-evaluate Option B before committing the rest of the milestones.

---

## Architecture changes

### Before (today)

```
PlayerCubit ──▶ media_kit Player + VideoController
                 (libmpv on every platform)
```

### After (this plan)

```
PlayerCubit ──▶ PlayerEngine (abstract)
                 │
                 ├── MediaKitEngine ──▶ media_kit Player (desktop, iOS)
                 │
                 └── ExoPlayerEngine ──▶ MethodChannel ──▶ ExoPlayer (Android)
                                          + EventChannel  + SurfaceProducer
```

### `PlayerEngine` interface (Dart side)

Lives at `packages/fluxora_core/lib/player/player_engine.dart`.  Mirrors
the subset of `media_kit.Player` the cubit currently uses; everything
the rest of the app doesn't touch stays out of the interface.

```dart
abstract class PlayerEngine {
  Future<void> open(String url, {Map<String, String>? headers, bool play = true});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setAudioTrack(int trackIndex);  // source-stream index
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume0to100);
  Future<void> dispose();

  // State (read-only snapshots) + streams.
  Duration get position;
  Duration get duration;
  bool get isPlaying;
  int? get selectedAudioTrackIndex;
  List<int> get availableAudioTrackIndices;
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<bool> get isPlayingStream;
  Stream<int?> get selectedAudioTrackStream;
  Stream<EngineError> get errorStream;

  // Texture id for embedding in a Flutter widget — both engines
  // expose this; the wrapping Video widget reads it.
  int? get textureId;
}
```

### Factory

```dart
class PlayerEngineFactory {
  static Future<PlayerEngine> create() async {
    if (Platform.isAndroid) return ExoPlayerEngine.create();
    return MediaKitEngine.create();
  }
}
```

Feature-flagged via `_kForceMediaKitOnAndroid = false` const so the
operator can re-enable libmpv-on-Android if ExoPlayer somehow
regresses worse during migration.  Flag deletes in M9.

---

## Behavior matrix

Same as today's player; nothing changes from the operator's
perspective except things start working.

| Scenario | Before plan 24 | After plan 24 |
|----------|----------------|---------------|
| Single-audio movie (AAC) | works | works (ExoPlayer native HLS) |
| Multi-audio AC3 5.1 — play | works | works |
| Multi-audio AC3 5.1 — pause/resume | flaky (wakelock fix mitigates) | works (no surface dance to begin with) |
| Multi-audio AC3 5.1 — switch track mid-play | **hangs** | works (ExoPlayer TrackSelectionParameters) |
| HDR HEVC source | works (with tonemap if requested) | works (Media3 has HDR pipeline) |
| HDR multi-audio | **audio silent** | works (Media3 HLS parser handles fmp4 init correctly) |
| HDR → SDR tonemap toggle | works (server restart) | works (server restart still) |
| Server-side seek (forward, large delta) | works (open new playlist) | works (Engine.open) |
| Bitrate adaptation | N/A (single rendition) | N/A (we still emit single rendition for now) |
| Subtitles | works | works (ExoPlayer SubtitleView) |
| Background playback / lockscreen | works | works (audio_service + MediaSession) |
| PIP (Android) | works | works |

---

## Server side

**No changes.**  The server still emits the same HLS playlist + fmp4
init + segments.  Plan 22's multi-audio support (the server-side
multiplexing of all audio tracks into segments) stays.  Plan 23's
`/audio-track` endpoint becomes **optional** — ExoPlayer doesn't need
it because client-side track switching works.  We keep the endpoint in
place as a fallback for clients that can't do client-side switching
(future TV / web clients running libmpv) but the mobile cubit no
longer calls it.

---

## Milestones

Estimated time assumes one developer focused; total ~5 days.

### M1 — Platform channel spike (4 h)

**Goal:** prove the plumbing works end-to-end against the simplest
possible playlist before investing in the abstraction.

Steps:
1. Add Media3 deps to `apps/mobile/android/build.gradle`:
   `androidx.media3:media3-exoplayer-hls`,
   `androidx.media3:media3-exoplayer`,
   `androidx.media3:media3-ui` (latest stable).
2. Create `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/ExoPlayerPlugin.kt`:
   - Registers a `MethodChannel` on
     `dev.marshalx.fluxora/exo_player`.
   - Implements `open(url)` + `play()` only.
   - Renders to a `SurfaceProducer.getSurface()`.
   - Logs events.
3. Dart side: throwaway widget that calls the channel and embeds a
   `Texture(textureId)` in a `SizedBox`.
4. Play one of our HLS playlists.  Must see video + hear audio.

Exit criteria: a 30-second video plays in a Flutter widget driven by
Media3.  No abstraction, no cubit integration yet — just the plumbing.

### M2 — `PlayerEngine` abstraction (4 h)

**Goal:** carve out the interface without changing behaviour.

Steps:
1. Add `packages/fluxora_core/lib/player/player_engine.dart` with the
   interface from the Architecture section.
2. Add `packages/fluxora_core/lib/player/engine_error.dart` enum (auth,
   network, decode, format-unsupported, generic — drives the existing
   cubit failure-reason mapping).
3. Implement `MediaKitEngine` by **wrapping the current code**.  Don't
   rewrite — just move existing `media_kit` calls into the engine's
   method bodies and have them re-export the relevant streams.
4. Refactor `PlayerCubit` to hold a `PlayerEngine` instead of a raw
   `Player`.  `_player.open(...)` becomes `_engine.open(...)`, etc.
5. The Video widget in `player_screen.dart` reads `_engine.textureId`
   and renders a `Texture` widget directly (instead of `Video(
   controller: vc)`).  For `MediaKitEngine` the texture id is the one
   `VideoController` already exposes.

Exit criteria: cubit + UI + tests all unchanged in *behaviour*; the
underlying engine call path is now via the interface.  Run the full
mobile test suite — 30/30 must pass.

### M3 — `ExoPlayerEngine` Dart side (6 h)

**Goal:** complete client of the Android platform channel.

Steps:
1. Implement `ExoPlayerEngine` against the MethodChannel +
   EventChannel.  Every method translates to a channel call.
2. Map ExoPlayer's track API to source-stream indices.  ExoPlayer
   identifies audio renditions by a group/format pair; we need to
   match those back to the FFmpeg source-stream indices the rest of
   our code uses (the cubit's `availableAudioTracks` carries
   `AudioTrackInfo.index` which is FFmpeg's `0:a:<index>`).  Strategy:
   when M2 emits the track list to Dart it also includes the source
   index parsed from the rendition `NAME` or `LANGUAGE`+ordinal
   fallback.  Worst case the indices are positional within the audio
   group.
3. Wire EventChannel emissions to Dart `Stream`s.
4. Plumb `EngineError` mapping from ExoPlayer's `PlaybackException`
   (HTTP_DATA_SOURCE_INVALID_HTTP_CONTENT_TYPE, etc.) into our
   structured error enum.

Exit criteria: `ExoPlayerEngine` open/play/pause/seek/audio-track all
work against a real Fluxora session.

### M4 — `ExoPlayerEngine` Kotlin side (8 h)

**Goal:** stable, complete native module.

Steps:
1. Move M1's quick-and-dirty plugin into a proper module structure:
   - `ExoPlayerPlugin.kt` — plugin entry; manages a map of player ids
     to ExoPlayer instances (multiple Flutter players possible).
   - `FluxoraExoPlayer.kt` — wraps one ExoPlayer + its SurfaceProducer
     + its Player.Listener.
2. Implement the full command set:
   - `open(url, headers, play, startPositionMs)` — builds an
     `HlsMediaSource` with a `DefaultHttpDataSource.Factory` that
     injects the bearer token header.  Sets `prepare()` then
     `play()` or `pause()` based on `play`.
   - `play` / `pause` / `seek(positionMs)` — direct ExoPlayer calls.
   - `setAudioTrack(sourceIndex)` — builds a
     `TrackSelectionParameters` overriding the audio
     `TrackSelectionOverride` to point at the rendition whose source-
     index matches.
   - `setRate(rate)` — `setPlaybackParameters(PlaybackParameters(rate))`.
   - `setVolume(v0to1)` — `setVolume(v)` (note: ExoPlayer uses 0-1,
     our interface takes 0-100, MediaKitEngine already does that
     conversion).
3. Implement Player.Listener emitting:
   - `onPlaybackStateChanged` → ready / buffering / ended.
   - `onIsPlayingChanged` → isPlaying stream.
   - `onPositionDiscontinuity` → position stream emission.
   - `onTracksChanged` → trackList stream + selectedAudioTrack stream.
   - `onPlayerError` → errorStream with mapped EngineError.
   - Periodic ~250 ms ticker emitting position (matches the cubit's
     existing progress reporter cadence).
4. SurfaceProducer lifecycle:
   - Acquire on plugin attach, release on detach.
   - Handle Flutter view resizing via `SurfaceProducer.setSize`.
5. Audio focus — request via `AudioAttributes.Builder().build()` and
   `setHandleAudioBecomingNoisy(true)` (auto-pause on headphones
   unplug, what the user expects).
6. KEEP_SCREEN_ON — Media3 sets this automatically when playing; we
   keep the screen-lifetime `WakelockPlus.enable()` anyway as belt-
   and-braces.

Exit criteria: every PlayerEngine method behaves identically to
MediaKitEngine for a single-audio HLS playlist.

### M5 — Multi-audio track switching (3 h)

**Goal:** the bug that motivated this plan, fixed.

Steps:
1. Operator test: pick a 5.1 AC3 multi-audio file, play, swap track
   mid-playback.  Confirm:
   - No video freeze.
   - Audio swap happens within ~200 ms.
   - Position stays where it was; no seek required.
   - No 404 storm on segments.
2. Repeat for pause-then-switch-then-resume.  Confirm audio plays on
   resume with the new track.
3. Repeat 10×; no flakiness.

Exit criteria: cell "Multi-audio AC3 5.1 — switch track mid-play"
flips from red to green.

### M6 — HDR + tonemap (3 h)

**Goal:** keep HDR working; fix HDR-multi-audio audio dropout.

Steps:
1. Operator test: HDR source, single audio.  Verify HDR pipeline
   engages (Media3 has built-in HDR; on supported devices the surface
   gets HDR10 metadata automatically).
2. Operator test: HDR + multi-audio.  Verify audio is no longer
   silent.  If still silent, capture an ExoPlayer log via `adb
   logcat -s ExoPlayer` and inspect — Media3's parser logs the actual
   parsing error in a way libmpv didn't.
3. Tonemap toggle: the existing server-restart path (cubit calls
   `setTonemap(bool)` which re-invokes `/start` with the new flag)
   still works because the cubit re-opens the playlist via the
   engine interface — ExoPlayerEngine's `open` handles the new URL
   transparently.

Exit criteria: rows "HDR multi-audio" + "HDR HEVC source" flip green.

### M7 — Lifecycle, audio focus, PIP, background playback (3 h)

**Goal:** make sure existing UX integrations keep working.

Steps:
1. PIP (`pip_service.dart`) — ExoPlayer + Android PIP is the standard
   combination; verify the Activity's `PictureInPictureParams` still
   triggers correctly when the surface is owned by Media3.
2. `audio_service` integration — our `FluxoraAudioHandler` binds to
   `media_kit.Player`.  Either:
   a) Extend `PlayerEngine` with a `MediaSessionBridge` that
   audio_service can hook into platform-agnostically, OR
   b) Have ExoPlayerEngine register its own MediaSession in Kotlin
   (Media3 ships `MediaSessionService` for this — first-party).
   Recommend (b) — it's the AOSP way and removes a layer of Dart
   plumbing.
3. Lockscreen controls — verify play/pause/seek from the lockscreen
   round-trip to ExoPlayer.
4. App-backgrounded auto-pause behaviour — our `didChangeAppLifecycle
   State` handler in `_PlayerViewState` calls cubit-level pauses;
   confirm it still fires correctly with the new engine.

Exit criteria: lockscreen + PIP + headphone-unplug + app-background
all behave the same as before.

### M8 — Position tracking + seek-restart integration (2 h)

**Goal:** scrubber, resume-progress reporter, server-restart seek all
continue to work.

Steps:
1. `PlayerCubit.seekTo` decides between in-player seek and server-
   restart based on the playlist's loaded source-time range.
   Confirm ExoPlayer's `getCurrentPosition` reports source-time after
   the cubit re-opens with a new `playlistOffsetSec`.
2. Verify the scrubber pinning logic in `PlayerProgressBar` still
   works — it depends on `widget.player.stream.position` (we re-route
   via the engine interface, so the stream contract is preserved).
3. Progress-reporting timer (`_startProgressTimer` in cubit) ticks
   correctly.

Exit criteria: scrubber + auto-resume + manual-seek all work.

### M9 — Tests, golden re-baseline, doc sweep (4 h)

Steps:
1. Update player tests to use a `FakePlayerEngine` mock instead of
   the existing `mocktail`'d media_kit Player.  Most tests will
   compile-error first, then be straightforward to fix.
2. Golden baselines unchanged — the UI doesn't care about engine.
3. Delete `_kForceMediaKitOnAndroid` flag if no rollback needed.
4. Doc sweep:
   - Update `docs/02_architecture/01_system_overview.md` mention of
     "media_kit on all platforms".
   - Update `docs/08_frontend/01_frontend_architecture.md` with the
     `PlayerEngine` abstraction.
   - Archive plan 22 if it's still in active state.
   - Mark plan 23 as superseded (the `/audio-track` endpoint stays in
     the codebase but is now unused by mobile).
   - Add a gotcha entry to `docs/12_guidelines/03_gotchas.md`:
     "Android playback uses Media3 ExoPlayer; desktop uses libmpv via
     media_kit; iOS uses media_kit_video (AVPlayer underneath)."

Exit criteria: full mobile test suite green; analyze clean; CI green
on main.

---

## Test plan

Real-device matrix that must be green to ship:

| File | Scenario | Status |
|------|----------|--------|
| Single-audio H.264 + AAC | play / pause / scrub / close | |
| Single-audio HEVC + AAC | play / pause / scrub / close | |
| Multi-audio HEVC + AAC stereo + Hindi AC3 5.1 | play / pause / resume / switch-track mid-play / switch-track while paused | |
| Multi-audio HDR HEVC | play / audio audible / switch-track | |
| HDR HEVC single-audio | play / tonemap toggle / close | |
| Resume from history | starts at correct position with correct audio | |
| Background → resume foreground | playback resumes cleanly | |
| Headphone unplug | auto-pause | |
| Long playback (>30 min) | no AudioTrack churn, no surface storms | |
| Slow LAN | rebuffer + recovery, no permanent stall | |

Automated coverage:

- All existing player_cubit tests pass against the new abstraction
  (~30 tests).
- New golden test capturing Video widget mounting with both engines
  (Texture id assertion).
- Kotlin unit test (JUnit) for the rendition→source-index mapping
  helper in `FluxoraExoPlayer.kt`.

---

## Sharp edges to watch for

1. **Headers on HlsMediaSource.**  ExoPlayer's default HTTP data
   source factory needs to be configured with the
   `Authorization: Bearer ...` header.  Easy to get wrong; will
   manifest as 401 on segment fetches.
2. **Audio track stream indices vs. ExoPlayer track types.**  Media3
   distinguishes audio renditions by `TrackGroup` membership.  Our
   server emits one HLS rendition with multiplexed audio streams —
   ExoPlayer parses the fmp4 init and exposes each audio stream as a
   `Format` within one audio `TrackGroup`.  Selecting by index inside
   the group is straightforward; we just need to thread the mapping
   from cubit (source-stream index) to ExoPlayer (group + format
   index).
3. **SurfaceProducer + size changes.**  Rotation, PIP entry/exit,
   keyboard show — all resize the Flutter view.  Test all of these.
4. **HDR pipeline + tonemap server flag.**  ExoPlayer auto-detects
   HDR.  The operator's tonemap toggle still hits the server (which
   does the actual tonemap work); ExoPlayer just receives an SDR
   stream when tonemap is on.  No HDR-pipeline change client-side.
5. **`audio_service` plugin compatibility.**  Today it binds to a
   `media_kit.Player`.  M7 either patches this binding or replaces
   it with Media3's `MediaSessionService`.  The latter is cleaner
   and removes the Dart-side plumbing entirely.
6. **`flutter_webrtc` audio focus.**  Plan 21 surfaced this — webrtc
   sometimes grabs audio focus.  Verify it doesn't interfere with
   ExoPlayer.  Easy fix if it does: configure
   `setHandleAudioBecomingNoisy(true)` and request focus aggressively
   on ExoPlayer side.
7. **Desktop tests still rely on `media_kit`.**  Keep the existing
   golden tests + cubit tests running against `MediaKitEngine` so we
   don't regress desktop while focusing on Android.
8. **The HDR-no-audio bug might also exist server-side.**  If M6
   uncovers a server-side init.mp4 codec issue, that's a separate
   server fix — but at least Media3 will tell us *what's wrong*
   instead of silently dropping audio.

---

## Files touched (provisional)

### New files

| File | Why |
|------|-----|
| `packages/fluxora_core/lib/player/player_engine.dart` | Interface |
| `packages/fluxora_core/lib/player/engine_error.dart` | Error mapping |
| `packages/fluxora_core/lib/player/media_kit_engine.dart` | Desktop+iOS impl |
| `packages/fluxora_core/lib/player/exo_player_engine.dart` | Android impl |
| `packages/fluxora_core/lib/player/player_engine_factory.dart` | Platform selection |
| `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/ExoPlayerPlugin.kt` | Plugin entry |
| `apps/mobile/android/app/src/main/kotlin/dev/marshalx/fluxora_mobile/exo/FluxoraExoPlayer.kt` | Per-player Kotlin class |
| `apps/mobile/android/app/src/test/kotlin/.../FluxoraExoPlayerTest.kt` | Rendition mapping unit test |

### Edited files

| File | Why |
|------|-----|
| `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` | `Player` → `PlayerEngine` |
| `apps/mobile/lib/features/player/presentation/screens/player_screen.dart` | `Video` widget → `Texture` |
| `apps/mobile/lib/features/player/presentation/widgets/flux_player_controls.dart` | `Player` references in widget params → `PlayerEngine` |
| `apps/mobile/lib/features/player/presentation/sheets/audio_subs_sheet.dart` | Track list source |
| `apps/mobile/lib/features/player/data/services/fluxora_audio_handler.dart` | Bind to engine instead of Player |
| `apps/mobile/test/features/player/player_cubit_test.dart` | Mock target |
| `apps/mobile/test/goldens/*.dart` | Player param types |
| `apps/mobile/android/app/build.gradle` | Media3 deps |
| `apps/mobile/pubspec.yaml` | Drop `media_kit` from android-only deps? (probably keep for desktop+iOS, no change) |
| `docs/02_architecture/01_system_overview.md` | Architecture note |
| `docs/08_frontend/01_frontend_architecture.md` | PlayerEngine doc |
| `docs/12_guidelines/03_gotchas.md` | Per-platform engine note |
| `docs/10_planning/01_roadmap.md` | Mark plan 24 active |
| `docs/10_planning/22_multi_audio_track_support.md` archive entry | Update with "ExoPlayer migration superseded the client-side switching workarounds" |

### Files NOT touched

- `apps/server/**` — zero server changes.
- iOS-specific files — out of scope for plan 24.
- Desktop client (`apps/desktop/**`) — uses media_kit, no change.

---

## Rollback plan

1. The `_kForceMediaKitOnAndroid` feature flag in the factory lets us
   instantly fall back to libmpv-on-Android if Media3 regresses
   something subtle.  Toggle, hot-restart, done.
2. If we need to fully revert mid-migration, the `PlayerEngine`
   abstraction (M2) is a no-op refactor that keeps everything on
   media_kit and can stand alone as a useful cleanup.
3. Plan 23's `/audio-track` endpoint stays in the codebase — if some
   future client can't do native track switching it has a server-side
   path.

---

## Time estimate

| Phase | Estimate |
|-------|----------|
| M1 — Platform channel spike | 4 h |
| M2 — PlayerEngine abstraction | 4 h |
| M3 — ExoPlayerEngine Dart side | 6 h |
| M4 — ExoPlayerEngine Kotlin side | 8 h |
| M5 — Multi-audio track switching | 3 h |
| M6 — HDR + tonemap | 3 h |
| M7 — Lifecycle / audio focus / PIP | 3 h |
| M8 — Position tracking / seek-restart | 2 h |
| M9 — Tests + doc sweep | 4 h |
| **Total** | **~37 h (≈5 working days)** |

Optimistic if the spike (M1) succeeds first try.  Add 8 h buffer for
the inevitable Kotlin/Surface lifecycle weirdness.

---

## Open questions (resolved 2026-05-15)

1. **Multi-rendition HLS — adopt the industry standard.** **Decision:**
   move the server to emit proper `#EXT-X-MEDIA TYPE=AUDIO` audio
   renditions instead of the current single-rendition with multiplexed
   audio streams. That's what Netflix / Plex / YouTube / every modern
   HLS player emits and what AVPlayer (iOS) expects for native track
   switching. **Scope:** not part of plan 24 itself — plan 24 lands
   ExoPlayer against the current single-rendition shape (it parses
   that correctly). Multi-rendition emission is **plan 25** so we
   don't compound the Android migration with a server-side HLS
   shape change in the same week. Mark plan 25 as the immediate
   follow-up.
2. **iOS migration — defer.** **Decision:** keep `media_kit_video`
   (AVPlayer underneath) on iOS for now. No reported iOS playback
   bugs; revisit if and when iOS-specific issues surface. A future
   plan can mirror this work via an AVPlayer platform channel — or
   plan 25's multi-rendition server output may give AVPlayer
   everything it needs without a native bridge.
3. **Subtitles — use ExoPlayer's built-in `SubtitleView`.**
   **Decision:** render subtitles Kotlin-side via Media3's
   `SubtitleView`. Shipping speed wins over the customisation we'd
   get from streaming cues to Dart. If a future design ask requires
   Flutter-rendered subtitles (custom styling, animation), revisit
   then.

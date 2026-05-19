# 10 — Player Engines

> Plan 24's `PlayerEngine` abstraction. Lets mobile use **ExoPlayer (Media3)** on Android and **media_kit (libmpv)** elsewhere from a single Dart cubit + UI.

---

## Class hierarchy

```mermaid
classDiagram
  class PlayerEngine {
    <<abstract>>
    +Stream~PlayerState~ stateStream
    +Stream~Duration~ positionStream
    +Stream~Duration~ durationStream
    +Stream~PlayerError~ errorStream
    +Stream~Size~ videoSizeStream
    +Size? videoSize
    +Future~void~ open(url, headers)
    +Future~void~ play()
    +Future~void~ pause()
    +Future~void~ seek(position)
    +Future~void~ setSpeed(rate)
    +Future~void~ selectAudioTrack(int index)
    +Future~void~ selectVideoQuality(int sourceIndex)
    +Future~void~ setMetadata(title)
    +Future~void~ dispose()
  }

  class ExoPlayerEngine {
    -MethodChannel _channel
    -EventChannel _events
    +open()
    +selectAudioTrack()
    +selectVideoQuality()
    -mapSourceIndex(int)~TrackGroup, formatIndex~
  }

  class MediaKitEngine {
    -Player _mpv
    -VideoController _controller
    +open()
    +selectAudioTrack()
  }

  class PlayerEngineFactory {
    <<factory>>
    +create() PlayerEngine
    -_kEnableExoPlayerEngine bool
    -_kForceMediaKitOnAndroid bool
  }

  PlayerEngine <|-- ExoPlayerEngine
  PlayerEngine <|-- MediaKitEngine
  PlayerEngineFactory ..> PlayerEngine : returns
```

All three live in `packages/fluxora_core/lib/player/`.

---

## Platform routing

```mermaid
flowchart TB
  classDef android fill:#16a34a,stroke:#000,color:#fff
  classDef desktop fill:#3b82f6,stroke:#000,color:#fff
  classDef ios fill:#a78bfa,stroke:#000,color:#fff
  classDef escape fill:#f59e0b,stroke:#000,color:#000

  Start([PlayerEngineFactory.create]) --> Q1{Platform.isAndroid?}
  Q1 -- yes --> Q2{_kForceMediaKitOnAndroid?<br/>(operator escape hatch)}
  Q2 -- no default --> Exo["ExoPlayerEngine<br/>Media3 1.10.1 + Tonemap"]:::android
  Q2 -- yes --> MK1[MediaKitEngine on Android]:::escape
  Q1 -- no --> Q3{Platform.isIOS?}
  Q3 -- yes --> MK2[MediaKitEngine via libmpv-ios]:::ios
  Q3 -- no --> MK3[MediaKitEngine on Win/macOS/Linux]:::desktop
```

The desktop control panel does **not** instantiate a player engine — it has no playback surface. The mobile app instantiates exactly one engine per `PlayerCubit` lifecycle.

---

## ExoPlayer engine — Kotlin side

```mermaid
graph TB
  classDef kotlin fill:#7c3aed,stroke:#fff,color:#fff
  classDef m3 fill:#a78bfa,stroke:#000,color:#000
  classDef chan fill:#fde68a,stroke:#000,color:#000

  Chan[MethodChannel<br/>dev.marshalx.fluxora/exo_player]:::chan
  Events[EventChannel<br/>events]:::chan

  Chan --> Plugin[ExoPlayerPlugin.kt]:::kotlin
  Events --> Plugin

  Plugin --> Build[Build ExoPlayer instance]:::kotlin
  Build --> RF[TonemappingRenderersFactory<br/>(extends DefaultRenderersFactory)]:::m3
  RF --> VR["MediaCodecVideoRenderer subclass<br/>KEY_COLOR_TRANSFER_REQUEST = SDR (API 33+)"]:::m3

  Plugin --> Bearer[Inject Authorization header<br/>via DefaultHttpDataSource.Factory<br/>(no token logged)]:::kotlin

  Plugin --> Listener[Player.Listener]:::m3
  Listener -- onTracksChanged --> Map[Source-index → TrackGroup + formatIndex]
  Listener -- onVideoSizeChanged --> Size[videoSize w/ PAR baked in]
  Listener -- onPlayerError --> Err[Forward to errorStream]

  Plugin --> MS[Media3 MediaSessionService<br/>lockscreen / notification / BT transport]:::m3
  Plugin --> AF[AudioFocus + BecomingNoisyReceiver<br/>auto-pause on headset pull]:::kotlin

  Plugin --> Ticker[250ms position ticker → events]:::kotlin
  Plugin --> NSC[network_security_config.xml<br/>cleartext for LAN<br/>HTTPS-only for prod domain]:::kotlin
```

---

## Engine capability matrix

| Capability | ExoPlayerEngine | MediaKitEngine |
|---|---|---|
| HDR → SDR tonemap (client) | Yes — `TonemappingRenderersFactory`, API 33+ | No (server `?tonemap=true` fallback) |
| Multi-audio in-client switch | Yes | Yes |
| Multi-video-quality in-client switch | Yes — `(TrackGroup, formatIndex)` map | Limited |
| Bearer header injection | Yes — `DefaultHttpDataSource.Factory` | Yes — `media_kit` httpHeaders |
| Lockscreen / Bluetooth transport | Yes — Media3 `MediaSessionService` | No |
| Audio focus / becoming-noisy | Yes | Manual |
| LAN cleartext | Yes — `network_security_config.xml` carve-out | Yes — libmpv ignores Android policy |
| Anamorphic PAR | Yes — baked into `videoSize` | Yes |
| Pinch zoom / fit-fill-stretch | Implemented in Flutter via raw `Listener` (both) | Same |

---

## Mobile player UI ↔ engine wiring

```mermaid
sequenceDiagram
  autonumber
  participant UI as flux_player_controls
  participant Ctl as player_controls_controller (ChangeNotifier)
  participant Cu as PlayerCubit
  participant E as PlayerEngine
  participant S as Server

  UI->>Ctl: user gesture (play/pause/seek/audio sheet)
  Ctl->>Cu: cubit method
  Cu->>S: REST call if needed (e.g. /stream/start)
  S-->>Cu: StreamStartResponse
  Cu->>E: open(playlist_url, bearer headers)
  E-->>Cu: stateStream + positionStream + errorStream
  Cu-->>Ctl: state updates
  Ctl-->>UI: rebuild (top bar, transport, progress, quick actions)

  UI->>Ctl: pick audio track
  Ctl->>Cu: selectAudioTrack(index)
  Cu->>E: selectAudioTrack(index)
  alt engine can switch
    E-->>Cu: switched
  else needs server respawn (plan 23)
    Cu->>S: POST /stream/{sid}/audio-track
    S-->>Cu: applied_seek_sec
    Cu->>E: open(new playlist)
  end
```

---

## Decision flags

```mermaid
graph LR
  classDef flag fill:#7c3aed,stroke:#fff,color:#fff
  classDef note fill:#6b7280,stroke:#000,color:#fff

  F1["_kEnableExoPlayerEngine<br/>(dropped post-rollout)"]:::flag
  F2["_kForceMediaKitOnAndroid<br/>(escape hatch, still kept)"]:::flag
  N1["Removed once M5 + M6 device-green"]:::note
  F1 --- N1
```

See [`docs/10_planning/24_player_audio_reliability_plan.md`](../../10_planning/24_player_audio_reliability_plan.md) for milestone status. M5 (multi-audio device smoke) + M6 (HDR + tonemap) require operator device testing; once they're green, `_kForceMediaKitOnAndroid` gets deleted and the plan archives.

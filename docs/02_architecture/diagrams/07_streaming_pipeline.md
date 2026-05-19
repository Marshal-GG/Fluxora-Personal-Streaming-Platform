# 07 — Streaming Pipeline

> What happens between *user taps Play* and *frames appear on screen*. Server-side spawning logic + client-side playback.

---

## Happy path — LAN stream-copy

```mermaid
sequenceDiagram
  autonumber
  actor U as User
  participant C as Mobile / Desktop client
  participant Cu as PlayerCubit
  participant S as Server /stream/start
  participant SR as session_router
  participant FC as ffmpeg_capabilities
  participant FS as ffmpeg_service
  participant FF as FFmpeg subprocess
  participant DB as SQLite

  U->>C: tap Play
  C->>Cu: open(media_file, resume_sec)
  Cu->>S: POST /stream/start/{file_id}?seek_sec=X
  S->>DB: read media_files + codec_name, hdr_format
  S->>DB: read groups → reason_to_deny_stream
  alt denied
    S-->>C: 403 PIN required / not visible
    C-->>U: PIN sheet or error
  end
  S->>FC: capability flags
  S->>SR: pick_encoder(transcoding_chain)
  alt source codec stream-copyable AND not in client blocklist
    S->>FS: build_args(mode=copy)
    FS->>FF: spawn -c:v copy -hls_time=10
  else needs transcode
    S->>FS: build_args(mode=transcode, encoder=picked, readrate=1.5)
    FS->>FF: spawn with cuvid hint + readrate gate
  else HDR + ?tonemap=true
    S->>FS: build_args(mode=transcode + zscale Hable)
    FS->>FF: spawn with HDR→SDR filter
  end
  FS-->>S: session_id + applied_seek_sec
  S->>DB: INSERT stream_sessions
  S-->>C: StreamStartResponse{playlist_url, applied_seek_sec, audio_tracks}
  C->>S: GET playlist.m3u8
  S-->>C: static VOD playlist (full duration)
  loop segment requests
    C->>S: GET segNNN.ts
    S-->>C: bytes
    C-->>U: video plays
  end
  C->>S: POST /stream/{sid}/progress (last_progress_sec)
  C->>S: DELETE /stream/{sid} on close
  S->>DB: UPDATE ended_at + bytes_transferred + progress_sec
```

---

## Decision tree — mode selection

```mermaid
flowchart TD
  Start([/stream/start request]) --> Probe{Have codec_name<br/>in media_files?}
  Probe -- no --> LazyProbe[Lazy ffprobe<br/>+ _persist_probe]
  LazyProbe --> Probe
  Probe -- yes --> ModeQ{streaming_mode<br/>setting}
  ModeQ -- server_transcode --> Trans[Transcode]
  ModeQ -- client_decode --> Pass1[Plan stream-copy]
  ModeQ -- auto default --> Pass1
  Pass1 --> HDRQ{HDR source<br/>+ ?tonemap=true?}
  HDRQ -- yes --> Trans
  HDRQ -- no --> BlockQ{codec in client<br/>video blocklist?}
  BlockQ -- yes --> Trans
  BlockQ -- no --> OverrideQ{per-library<br/>av1/vp9 override?}
  OverrideQ -- explicit off --> Trans
  OverrideQ -- on or inherit --> AudioQ{audio codec OK<br/>for client?}
  AudioQ -- no --> AudioMix[Stream-copy video<br/>+ transcode audio<br/>mixed-codec fallback]
  AudioQ -- yes --> Copy[Pure stream-copy]
  Copy --> Spawn[Spawn FFmpeg]
  Trans --> Spawn
  AudioMix --> Spawn
  Spawn --> Stream[(HLS playlist + segments)]
```

---

## Session state machine

```mermaid
stateDiagram-v2
  [*] --> Probing : POST /stream/start
  Probing --> Spawning : codec known
  Probing --> [*] : denied (403)
  Spawning --> Playing : first segment ready
  Spawning --> Failed : FFmpeg dies
  Playing --> Seeking : POST /stream/{sid}/seek
  Seeking --> Playing : applied_seek_sec returned
  Playing --> Paused : client side only
  Paused --> Playing
  Playing --> SwitchTrack : POST /stream/{sid}/audio-track
  SwitchTrack --> Playing
  Playing --> FallbackTranscode : POST /fallback-transcode
  FallbackTranscode --> Playing
  Playing --> FallbackAudio : POST /fallback-audio-transcode
  FallbackAudio --> Playing
  Playing --> Ended : DELETE /stream/{sid}
  Failed --> [*]
  Ended --> [*]
```

---

## Client-side fallback escalation (plan 20 + 21)

```mermaid
sequenceDiagram
  autonumber
  participant C as Client
  participant E as PlayerEngine
  participant S as Server

  C->>S: POST /stream/start (auto mode)
  S-->>C: playlist (stream-copy)
  C->>E: open(playlist)
  alt video codec rejected
    E-->>C: PlayerError(video_unsupported)
    C->>S: POST /fallback-transcode<br/>{file_id, position, codec}
    S->>S: add codec to client_codec_blocklist
    S-->>C: new playlist (transcode)
    C->>E: open(new playlist)
  else audio codec rejected
    E-->>C: PlayerError(audio_unsupported)
    C->>S: POST /fallback-audio-transcode<br/>{file_id, position, audio_codec}
    S->>S: add codec to client_audio_codec_blocklist
    S-->>C: new playlist (mixed-codec)
    C->>E: open(new playlist)
  else 6-second watchdog after PlayerReady
    E-->>C: silent timeout
    Note over C: streaming_mode=auto auto-fallback
    C->>S: POST /fallback-transcode
    S-->>C: new playlist (transcode)
  end
```

---

## Multi-audio-track support (plan 22)

```mermaid
sequenceDiagram
  autonumber
  participant C as Client UI
  participant Cu as PlayerCubit
  participant E as PlayerEngine
  participant S as Server

  S-->>C: StreamStartResponse.audio_tracks: AudioTrackInfo[]
  Note over E: PlayerEngine sees -map 0:v:0 -map 0:a?<br/>init.mp4 declares every track
  C->>Cu: open audio sheet
  Cu->>C: render track list
  C->>Cu: pick track #2
  alt media_kit / ExoPlayer can switch in-client
    Cu->>E: selectAudioTrack(index)
    E-->>Cu: switched
  else needs server respawn (plan 23 fallback)
    Cu->>S: POST /api/v1/stream/{sid}/audio-track
    S->>S: respawn FFmpeg with -map 0:a:N
    S-->>Cu: applied_seek_sec
    Cu->>E: open(new playlist)
  end
```

---

## §16 + §17 invariants (regression-guarded)

```mermaid
graph TB
  classDef rule fill:#7c3aed,stroke:#fff,color:#fff

  R1["seek_sec routed to FFmpeg<br/>(applied_seek_sec returned)"]:::rule
  R2["-readrate 1.5 + initial_burst 30<br/>only on TRANSCODE sessions"]:::rule
  R3["_omits_readrate_for_stream_copy<br/>regression guard"]:::rule
  R4["static VOD playlist pre-emitted<br/>(full duration up-front)"]:::rule
  R5["cuvid hint auto-retried w/o<br/>on Turing/RTX 20 + AV1"]:::rule
  R6["uniform info loglevel<br/>(no -loglevel error suppression)"]:::rule
  R7["ffmpeg_capabilities version probe<br/>gates capability-dependent flags"]:::rule
```

See [`docs/10_planning/16_streaming_resume_and_throttle_plan.md`](../../10_planning/16_streaming_resume_and_throttle_plan.md) + [`docs/10_planning/17_ffmpeg_diagnostics_and_m2_retry_plan.md`](../../10_planning/17_ffmpeg_diagnostics_and_m2_retry_plan.md).

---

## Known sharp edges (plan 11)

| Issue | Tracked in |
|---|---|
| Seek-restart edge cases | [plan 11](../../10_planning/11_streaming_pipeline_issues.md) |
| Tonemap timeout on long files | plan 11 |
| Zombie FFmpeg cleanup | plan 11 |
| Long-GOP game captures w/ stream-copy | resolved — `hls_time=10`, no `independent_segments` |

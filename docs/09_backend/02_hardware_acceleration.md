# Hardware Acceleration — Transcoding Pipeline

> **Status:** Phase 1 (encoder registry) + Phase 2 (DB migration) + Phase 3 (FFmpeg pipeline rewrite + self-test) + Phase 4 (GPU monitoring) complete. **All three GPU UX slices shipped 2026-05-04** — A (encoder availability surfacing + advisor), B (GPU hardware detection + Detected Hardware card), C (multi-encoder priority chain + fallback orchestration + FallbackHistoryPanel + per-session encoder_used).

---

## Problem

The software `libx264` encoder consumes one full CPU core per active transcode session.
On a typical home server (4–8 cores) this limits simultaneous full-transcode streams to
2–4 before the machine saturates. The stream-copy fast path (H.264/HEVC source files)
costs near-zero CPU, so the problem only occurs for legacy-codec files (VP9, AV1, MPEG-4,
DivX) that cannot be remuxed and must be re-encoded.

---

## Solution Overview

Use GPU-accelerated FFmpeg encoders when available on the host machine:

| Encoder | GPU / API | Platforms | Notes |
|---|---|---|---|
| `libx264` | CPU (software) | All | Default fallback; always present |
| `libx265` | CPU (software) | All | HEVC software fallback |
| `h264_nvenc` | NVIDIA CUDA | Linux, Windows | Requires Nvidia GPU + driver ≥ 418 |
| `hevc_nvenc` | NVIDIA CUDA | Linux, Windows | Same driver requirement |
| `h264_qsv` | Intel Quick Sync | Linux, Windows | Requires Intel CPU gen 6+ (Skylake+) |
| `hevc_qsv` | Intel Quick Sync | Linux, Windows | Same CPU requirement |
| `h264_vaapi` | AMD/Intel VA-API | Linux only | Requires `/dev/dri/renderD*` access |
| `hevc_vaapi` | AMD/Intel VA-API | Linux only | Same device requirement |
| `h264_videotoolbox` | Apple VT | macOS only | Built into macOS ≥ 10.8; zero config |
| `hevc_videotoolbox` | Apple VT | macOS only | Same |

**Typical gains over libx264:**
- NVENC: 10–30× throughput improvement, ~5% GPU load
- QSV: 8–20× throughput improvement
- VAAPI: 6–15× throughput improvement
- VideoToolbox: 8–25× throughput improvement

---

## Architecture

### Encoder Registry (`services/encoder_registry.py`)

All encoder-specific knowledge lives in a single `ENCODER_REGISTRY` dict keyed by
encoder name. Each entry is an `EncoderMeta` dataclass with:

- `codec` — `"h264"` or `"hevc"` (determines HLS segment format)
- `vendor` — `"software" | "nvidia" | "intel" | "amd" | "apple"`
- `hwaccel` — value for FFmpeg's `-hwaccel` flag (e.g. `"cuda"`)
- `hwaccel_output_fmt` — value for `-hwaccel_output_format`
- `preset_map` — maps software preset names to native HW names (NVENC uses `p1`–`p7`)
- `vf_chain` — optional video filter chain required by the encoder (VAAPI needs `scale_vaapi`)
- `quality_args(crf)` — returns quality flags (CRF / `-cq` / `-qp` / `-global_quality`)
- `segment_fmt` — `"mpegts"` for H.264, `"fmp4"` for HEVC (Apple HLS spec)
- `platforms` — frozenset of OS names where the encoder can exist

No other file branches on encoder names. All conditionals are replaced by registry lookups.

### FFmpeg Command Structure

Hardware encoders require `-hwaccel` flags **before** `-i`. The pipeline always produces:

```
ffmpeg [pre-input flags] -i <file> [codec flags] [audio flags] [hls output flags]
```

This is a breaking change from the old code which placed hwaccel flags after `-i`.

### Quality Mapping

Each encoder has a different quality control parameter:

| Vendor | Flag | Direction | Fluxora maps CRF → |
|---|---|---|---|
| libx264/libx265 | `-crf` | 0=best, 51=worst | Direct passthrough |
| NVENC | `-rc vbr -cq` | 0=best, 51=worst | Direct passthrough |
| QSV | `-global_quality` | 1=best, 51=worst | Direct passthrough |
| VAAPI | `-qp` | 0=best, 51=worst | Direct passthrough |
| VideoToolbox | `-q:v` | 100=best, 0=worst | `q = 100 - floor(crf * 100/51)` |

### Encoder Self-Test

On startup (background task, non-blocking) and on every encoder change via settings API,
the server runs `test_encoder()` which encodes 1 second of a lavfi test pattern.

- `test_encoder` returns `tuple[bool, str | None]` — pass/fail + first non-empty stderr line (≤240 chars) on failure.
- Results stored in `_TEST_RESULTS: dict[str, EncoderTestResult]` — a frozen dataclass with `passed: bool`, `error: str | None`, `tested_at: datetime`.
- **Pass** → encoder marked `encoder_test_passed: true`, `encoder_test_error: null` in status response.
- **Fail** → `encoder_test_error` carries the FFmpeg stderr line so the operator can see `Cannot load nvcuda.dll` rather than "test failed".

This prevents silent failures where FFmpeg accepts the encoder name but fails on real files.

---

## Slice A — Encoder availability surfacing (shipped 2026-05-04)

### Encoder Advisor (`services/encoder_advisor.py`)

New pure-function module. `recommend(active, available, test_results) -> Recommendation` applies four priority rules:

| Priority | Condition | `reason_code` | `severity` |
|----------|-----------|---------------|------------|
| 1 | Active encoder failed last self-test | `failed_active` | `warning` |
| 2 | Active is software, tested-passing GPU encoder available | `cpu_fallback` | `info` |
| 3 | Active outputs HEVC (fmp4 segments) | `hevc_compat` | `info` |
| 4 | Otherwise | `none` | `none` |

Vendor preference for GPU upgrade rule: NVIDIA → Intel → AMD → Apple. Untested encoders are never recommended.

### Desktop encoder-status widgets (`encoder_status_panel.dart`)

Three composable widgets in `apps/desktop/lib/features/transcoding/presentation/widgets/encoder_status_panel.dart`:

- `ActiveEncoderStrip` — one-line summary: encoder name + engine label + session count + CPU/GPU pill.
- `EncoderRecommendationBanner` — collapses when `reasonCode == 'none'`; shows info/warning based on `EncoderAdvice.severity`; "Switch to <encoder>" action button.
- `EncoderStatusPanel` — pill per encoder (`Recommended` / `Available` / `Failed` / `Not detected`); failed encoders show `encoder_test_error` in a hover tooltip; header shows "tested HH:MM".

All three read from `TranscodingCubit`, which fetches `/status` + `/advisor` per 2 s tick. `SettingsScreen` now provides both `SettingsCubit` and `TranscodingCubit` via `MultiBlocProvider`.

---

## NVIDIA cuvid input-decoder hint + auto-fallback

### `_NVIDIA_CUVID_BY_CODEC` map

Module-level dict mapping source codec → cuvid decoder name: `av1` → `av1_cuvid`, `hevc`/`h265` → `hevc_cuvid`, `h264` → `h264_cuvid`, `vp9` → `vp9_cuvid`, etc.

### `_input_decoder_args(source_codec, encoder_meta) -> list[str]`

Returns `["-c:v", "<codec>_cuvid"]` only when encoder vendor is NVIDIA AND source codec is in the map. Injected between `pre_input_args(...)` and `-i <file>` in the transcode branch only.

### Cuvid auto-fallback retry (widened 2026-05-04)

`_is_cuvid_failure(stderr_tail)` matches substrings in `_CUVID_FAILURE_MARKERS`:

```python
_CUVID_FAILURE_MARKERS = (
    "cuvid is not supported",
    "not supported with this chroma format",
    "cuvid",                                 # any cuvid-tagged error in the tail
    "hwaccel initialisation returned error", # NEW — covers -hwaccel cuda setup failures
    "doesn't support hardware accelerated",  # NEW — Turing AV1 NVDEC absent
    "hardware is lacking required capabilities",  # NEW — hardware capability gap
)
```

**Why the widening matters:** on Turing GPUs (RTX 20-series) that have no AV1 NVDEC at all, even `-hwaccel cuda` itself fails to initialise for AV1 input — FFmpeg logs `"Failed setup for format cuda: hwaccel initialisation returned error"` before the cuvid step. The old markers only matched cuvid-specific strings and missed this case, leaving the stream erroring on the second attempt too. The widened set catches the `-hwaccel cuda`-level failure so the full GPU input pipeline (both `-hwaccel cuda` AND `-c:v *_cuvid`) is dropped on retry.

`start_stream` refactored into:
- `_build_ffmpeg_cmd(..., use_gpu_input: bool)` — pure argv builder (renamed from `use_cuvid`; `use_gpu_input=False` drops both `pre_input_args` and `_input_decoder_args`).
- `_spawn_ffmpeg_attempt(cmd, session_id, playlist)` — runs one attempt; returns `(succeeded, stderr_tail, returncode)`.

Retry logic: spawn with `use_gpu_input=True` → on failure, if `_is_cuvid_failure` fires → spawn second attempt with `use_gpu_input=False` (software decode, NVENC encode via FFmpeg's auto-upload) → surface second error if both fail.

**Tonemap always uses `use_gpu_input=False`** from the first attempt — the `zscale` / `tonemap` filters operate on CPU frames; routing input through CUDA would require converting to CPU before the filter anyway, and many FFmpeg builds refuse the mixed-context pipeline.

---

## Slice C — Multi-encoder priority chain + fallback orchestration (shipped 2026-05-04)

The single-encoder model breaks at the cap: an RTX 2060 host running 3 NVENC streams returns 503 on stream #4 instead of falling back to the Intel iGPU's QSV. Slice C transforms `transcoding_encoder` from one choice into a **priority chain** the operator orders.

### Server architecture

- **`EncoderMeta.concurrent_session_cap: int | None`** — NVENC entries (`h264_nvenc` + `hevc_nvenc`) get cap = 3 (NVIDIA driver limit on consumer GeForce / non-Quadro cards). Software / QSV / VAAPI / VideoToolbox = `None` (no enforced cap; software is bandwidth-bound, others have no documented session limit).
- **`services/session_router.py`** — pure-function-style chain walker. `pick_encoder(chain, session_id, *, default_encoder)` walks the chain, finds the first encoder whose live-session count is under cap, reserves a slot, returns `(encoder, reason)`. `release_session(session_id)` frees the slot in `stop_stream`.
- **Reason codes**: `configured` (first chain entry was available), `gpu_session_cap_hit` (first at cap, fell to next), `all_encoders_saturated` (every entry at cap; using last anyway so FFmpeg produces a clear error), `encoder_unknown` (every chain entry was a typo, using default).
- **50-entry FIFO ring buffer** of routing decisions exposed via `GET /api/v1/transcoding/fallback-history`. In-memory only; resets on server restart. Cross-restart history uses `stream_sessions.encoder_used` (migration 021).
- **`start_stream` integration** — transcode mode only. Stream-copy bypasses the router entirely (no encoder is invoked, so it doesn't count against any cap). When `transcoding_chain` is NULL, falls back to `[transcoding_encoder, "libx264"]`.

### Storage

- **Migration 020** — `user_settings.transcoding_chain TEXT DEFAULT NULL`. JSON-encoded list (chains are tiny + single-tenant; never queried relationally).
- **Migration 021** — `stream_sessions.encoder_used TEXT DEFAULT NULL`. Populated on INSERT from `session_router.get_session_encoder(session_id)`. Drives the desktop's per-session encoder pill.
- **Validation** in `settings_service.update_settings`: rejects unknown encoders (422 with the offending entry named); rejects all-duplicate chains (`[libx264, libx264]` is meaningless); empty list normalises to NULL ("use default chain").

### Desktop architecture

- **`EncoderPriorityList` widget** (`apps/desktop/lib/features/transcoding/presentation/widgets/`). Drag-and-drop reorderable list using `ReorderableListView`. Each row: index pill, encoder label + ID, "Primary" purple pill on entry 0, X button to remove. "+ Add encoder" popup menu shows encoders not already in the chain. Controlled — parent owns state.
- **"Encoder priority chain (advanced)" `_SettingBlock`** on Settings → Streaming.
- **`FallbackHistoryCubit`** polls `/transcoding/fallback-history` every 5 s. **`FallbackHistoryPanel`** below active sessions card on the Transcoding screen renders one row per recent event with a `requested → actual` arrow + reason chip; capped at 5 most recent; collapses to nothing when buffer is empty.
- **Per-session encoder pill** on the active-sessions table — purple `h264_nvenc` etc. when transcoding, info `stream-copy` when remuxing.

### Decisions

- **NVENC cap = 3, treated as soft.** Newer drivers + RTX 40+ have lifted this on some cards but per-card detection is fragile (driver version + GPU model interact). Treating as soft means: when reached, route to next encoder *but also* let the operator force-select via a single-encoder chain → FFmpeg surfaces the actual driver error.
- **Empty list `[]` clears the chain (stored as NULL).** Distinct from null in the request body (which means "leave unchanged"). The desktop only sends `transcoding_chain` when the local list differs from the loaded snapshot.
- **In-memory ring buffer 50 entries.** Real-time diagnostic panel doesn't need cross-restart history; that's what `stream_sessions.encoder_used` is for.

---

## HDR tonemap path (shipped 2026-05-04)

### When it triggers

`start_stream(*, tonemap_hdr: bool = False)` enables the path when **both** conditions hold:
1. The caller passes `tonemap_hdr=True` (set by `routers/stream.py` from the `?tonemap=true` query param).
2. `_resolve_source_metadata` returns a non-null `hdr_format` (`"HDR10"` / `"HLG"` / `"DolbyVision"`).

If either is false the flag is a no-op (`apply_hdr_tonemap = False`) — an SDR source with `tonemap=true` streams normally.

### The zscale + Hable filter chain

```python
_HDR_TO_SDR_VF = (
    "zscale=t=linear:npl=100,format=gbrpf32le,"
    "zscale=p=bt709,"
    "tonemap=tonemap=hable:desat=0,"
    "zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
)
```

Steps in order:
1. `zscale=t=linear:npl=100` — un-PQ the HDR10 transfer function to linear light at 100 nit peak.
2. `format=gbrpf32le` — float planar colour space so `tonemap` has sufficient headroom.
3. `zscale=p=bt709` — gamut conversion: BT.2020 primaries → BT.709 primaries.
4. `tonemap=tonemap=hable:desat=0` — Hable tonemapping curve; `desat=0` preserves saturation (avoids washing out game-capture / anime content).
5. `zscale=t=bt709:m=bt709:r=tv,format=yuv420p` — back to BT.709 transfer + TV-range 8-bit yuv420p, ready for any 8-bit encoder (libx264, h264_nvenc, etc.).

### Force-transcode override

If the source would normally be stream-copied (h264 or hevc), but `apply_hdr_tonemap` is true, the pipeline overrides `direct_remux = False` — stream-copy passes the encoded bitstream unchanged and cannot apply any filter. Log: `"Tonemap requested for HDR source — overriding stream-copy for session"`.

### Combination with VAAPI vf_chain

`_build_ffmpeg_cmd` builds the final `-vf` argument by concatenating `[c for c in (_HDR_TO_SDR_VF if apply_hdr_tonemap else None, meta.vf_chain) if c]`. The tonemap chain runs first (CPU-side), converting to `yuv420p`; VAAPI's `format=nv12|vaapi,hwupload` step then sees standard 8-bit frames and uploads them to VRAM for NVENC/QSV encode. Without this ordering, VAAPI would receive BT.2020 PQ frames it cannot consume.

### `StreamStartResponse` new fields

| Field | Type | Semantics |
|-------|------|-----------|
| `hdr_format` | `str \| None` | Source HDR tag from `media_files.hdr_format`. Drives the player's HDR badge and tonemap toggle visibility. |
| `tonemapped` | `bool` | `True` when the server is actively tonemapping this session (`tonemap_hdr and hdr_format`). |

---

## Static VOD playlist (shipped 2026-05-04)

### Problem

FFmpeg's HLS muxer emits an incremental live playlist as it writes segments. Without `#EXT-X-PLAYLIST-TYPE:VOD` + `#EXT-X-ENDLIST`, `media_kit` and other players treat the stream as live — the scrubber only spans segments written so far, growing in real time.

### Fix: `_write_static_vod_playlist`

```python
def _write_static_vod_playlist(
    *, playlist: Path, duration_sec: float, hls_time: float,
    use_fmp4: bool, init_filename: str = "init.mp4"
) -> int:
```

Called after `_spawn_ffmpeg_attempt` succeeds. Writes a complete playlist to `playlist.m3u8` listing every segment FFmpeg will eventually produce (`ceil(duration_sec / hls_time)` entries), plus `#EXT-X-PLAYLIST-TYPE:VOD` and `#EXT-X-ENDLIST`. Returns the segment count.

FFmpeg writes its own incremental playlist to `_ff_playlist.m3u8` (the `ff_playlist` path in `start_stream`) — used only as the "FFmpeg has started producing output" sentinel for `_spawn_ffmpeg_attempt`'s 10 s wait loop; never served to the client.

### HLS router segment-wait

The static playlist lists segments that may not yet exist (user seeks ahead of FFmpeg's encode position). The HLS router (`GET /api/v1/hls/{session_id}/{filename}`) waits up to 5 s (50 × 100 ms polls) for `seg*.m4s` / `seg*.ts` / `init.mp4` before falling through to 404. This covers the seek-ahead case without holding the response open indefinitely.

### Limitation

Stream-copy aligns segment boundaries to source keyframes, not to `hls_time`. The predicted segment count is therefore an **upper bound** — if the source's last keyframe falls early, the final listed segments may never be written. Players retry-then-skip on 404 within reason; the visible effect is at most a small stutter at end-of-file.

---

## Known limitations

### NVENC session limits

Consumer NVIDIA GPUs cap concurrent NVENC sessions at 3 (Windows) or 8 (Linux with nvidia-patch). The tier-based `max_concurrent_streams` cap in `settings_service.py` effectively enforces this. Document in the Desktop UI tooltip.

### VAAPI requires group membership

The server process must be in the `render` (or `video`) group on Linux to access `/dev/dri/renderD*`.

### VideoToolbox preset handling

VideoToolbox ignores the `-preset` flag entirely. The Desktop UI hides the preset dropdown and shows only the quality (CRF equivalent) slider when VideoToolbox is selected.

### AV1 NVDEC chroma and bit-depth constraints

AV1 NVDEC support varies by GPU generation:
- RTX 30 (Ampere)+: supports 8-bit and 10-bit 4:2:0 AV1.
- RTX 20 (Turing) and older: **no AV1 NVDEC at all** — even `-hwaccel cuda` itself fails to initialise for AV1 input on these cards (`"hwaccel initialisation returned error"` in stderr). The widened `_CUVID_FAILURE_MARKERS` catches this; the retry drops the entire GPU input pipeline (`use_gpu_input=False`) so software decode feeds directly into NVENC encode.
- 4:4:4 chroma and 12-bit depth are unsupported on all consumer NVIDIA cards.

When the GPU input pipeline is rejected for any reason, the fallback retry uses FFmpeg's auto-selected software decoder. On bundled FFmpeg builds that lack `--enable-libdav1d`, the native AV1 software decoder also fails (`[av1] Failed to get pixel format`). In that case both attempts fail and the operator sees the second error tail.

**Operator workarounds:** re-encode the source to h264/hevc with Handbrake, or replace the bundled `ffmpeg.exe` with a build that includes `--enable-libdav1d` (see manual tasks).

---

## DB Changes

### Migration 017 — `transcoding_hwaccel_device`

```sql
ALTER TABLE user_settings
    ADD COLUMN transcoding_hwaccel_device TEXT DEFAULT NULL;
```

Relevant only for VAAPI on Linux. `NULL` means "auto" (use default device). On Windows
and macOS this column is ignored. Users with multiple AMD/Intel GPUs can point it at the
correct `/dev/dri/renderD129` (or whichever).

---

## Settings API Changes

### New field: `transcoding_hwaccel_device`

- **Type:** `str | None`
- **Default:** `null` (auto)
- **Writable via:** `PATCH /api/v1/settings` (local-only)
- **Used by:** `ffmpeg_service.start_stream()` for VAAPI `-hwaccel_device` flag

---

## GPU Monitoring

`GET /api/v1/transcoding/status` already returns `gpu_utilization_percent` and
`vram_used_mb` for NVENC (via `nvidia-smi`). The same fields are now populated for:

| Vendor | Tool | Sudo required? |
|---|---|---|
| NVIDIA | `nvidia-smi` | No |
| Intel QSV | `intel_gpu_top` | No (on most distros) |
| AMD VAAPI | `radeontop` | No (with DRM group membership) |
| Apple VT | `system_profiler SPDisplaysDataType` | No (VRAM only; util = null) |

All probes are best-effort — failure returns `null`, never raises.

---

## Implementation Phases

| Phase | Description | Status | Files |
|---|---|---|---|
| 1 | Encoder registry + model expansion | ✅ Shipped | `encoder_registry.py` (new), `models/settings.py`, `models/transcoding.py` |
| 2 | DB migration + settings service extension | ✅ Shipped | `017_hwaccel_device.sql`, `settings_service.py` |
| 3 | FFmpeg pipeline rewrite + self-test | ✅ Shipped | `ffmpeg_service.py` |
| 4 | GPU monitoring expansion | ✅ Shipped | `transcoding_service.py` |
| Slice A | Encoder availability surfacing + advisor | ✅ Shipped 2026-05-04 | `encoder_advisor.py` (new), `encoder_status_panel.dart` (new), `transcoding_cubit.dart`, `settings_screen.dart` |
| Slice B | GPU hardware detection + `/transcoding/devices` endpoint | ✅ Shipped 2026-05-04 | `hardware_probe.py` (new), `detected_hardware_card.dart` (new), `hardware_cubit.dart` (new) |
| Slice C | Multi-encoder fallback chain | ✅ Shipped 2026-05-04 | `session_router.py` (new), `020_encoder_chain.sql` + `021_session_encoder.sql` (new migrations), `EncoderMeta.concurrent_session_cap`, `encoder_priority_list.dart` (new), `fallback_history_panel.dart` (new), `fallback_history_cubit.dart` (new) |

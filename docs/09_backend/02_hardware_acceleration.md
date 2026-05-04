# Hardware Acceleration — Transcoding Pipeline

> **Status:** Phase 1 (encoder registry) + Phase 2 (DB migration) + Phase 3 (FFmpeg pipeline rewrite + self-test) + Phase 4 (GPU monitoring) complete. Slice A (encoder availability surfacing + advisor) shipped 2026-05-04. Slice B (GPU hardware detection) pending owner approval.

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

### Cuvid auto-fallback retry

`_is_cuvid_failure(stderr_tail)` matches substrings `('cuvid is not supported', 'not supported with this chroma format', 'cuvid')`. Conservative — only fires on cuvid-tagged failures.

`start_stream` refactored into:
- `_build_ffmpeg_cmd(..., use_cuvid: bool)` — pure argv builder.
- `_spawn_ffmpeg_attempt(cmd, session_id, playlist)` — runs one attempt; returns `(succeeded, stderr_tail, returncode)`.

Retry logic: spawn with cuvid → on failure, if `_is_cuvid_failure` fires → spawn second attempt without cuvid → surface second error if both fail.

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
- RTX 20 (Turing) and older: no AV1 NVDEC support at all — cuvid hint will fail cleanly; auto-fallback fires.
- 4:4:4 chroma and 12-bit depth are unsupported on all consumer NVIDIA cards.

When cuvid is rejected for chroma/bit-depth reasons, the fallback retry uses FFmpeg's auto-selected software decoder. On bundled FFmpeg builds that lack `--enable-libdav1d`, the native AV1 software decoder also fails (`[av1] Failed to get pixel format`). In that case both attempts fail and the operator sees the second error tail.

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
| Slice B | GPU hardware detection + `/transcoding/devices` endpoint | Pending owner approval | — |
| Slice C | Multi-encoder fallback chain | Pending owner approval | — |

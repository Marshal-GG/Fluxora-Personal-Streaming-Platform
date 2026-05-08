# FFmpeg Diagnostics + M2 (`-readrate`) Retry Plan

> **Category:** Planning
> **Status:** Drafted 2026-05-08; **M1 + M2 + M3 + M4 ✅ all landed 2026-05-08; real-device follow-on patches landed same day.** Server suite 681 → 695 (+14). Pending operator's real-device re-retest.
> **Scope:** Close the diagnostic blind-spot that caused two M2 (`-readrate` throttle) attempts to fail with `<no stderr captured>` and surface the same opacity for the HDR audio bug. Re-attempt M2 with the diagnostics in place. Carries forward the four pre-conditions originally listed in [`16_streaming_resume_and_throttle_plan.md`](./16_streaming_resume_and_throttle_plan.md) §M2.
> **Triggered by:** operator question 2026-05-08 — *"create a proper plan to fix prob issue and implement it fully, upgrade the versions if that can fix it"*. Investigation revealed the system's FFmpeg is **8.0**, well above the 5.1 minimum for `-readrate_initial_burst` — no upgrade needed. The actual blocker is diagnostic: `-loglevel error` was hiding whatever FFmpeg complained about.

---

## 1 · Investigation Findings (2026-05-08)

### 1.1 FFmpeg version

```
ffmpeg version 8.0-essentials_build-www.gyan.dev Copyright (c) 2000-2025 the FFmpeg developers
libavformat    62.  3.100 / 62.  3.100
libavcodec     62. 11.100 / 62. 11.100
```

**Conclusion:** FFmpeg 8.0 supports every flag we want (`-readrate` since 4.x, `-readrate_initial_burst` since 5.1). **No upgrade required.**

### 1.2 What `_ffmpeg_bin()` actually resolves to

`apps/server/services/ffmpeg_service.py::_ffmpeg_bin()` checks for a PyInstaller-bundled binary first (`sys._MEIPASS/ffmpeg`); on dev (uvicorn-direct) it falls through to `shutil.which("ffmpeg")` — which resolves via system `PATH`. Operator runs in dev mode → bundled FFmpeg theory is wrong; the M2 failures hit FFmpeg 8.0.

### 1.3 What actually went wrong on the two M2 attempts

Both attempts ended with the same kill-after-10s-no-stderr pattern:

```
ERROR services.ffmpeg_service: FFmpeg killed after 10s timeout (no first segment)
                                FFmpeg stderr (last 4 KB):
                                <no stderr captured>
```

`_loglevel error` was suppressing FFmpeg's init / progress / warning output so by the time we killed the process, the captured stderr file was empty. We were diagnostically blind — the M2 revert was the right call given the lack of signal, but the actual root cause is still unknown.

### 1.4 Why the same blind-spot hit the HDR audio bug

Same `<no stderr captured>` shape on the HDR path. The audio-drop fix (force re-encode under tonemap) was a reasoned guess based on architectural knowledge — but if that fix doesn't hold under real-device retest, we'd be guessing again. Diagnostics first; fixes second.

---

## 2 · Goals

1. Make EVERY future "FFmpeg failed for unknown reason" failure produce actionable stderr in our logs.
2. Pin the FFmpeg version + capabilities at server startup so any flag we add can be gated correctly.
3. Re-attempt M2 (`-readrate 1.5` + `-readrate_initial_burst 30`) with the diagnostic infrastructure in place — either it works (heat / fan win), or we see why it doesn't and decide based on real signal instead of guessing.

## 3 · Non-goals

- Sliding-window encoder. Still v1.1 per `16_streaming_resume_and_throttle_plan.md` §6 with telemetry-driven revisit triggers. Don't pre-emptively build it.
- FFmpeg version upgrade. Already on 8.0, no upgrade required.
- Bundle-vs-system FFmpeg discipline. Out of scope; covered by the existing PyInstaller distribution path (`apps/server/build/`).

---

## 4 · Sequenced Remediation

```
M1 — Loglevel bump (info; always)                  │ ~15 min   │ low risk    │ ✅ landed 2026-05-08
M2 — FFmpeg version probe at server startup        │ ~30 min   │ low risk    │ ✅ landed 2026-05-08
M3 — Re-attempt -readrate 1.5 + initial_burst 30   │ ~30 min   │ medium risk │ ✅ landed 2026-05-08
M4 — Timeout-helper for slow-startup transcodes    │ ~15 min   │ low risk    │ ✅ landed 2026-05-08
─────────────────────────────────────────────────  │ ────────  │ ────────    │
Total                                              │ ~1 h 30 min                │ ✅ ALL DONE
```

### M1 — Loglevel bump

**Goal:** never see `<no stderr captured>` again on a transcode failure path.

**Change:** `_build_ffmpeg_cmd` always uses `-loglevel info` (was `warning` for transcode + `error` for stream-copy). FFmpeg's `info` level emits init messages + per-frame stats; with our 4 KB stderr-tail cap (`_drain_stderr`), the in-memory cost is unchanged and the disk cost (per-session tempfile) is bounded by FFmpeg's own log volume.

**Trade-off:** healthy sessions write more bytes to the tempfile while running. Not a problem — the file is unlinked at session end. The win is that init-time errors (unknown options, decoder rejection, slow source-disk read) reach the captured stderr instead of being suppressed.

**Tests:**
- Update existing `test_build_ffmpeg_cmd_uses_warning_loglevel_for_transcode` + `_uses_error_loglevel_for_stream_copy` to assert `info` for both, OR delete + replace with a single `_uses_info_loglevel`.

### M2 — FFmpeg version probe at startup

**Goal:** know what FFmpeg the server is using; cleanly gate version-dependent flags.

**Changes:**
- New module `apps/server/services/ffmpeg_capabilities.py` — async function `probe_ffmpeg_capabilities() -> FfmpegCapabilities` that runs `ffmpeg -version`, parses major/minor, exposes a frozen dataclass:
  ```python
  @dataclass(frozen=True)
  class FfmpegCapabilities:
      version_string: str           # full first-line output
      major: int
      minor: int
      supports_readrate_initial_burst: bool   # major >= 5 and (major > 5 or minor >= 1)
  ```
- New module-level `_capabilities: FfmpegCapabilities | None = None` populated at server startup (hook into `main.py` startup alongside the existing FFmpeg path probe).
- One INFO log line at startup: `ffmpeg_capabilities version="8.0..." major=8 minor=0 supports_readrate_initial_burst=true`.
- Public `get_capabilities() -> FfmpegCapabilities` so `_build_ffmpeg_cmd` (and any future code) can read.

**Tests:**
- `test_probe_capabilities_parses_real_ffmpeg_version` — runs the actual subprocess, asserts version_string non-empty + major >= 4.
- `test_capabilities_supports_readrate_initial_burst_for_5_1` — synthetic dataclass construction.
- `test_capabilities_falls_back_when_ffmpeg_missing` — `_ffmpeg_bin()` raises FileNotFoundError → `probe_ffmpeg_capabilities` returns a "version unknown" sentinel rather than raising.

### M3 — Re-attempt M2 with version-gated flags

**Goal:** re-introduce `-readrate 1.5` + `-readrate_initial_burst 30` now that we can see why it fails (M1) and know what FFmpeg supports (M2).

**Changes in `_build_ffmpeg_cmd`:**
- Re-add `-readrate 1.5` always (FFmpeg 4.x+ supports it; we run 8.0; safe everywhere we'll deploy).
- Add `-readrate_initial_burst 30` ONLY when `get_capabilities().supports_readrate_initial_burst` is True. Older builds (PyInstaller bundle if pinned older than 5.1) get the throttle without the burst — first-segment lands within ~7 s wall on stream-copy, which fits the M4-bumped timeout below.
- Skip both when `apply_hdr_tonemap` is True (existing behaviour; tonemap is already CPU-bound at <1× realtime).

**Regression-guard tests** (replace the absence-pinning tests from the M2 revert):
- `_includes_readrate_when_supported`
- `_includes_initial_burst_when_capabilities_support_it`
- `_omits_initial_burst_when_capabilities_too_old` (synthetic capabilities = (5, 0))
- `_omits_both_when_tonemap_active` (preserve existing behaviour)

### M4 — Timeout helper for slow-startup transcodes

**Goal:** when `-readrate` is on, give FFmpeg enough wall-time to produce the first segment without timeout-killing it.

**Changes in `_spawn_ffmpeg_attempt`:**
- New optional `extended_timeout: bool = False` keyword param.
- When True, `playlist_timeout_sec = max(playlist_timeout_sec, 30.0)` — covers the worst case where readrate's burst-window doesn't fully absorb the first-segment wait (e.g. slow source-disk read combined with throttle).
- `start_stream` passes `extended_timeout=True` whenever `-readrate` is in the cmd.

**Tests:**
- `_extended_timeout_bumps_to_30s_when_readrate_active` (mock `_spawn_ffmpeg_attempt`; assert the timeout argument matches expectation).

---

## 5 · Decisions Locked In

1. **`info` loglevel always, not conditional on direct_remux.** Conditional logic was the original sin — error level on stream-copy meant the HDR audio bug (which IS stream-copy on the audio path) had no diagnostics. Same logic for transcode. Just: `info` everywhere.
2. **Capabilities probe runs at server startup, not lazily.** Cheap (~50 ms), one-shot, idempotent. Server already does FFmpeg path probing at startup; the capabilities probe rides alongside.
3. **`-readrate` re-introduces unconditionally on FFmpeg 4+.** No version check there since the supported-since-version is so old (FFmpeg 4 was released 2018). The version probe gates only the burst flag.
4. **No PyInstaller bundle re-evaluation.** The existing `apps/server/build/` distribution model stays as-is. The capabilities probe handles version drift between dev (system) and prod (bundled) without changing the bundle.

---

## 6 · Verification

- `python -m pytest tests/` — server suite green; actual delta **681 → 695 = +14 tests** (M1 swap; M2 capabilities +11 with regex-coverage and failure-path cases; M3 readrate +4; same-day follow-on `_omits_readrate_for_stream_copy` regression guard +1; M4 timeout-helper covered by existing readrate test parametrisation, no separate test added).
- `python -m ruff check .` — clean.
- `flutter analyze` — clean (no mobile-side changes in this plan).
- **Real-device retest** — operator opens a regular video, confirms first frame within ≤ 12 s and steady-state CPU/GPU at single digits (the heat win that motivated M2 in the first place). If the M3 retry STILL fails, the M1 stderr now tells us why and we revisit with information.

---

## 7 · Future Work — still v1.1

Sliding-window encoder remains explicitly v1.1 per [`16_streaming_resume_and_throttle_plan.md`](./16_streaming_resume_and_throttle_plan.md) §6. Telemetry-driven revisit triggers unchanged.

---

## 8 · Real-device follow-on patches (2026-05-08, same-day after M1–M4)

Operator retested with M1–M4 in place and surfaced two new symptoms.  Both are pinned by regression tests so they don't silently regress.

### 8.1 `seg00195.ts` 404 storm on stream-copy seek-restart

**Symptom:** seeking forward into a stream-copy session repeatedly 404'd the next segment; mobile gave up after a handful of retries.

**Cause:** `-readrate 1.5` was being applied to stream-copy too.  Stream-copy is already CPU-cheap (~real-time disk-read + remux); the throttle just delayed the post-restart first segment past the 2 s segment-serve wait timeout → router returned 404 → media_kit retried a few times then gave up.

**Fix:** `_build_ffmpeg_cmd` now gates `-readrate` (and the burst flag) to **transcode-only**: `if not direct_remux and not apply_hdr_tonemap:`.  Stream-copy paths get neither flag.  The timeout-floor bump in `_spawn_ffmpeg_attempt` was tightened to match.

**Tests:**
- `test_build_ffmpeg_cmd_omits_readrate_for_stream_copy` — new regression guard pinning that `direct_remux=True` produces neither flag, regardless of capabilities.
- Existing `_includes_readrate_on_modern_ffmpeg`, `_omits_initial_burst_on_pre_5_1_ffmpeg`, `_falls_back_when_capabilities_unknown` all flipped from `direct_remux=True` to `direct_remux=False` (transcode mode).

### 8.2 Scrubber jumps to max during drag, then back to release point

**Symptom:** drag the scrubber forward → it visually rubber-bands to the right edge mid-drag, then snaps back to the actual release point once the seek-restart completes.

**Cause:** `_ProgressBar.onChanged` was calling `player.seek(clampedPlayerMs)` on every drag-tick.  For a forward drag, the requested player-time often exceeded the current playlist's apparent end-time → libmpv clamped to the end → scrubber rendered the player's clamped position → max-edge bounce.  This is purely a preview-rendering bug; the actual server-side seek-restart on `onChangeEnd` was already correct.

**Fix:** `_ProgressBar` converted from `StatelessWidget` to `StatefulWidget`.  Added `_dragValue: double?` local state.  During drag (`onChangeStart` + `onChanged`): only `setState(() => _dragValue = v)` — no `player.seek` call.  On release (`onChangeEnd`): clear `_dragValue` and fire `onSeekCommit(target)`.

**Tests:** mobile-side widget — `flutter analyze` clean.  No automated test added (drag-rendering is not unit-testable without a `WidgetTester` flow; the regression is one-line obvious in the diff).

---

## 9 · TL;DR

Operator's system FFmpeg is 8.0 — no upgrade needed. The two M2 failures were diagnostically blind, not version-gated. Plan: ship `info` loglevel + version probe so future failures are visible, then re-attempt M2 with the diagnostics in place. ~1.5 hours end-to-end + two same-day real-device follow-on fixes (transcode-only readrate gating, scrubber-drag local state). Sliding-window encoder stays v1.1.

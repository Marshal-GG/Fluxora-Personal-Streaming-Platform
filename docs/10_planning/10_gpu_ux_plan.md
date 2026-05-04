# GPU & Encoder UX Plan — Desktop Settings + Server-Side Orchestration

> **Category:** Planning
> **Status:** Drafted 2026-05-04. **All three slices shipped 2026-05-04.** Slice A — encoder availability surfacing + advisor + active-encoder strip. Slice B — hardware probe + `/transcoding/devices` + Detected Hardware card. Slice C — multi-encoder fallback chain + `session_router` + EncoderPriorityList drag-and-drop + FallbackHistoryPanel + per-session `encoder_used`.
> **Goal:** Make the operator's GPU + encoder reality *visible* in the desktop control panel, then *intelligent* (recommendations + automatic fallback), then *resilient* (multi-encoder routing under load).
> **Scope:** Server (`apps/server/`) + Desktop (`apps/desktop/`). Mobile shows the active encoder per-stream as a footnote only — no UI re-architecture.

---

## 1. Why this exists

The HW-acceleration slice that just landed (encoder registry + 10 encoders + per-vendor probes + `encoder_test_passed`) is **server-only**. The desktop UI:

- Hands the operator a 10-row encoder dropdown with no hint of which encoders this machine actually supports.
- Doesn't say which GPU is installed, which engine the active encoder is using, or whether streams are CPU- or GPU-bound right now.
- Has no concept of "this encoder failed self-test, picking it will break playback" — the operator only finds out after a save + a stream attempt + a Sentry trace.
- Has no fallback path when the configured encoder hits a session limit (NVENC consumer cards cap at 3 concurrent sessions; QSV is bandwidth-bound; VAAPI dies if `/dev/dri/renderD128` is on a different GPU than the one driving display).

The user asked for: which GPU is detected, whether CPU or GPU is being used, multi-GPU fallback (including integrated graphics), and per-encoder recommendation + issue flags. This plan inventories every surface, scopes the server work, and locks the cutover ritual.

**Cross-references:**
- [`docs/09_backend/02_hardware_acceleration.md`](../09_backend/02_hardware_acceleration.md) — server-side encoder registry, FFmpeg flag-ordering, GPU probe commands, self-test lifecycle.
- [`docs/04_api/01_api_contracts.md`](../04_api/01_api_contracts.md) — every new endpoint here lands there.
- [`docs/03_data/02_database_schema.md`](../03_data/02_database_schema.md) — schema additions (none expected for Slices A+B; Slice C may add a session-routing table).
- [`docs/05_infrastructure/02_url_inventory.md`](../05_infrastructure/02_url_inventory.md) — every new URL here lands there.
- [`AGENT_LOG.md`](../../AGENT_LOG.md) — implementation entries land here per slice.

---

## 2. Inventory — every surface that needs work

| Surface | Today | Real-data path | Server work | Desktop work | Slice |
|---------|-------|----------------|-------------|--------------|-------|
| Settings → Streaming → Encoder dropdown | Static 10-item list, every encoder selectable, no status indicator | Annotate each row with one of `Recommended` / `Available` / `Failed` / `Not on this OS` / `Not detected`. Sort Recommended first, Failed greyed-out at bottom (still selectable so the operator can investigate). Below the dropdown, render a status panel: active encoder name, vendor, GPU engine (`cuda` / `qsv` / `vaapi` / `videotoolbox` / `cpu`), last-test timestamp, and (for failed encoders) the first non-empty stderr line from the self-test. | None — `/api/v1/transcoding/status` already returns `available_encoders`, `encoder_loads[*].encoder_test_passed`, `encoder_loads[*].gpu_engine`. Slice A is pure desktop work. **Server addition (small):** capture the failed self-test's stderr tail (first line, ≤200 chars) and add `encoder_test_error: str \| null` to `EncoderLoad` so the UI can surface it. | New `EncoderStatusPanel` widget below the dropdown. Wraps the dropdown in a `BlocConsumer<TranscodingStatusCubit, TranscodingStatusState>`. Pill renderer + sort-aware `FluxSelect` items + tooltip on hover for failed encoders. | A |
| "What GPU am I using?" card | No surface today | New "Detected hardware" card on the Streaming tab. Shows: GPU vendor + model + VRAM (if probe-able), encoder support pills (e.g. `NVENC: H.264 + HEVC`, `QSV: H.264 only`), driver version where the probe yields it. | New endpoint `GET /api/v1/transcoding/devices` that runs `nvidia-smi -L` (NVIDIA), `lspci -nn` (Linux PCI scan), `wmic path Win32_VideoController` (Windows), or `system_profiler SPDisplaysDataType` (macOS). Returns `[{vendor, model, vram_mb, driver_version, encoder_support: ['h264_nvenc', ...]}]`. Probe is cached for the process lifetime (hardware doesn't change without a reboot). | New `DetectedHardwareCard` widget. Loads from a new `HardwareCubit`. Renders one card per detected GPU, plus a CPU card with its model + thread count. | B |
| VAAPI device-path field | Free-text input — operator types `/dev/dri/renderD128` blind | Replace with a `FluxSelect` populated from `/api/v1/transcoding/devices`. The card from row 2 already enumerates GPUs; reuse the same payload here, filtered to Linux-VAAPI-capable GPUs. Free-text input is kept as an "Other (custom)" option for unusual setups. | The same `/devices` endpoint is enough — Linux probe walks `/dev/dri/render*`. **Server addition:** annotate each device entry with its `dev_path` so the dropdown can use it as the value. | Replace the `_SField` `FluxTextField` with a `FluxSelect`. Falls back to text input on non-Linux platforms (the field is hidden anyway when the active encoder isn't VAAPI). | B |
| "What encoder am I using right now?" badge | Already in the API but never surfaced | Tiny strip at the top of the Streaming tab: `Active: NVIDIA GeForce RTX 4070 (NVENC, h264_nvenc) · 2 of 3 streams using GPU · CPU 14%`. Updates every 2 s from the existing `/api/v1/transcoding/status` poll. | None — fields already exist. | New `ActiveEncoderStrip` widget. Composed from `TranscodingStatusCubit.state.activeEncoder` + `state.encoderLoads.find(active).gpuUtilizationPercent`. | A |
| Per-stream encoder visibility | Active sessions list shows file + client; no encoder column | Add `encoder_used: str` to each session in `TranscodingStatusResponse.active_sessions[*]`. So the operator sees that File A is using `h264_nvenc` (GPU) and File B is using `libx264` (CPU fallback after NVENC saturated). | Server tracks `encoder_used` per session. Currently `start_stream` resolves the encoder once and never persists it on the session row — Slice C wires this through `stream_sessions` (new column or in-memory cache keyed by session_id). | Existing transcoding screen's session table grows an "Encoder" column. | B (read) / C (write) |
| Encoder recommendation banner | None | Banner above the dropdown when the operator's active choice is suboptimal. Three failure modes:<br>**1. CPU fallback when GPU is available:** "You're on `libx264` (CPU). NVENC is detected and tested — pick `h264_nvenc` for ~10× faster transcoding."<br>**2. Failed encoder is selected:** "`hevc_qsv` failed self-test (Iris driver missing). Falling back to `libx264`. [Re-run test]"<br>**3. HEVC encoder + non-Apple HLS clients:** "HEVC requires fmp4 segments — older Roku / Chromecast 1st gen can't play these. Use `libx264` for max compatibility." | Recommendation logic lives server-side in a new `services/encoder_advisor.py`. Returns `{recommended_encoder: str, reason_code: enum, reason_text: str}` from `GET /api/v1/transcoding/advisor`. Pure function over `available_encoders` + `encoder_test_results` + `active_encoder`. No state. | New `EncoderAdvisorCubit` + `EncoderRecommendationBanner`. Banner is dismissable per session (not persistent — re-evaluate on every dropdown change). | A (basic logic) / B (richer rules with hardware data) |
| Failed-encoder modal | Self-test failure is silent | When an encoder's self-test fails, surface a modal on next Settings open: "`h264_qsv` self-test failed. Output: `Failed to load Intel media driver. Reinstall Intel Media SDK from intel.com/qsv-driver`. We've selected `libx264` instead." Modal is dismissed by clicking "OK, use libx264" or "Re-test". | The `encoder_test_error` field from row 1 carries the stderr; a new `notification` event of type `encoder.test_failed` is emitted when a self-test fails so the desktop's notifications system already routes it. | Add the new notification event to the renderer mapper. Add a "View encoder logs" link in the modal that deep-links to `Settings → Transcoding`. | A |
| Multi-encoder concurrent routing | Single configured encoder; N+1 stream returns 503 if the encoder's session cap is hit | Operator picks a *priority chain* in Settings — e.g. `[h264_nvenc, h264_qsv, libx264]`. When `start_stream` runs, it tries the first encoder in the chain; if that encoder has hit its session cap (NVENC consumer cards ≤ 3, others bandwidth-bound), it tries the next. Failed sessions log *which* encoder was used. | Major server work: `start_stream` consults `services/session_router.py`; per-encoder session counts are tracked in-memory with a sliding window; chain config persisted in `user_settings.transcoding_chain` (new TEXT column, JSON-encoded list). New endpoint `PATCH /api/v1/settings { transcoding_chain: [...] }`. | New `EncoderPriorityList` widget — drag-and-drop reorder of available encoders, each tagged with its session-cap. Renders the active chain as a column with up/down handles + a +Add button to append a new encoder. | C |
| "Why is my CPU pinned?" diagnostic | Operator has to read FFmpeg stderr in `~/.fluxora/logs/server.log` | New diagnostic panel below the active sessions list: "Last 5 streams that fell back to CPU and why." Each row shows: timestamp, file, requested encoder, fallback encoder, reason (`gpu_session_cap_hit`, `encoder_self_test_fail`, `unsupported_codec`, `manual_override`). | `services/session_router.py` records fallback events to a small ring buffer (in-memory, 50 entries). New endpoint `GET /api/v1/transcoding/fallback-history`. | New `FallbackHistoryPanel` widget. Read-only, refreshes when the operator opens the Transcoding screen. | C |
| Mobile player — encoder footnote | None | Tiny overlay in the player when paused (or when the operator long-presses the title bar) showing "Streaming via h264_nvenc · 1080p · ~3 Mb/s". Helps the operator confirm hardware acceleration kicked in for *this* stream from the device's POV. | New `encoder_used: str` field on the `/stream/start` response (already calculated server-side; add the field to the response model). | New `_PlayerStreamInfoChip` widget; reads from `PlayerCubit.state.encoderUsed` via the existing `startStream` response wiring. | B |
| Settings → About → System info | Server name, version, tier | Add: server-machine GPU summary (one-liner per detected GPU) + active encoder + active stream count. Same data the Streaming tab uses — just rendered as static metadata on the About tab so an operator filing a support ticket can copy-paste it. | None — uses existing `/transcoding/status` + new `/transcoding/devices`. | New rows under About → "Hardware". | B |
| `docs/09_backend/02_hardware_acceleration.md` follow-on | Slice 1 (registry) + Slice 4 (probes) documented | Append: advisor algorithm, recommendation rules, fallback chain config schema, fallback-history ring buffer rationale. | Doc only. | None. | A/B/C respectively |

---

## 3. Phasing

Three slices, each independently shippable. **Slice A is the value-per-effort sweet spot** — the user gets immediate visibility into encoder health with zero new endpoints. Slices B + C compound on A.

### Slice A — "What's actually working?" ✅ shipped 2026-05-04

**Pure surfacing.** No new endpoints; one small server-side addition for the self-test stderr.

**Server work**
- `services/transcoding_service.py` — extend `_TEST_RESULTS` from `dict[str, bool | None]` to `dict[str, EncoderTestResult]` where `EncoderTestResult` is `{passed: bool, error: str | None, tested_at: datetime}`. The `error` field captures the first non-empty stderr line from the failed FFmpeg test invocation.
- `services/ffmpeg_service.test_encoder` — return a tuple `(passed: bool, error: str | None)` instead of `bool`. Capture stderr to a tempfile (mirrors the existing pattern in `start_stream`), drain on completion, surface the first non-empty line on failure.
- `models/transcoding.py` — `EncoderLoad` gains `encoder_test_error: str | None` and `encoder_tested_at: datetime | None`.
- `services/encoder_advisor.py` (new) — pure function `recommend(active: str, available: list[str], test_results: dict[str, EncoderTestResult]) -> Recommendation`. Rule set:
  - If active is software but a tested-passing GPU encoder exists: recommend the GPU encoder.
  - If active failed self-test: recommend the highest-priority tested-passing encoder, software at minimum.
  - If active is HEVC: warn about playback compatibility (matter-of-fact, not a critical recommendation).
- New endpoint `GET /api/v1/transcoding/advisor` (local-only).

**Desktop work**
- New `EncoderStatusPanel` widget under the encoder dropdown. Renders one row per `_kEncoders` entry with a status pill:
  - **Recommended** — purple pill, top of the list.
  - **Available** — neutral pill, alphabetical within group.
  - **Failed** — red pill, greyed text, error tooltip on hover, "Re-test" chip.
  - **Not on this OS** — grey pill, hidden by default with a "Show all" toggle.
  - **Not detected** — grey pill, "build of FFmpeg without this encoder", same hide-by-default treatment.
- Replace the current `_kEncoders` const list with an `EncoderItem` model that carries the status + label. Hydrate from `TranscodingStatusCubit`.
- New `ActiveEncoderStrip` at the top of the Streaming tab — one-line summary that updates every 2 s.
- New `EncoderRecommendationBanner` — dismissable per session, fed by the new `/advisor` endpoint.
- Failed-encoder modal — opens on first navigation to Settings → Streaming after a failed self-test (notification-driven; one-shot per failure event).

**Tests**
- Server: `test_encoder_advisor.py` — 6 cases (CPU-only setup recommends nothing; CPU active + NVENC tested-passing → recommends NVENC; HEVC encoder active emits HEVC compatibility warning; failed-active recommends fallback; etc.). +1 case in `test_transcoding.py` for the `encoder_test_error` field.
- Desktop: `encoder_status_panel_test.dart` — pill rendering for each status; sort order; failed-tooltip text. +1 cubit test for `EncoderAdvisorCubit`.

**Mock entries deletable after Slice A:** none yet — Slice A is additive UI.

### Slice B — "What hardware is in this box?" ✅ shipped 2026-05-04

**New endpoint, GPU detection, hardware cards.**

**Server work**
- `services/hardware_probe.py` (new) — per-platform GPU enumeration:
  - **Linux:** `lspci -nn -d ::0300` for VGA-class devices; supplement with `nvidia-smi -L` for NVIDIA model + VRAM; walk `/dev/dri/render*` for VAAPI device paths.
  - **Windows:** `wmic path Win32_VideoController get Name,AdapterRAM,DriverVersion /format:csv`. (No PowerShell dependency for parity with the PyInstaller bundle.)
  - **macOS:** `system_profiler SPDisplaysDataType -json`.
  - **CPU:** `cpuinfo` (Linux) / WMI (Windows) / `sysctl -n machdep.cpu.brand_string` (macOS). Always returned — useful as a baseline.
- All probes are best-effort — failure returns `[]`, never raises. Cached for process lifetime.
- New endpoint `GET /api/v1/transcoding/devices` (local-only). Response shape:
  ```json
  {
    "cpus": [{"vendor": "Intel", "model": "...", "threads": 16}],
    "gpus": [
      {"vendor": "nvidia", "model": "GeForce RTX 4070", "vram_mb": 12288,
       "driver_version": "535.171.04", "dev_path": null,
       "encoder_support": ["h264_nvenc", "hevc_nvenc"]},
      {"vendor": "intel", "model": "UHD Graphics 770", "vram_mb": null,
       "driver_version": null, "dev_path": "/dev/dri/renderD128",
       "encoder_support": ["h264_qsv", "hevc_qsv", "h264_vaapi", "hevc_vaapi"]}
    ]
  }
  ```
- `models/transcoding.py` — `ActiveTranscodeSession` gains `encoder_used: str` (read-only).
- `routers/stream.py` — `start_stream` response gains `encoder_used: str` so the mobile client can surface it.

**Desktop work**
- New `HardwareCubit` + `DetectedHardwareCard` widget on the Streaming tab.
- VAAPI device-path field → `FluxSelect` populated from `/devices` (with "Other (custom)" fallback).
- Active sessions table grows an "Encoder" column.
- About tab → Hardware section (static rendering of the same data).

**Mobile work**
- `_PlayerStreamInfoChip` widget — long-press title in the player or surface during pause overlay.

**Tests**
- Server: `test_hardware_probe.py` — mocked subprocess for each platform; verifies parsing, error handling, cache behaviour. +2 cases on the `/devices` endpoint (auth + response shape).
- Desktop: `hardware_cubit_test.dart` — load + error + retry. Widget test for `DetectedHardwareCard` rendering.

**Risks**
- `wmic` is deprecated on Win11 23H2+ but still ships. **Fallback:** parse `Get-WmiObject` via PowerShell only if `wmic` returns non-zero. Verified at run-time, no precondition.
- `lspci` requires `pciutils` package on minimal Linux installs. **Mitigation:** failure returns the GPU model as `"Unknown PCI device 0x..."` from `/sys/class/drm/*/device/{vendor,device}`.

### Slice C — "Don't fail loudly when one encoder saturates" ✅ shipped 2026-05-04

**Multi-encoder priority chain + fallback orchestration. Largest slice; most risk.**

**Server work**
- New SQL migration `019_encoder_chain.sql` — adds `transcoding_chain TEXT` to `user_settings` (JSON-encoded list, e.g. `'["h264_nvenc","h264_qsv","libx264"]'`).
- `services/session_router.py` (new) — orchestrates encoder selection on `start_stream`:
  - Read `transcoding_chain` from `user_settings`.
  - For each encoder in the chain: ask `_active_session_count_for_encoder(encoder)`; if below the encoder's known cap (registry-defined: NVENC = 3 on consumer cards, others = unlimited), reserve a slot and return that encoder.
  - If every encoder in the chain is at cap: fall through to the last entry anyway (it'll fail at FFmpeg level with a clear error, which is preferable to a 503 the operator can't diagnose).
  - Record the routing decision to a 50-entry ring buffer for the diagnostic panel.
- `EncoderMeta` gains `concurrent_session_cap: int | None`. NVENC `= 3`, QSV / VAAPI / VideoToolbox / libx264 = `None` (no cap).
- `start_stream` consults `session_router.pick_encoder()` instead of reading `transcoding_encoder` directly. The configured `transcoding_encoder` becomes the *first* entry of the chain when no chain is configured (back-compat for existing installs).
- New endpoint `GET /api/v1/transcoding/fallback-history` (local-only) — returns the ring buffer.
- `stream_sessions` schema migration `020_session_encoder.sql` — adds `encoder_used TEXT` so historical fallback events are visible after a server restart (ring buffer is in-memory).

**Desktop work**
- New `EncoderPriorityList` widget — drag-and-drop reorderable list of encoders. Each row tagged with `(N/M sessions)` where M is the encoder's session cap (or `∞` for uncapped).
- Save action posts the chain to `PATCH /api/v1/settings { transcoding_chain: [...] }`.
- New `FallbackHistoryPanel` widget on the Transcoding screen.

**Tests**
- Server: `test_session_router.py` — chain-with-no-cap; chain-where-first-is-saturated-falls-through; ring buffer FIFO + capacity. `test_settings.py` extension for the `transcoding_chain` field's PATCH validation. `test_stream.py` updates: existing tests assert a single encoder; new tests assert chain-aware routing.
- Desktop: `encoder_priority_list_test.dart` — drag-and-drop reorder, save, validation that at least one encoder must remain.

**Risks**
- **NVENC consumer-card limit detection.** The "3 sessions" cap depends on the GPU model + driver — newer 40-series cards have lifted it. Hardcoding `3` is conservative but wrong on hardware that supports more. **Mitigation:** the `concurrent_session_cap` is treated as a *soft* limit — when reached, attempt the next encoder *but also* try the original one if the operator overrides via a `force_encoder` query param on `/stream/start`. NVIDIA's actual driver-level cap will surface as a clear FFmpeg error (`OpenEncodeSessionEx failed: out of memory`).
- **In-memory ring buffer is lost on restart.** Operators with intermittent issues won't see fallback events from yesterday. Acceptable for v1 — Slice C's goal is real-time diagnosis, not historical analysis. v2 can persist to a `transcoding_events` table.

**Dependencies**
- Slice C requires Slice B's `encoder_used` field on `ActiveTranscodeSession` (otherwise the active sessions table can't show what each one is using).

---

## 4. Decisions to lock before starting

| # | Decision | Default | Rationale |
|---|----------|---------|-----------|
| 1 | Recommendation algorithm placement: server vs. desktop | **Server** (`services/encoder_advisor.py`) | Pure-function decision over `available_encoders` + `test_results` is small and stateless; centralising means future mobile / web clients get the same recommendation without reimplementing. |
| 2 | Hardware probe caching strategy | **Process-lifetime** (re-probe on server restart only) | GPU + driver don't change without a reboot; probe cost is real (`wmic` is ~500ms cold). Cache invalidation = restart. |
| 3 | Should "Failed" encoders remain selectable in the dropdown? | **Yes**, with a confirmation dialog | Lets the operator force-select to gather more diagnostics; greyed-out-disabled would hide the encoder entirely. |
| 4 | NVENC concurrent-session cap source | **Hardcoded 3** in `EncoderMeta` for Slice C v1 | Detecting actual cap requires either an SDK call (no Python binding) or trial-and-error session creation. v2 can detect-by-failing. |
| 5 | Fallback chain default (when none configured) | **`[active_encoder, libx264]`** | Two-element chain with software fallback — minimal surprise for existing installs. Operator opts in to richer chains via Slice C's UI. |
| 6 | Mobile encoder-info chip surface | **Long-press title** + pause-overlay footnote | Avoids cluttering the playing UI; operators who care will find it. |
| 7 | Slice C scope: integrated-GPU fallback when discrete is saturated | **Yes** — handled naturally by chain ordering | The operator orders `[h264_nvenc, h264_qsv, libx264]`; QSV uses iGPU. No special "iGPU mode" needed in code. |
| 8 | Backwards compatibility: existing `transcoding_encoder` field | **Kept** as the chain's first element when chain is null | No-op migration; existing PATCH calls continue to work. |
| 9 | Recommendation banner persistence | **Per-session dismiss** (re-evaluate on every Settings open) | Sticky-dismiss would let an operator silence a critical "Failed self-test" warning forever. Re-evaluation is cheap. |
| 10 | Self-test re-trigger frequency | **On settings change + manual** ("Re-test all" button) | Driver updates + hardware swaps need a manual re-test; auto-re-test on every server start would slow startup unnecessarily. |

**Pending decisions (need owner answer):**
- Is integrated-GPU fallback **on by default** (chain auto-populated `[active, iGPU_qsv, libx264]`), or **off by default** (operator opts in via the priority list)? Default OFF is safer (existing behaviour unchanged); default ON is friendlier (out-of-the-box fallback for free).
- Should `/api/v1/transcoding/devices` be **bearer-required** (rich device info could be considered system metadata) or **localhost-only** (matches the rest of `/transcoding/*`)? Default: localhost-only — the desktop is the only legitimate caller.

---

## 5. NOT doing in this plan (out of scope)

- **CPU-load-based fallback** (e.g. "if CPU > 80%, prefer NVENC"). Too noisy — the LRS load average jumps with every scan. Slice C orders by encoder availability, not real-time load.
- **Per-stream encoder override from mobile.** A client picking "force CPU because my client decoder is broken" is a tier-2 feature; the desktop control panel is the source of truth in v1.
- **Cross-machine encoder pooling** (offload transcoding to a different server). Out of scope until v3 multi-node clustering.
- **Encoder benchmarking suite** (run all encoders against a 30-second test pattern, score throughput, recommend by score). Slice A's `encoder_test_passed` is a binary pass/fail; richer benchmarking can land later if the per-encoder recommendation needs more nuance.
- **Real-time GPU-load graph in the desktop dashboard.** Slice B exposes `gpu_utilization_percent` per probe call (already wired); a graph would need WebSocket streaming + a charting library. Defer to a separate UI polish round.
- **Slice C without first shipping Slices A + B.** The fallback panel needs the active-encoder display + hardware card to be useful — without those, fallback events are abstract numbers.

---

## 6. Cutover ritual (per slice)

**Each slice ends with the same checklist:**

1. **Server tests green** — `pytest` from `apps/server/` (current baseline 274; Slice A adds ~7, Slice B adds ~6, Slice C adds ~10).
2. **Desktop analyze + tests green** — `flutter analyze` + `flutter test` from `apps/desktop/`.
3. **Manual smoke test on the user's actual machine.** Walk through: open Settings → Streaming → confirm the active encoder strip reflects what's running; pick a Failed encoder → confirm the modal fires; pick a working encoder → confirm session count updates after a stream starts.
4. **Doc round** — update `docs/04_api/01_api_contracts.md` (every new endpoint), `docs/05_infrastructure/02_url_inventory.md`, `docs/09_backend/02_hardware_acceleration.md` (advisor algo / chain schema / probe coverage), `docs/00_overview/current_status.md` (test counts + slice marker), `docs/12_guidelines/03_gotchas.md` (any sharp edges discovered), `docs/10_planning/01_roadmap.md` (slice marked ✅).
5. **AGENT_LOG entry** — files modified, decisions made, blockers, suggested next steps.
6. **No commits** until the owner approves — Hard Prohibition #1.

---

## 7. Pre-flight checks (before writing any code)

- Confirm `_TEST_RESULTS` migration is safe — Slice A changes the type from `dict[str, bool | None]` to `dict[str, EncoderTestResult]`. Search for every reader to make sure nothing depends on the old shape.
- Verify the desktop's existing `TranscodingStatusCubit` polls every 2s and won't get rate-limited by the new `/advisor` call (it doesn't poll advisor — the advisor is fetched on Settings open + on dropdown change).
- Confirm the Windows `wmic` parser handles GPUs with non-ASCII names (e.g. Korean / Japanese OEM displays). UTF-8 decode with `errors='replace'` is the safe default.
- Verify the `nvidia-smi` JSON output is stable across driver versions in the lab matrix. (Newer drivers add fields; stripping unknown fields client-side is the contract.)
- Ensure the server's `encoder_advisor.py` returns a deterministic recommendation when *no* hardware is present — should always be `libx264` with `reason_code: cpu_only`.

---

## 8. Suggested execution order

If the owner greenlights all three slices, the recommended order is:

1. **Slice A first.** Highest value-per-hour. Surfacing the existing data unlocks the diagnostic conversation that informs Slices B + C.
2. **Slice B second.** The hardware card is the foundation for the VAAPI device picker AND Slice C's chain UI (the "available encoders" list).
3. **Slice C last.** Largest engineering, requires both prior slices for its UI to make sense.

If only one slice ships, **Slice A** alone is worth shipping — it removes the entire "configure encoder blind, ship a stream, watch CPU spike" feedback loop.

---

## 9. Open questions

- **Slice C — when do we declare the chain "good"?** The user could configure a chain with three failed encoders. Do we hard-block save (force at least one tested-passing entry)? Default: yes.
- **Slice B — should the desktop poll `/transcoding/devices` or fetch once?** Hardware doesn't change at runtime; once is correct, but a "Re-detect" button is friendly for operators who hot-plug eGPUs. Default: fetch once + manual "Re-detect" button.
- **Slice A — recommendation banner copy review.** Three rule banners are draft; the user should approve copy before implementation. Sample: "You're transcoding on CPU. NVIDIA GPU detected — switch to `h264_nvenc` for ~10× faster transcoding." (Tone matches existing notifications: factual, suggests action, no marketing fluff.)
- **Mobile encoder chip — long-press title or always-visible footnote in the pause overlay?** Long-press is more discoverable for power users; pause-overlay is more visible. Default: pause-overlay (cheap to render; helps the operator confirm at a glance).

---

## 10. Locked once owner approves

1. Slice A approval = green light to start. Implement → tests → doc round → AGENT_LOG → owner reviews diff.
2. Slice B approval = green light *after* Slice A ships. Implementing in parallel risks merge conflicts in `transcoding_service.py` + the desktop's Streaming tab.
3. Slice C approval = green light *after* Slices A + B ship. Slice C's UI sits on top of B's hardware data.
4. Decisions §4 are locked at approval; any change after triggers a plan amendment, not a silent code change.

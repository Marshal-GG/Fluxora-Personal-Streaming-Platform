# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_09.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 08)
**Archived:** 2026-05-07
**Contents:** Streaming-pipeline overhaul (4-commit remediation against the seek/HDR/zombie/peg regressions) · Library + TMDB hardening · Cosmetic redesign follow-ups (F1–F10 from §11.1) · Help/Settings audit · Reachability hardening · Legal docs from scratch + Inno Setup installer + 15-finding edge-case audit · Encoder benchmark from zero to a full operator surface (history, sidebar, live progress, gradient bar, fps + resolution selectors, cap-verification probe) · Ruff cleanup + F9 Profile Sessions tab.

* **Streaming-pipeline plan + 4 commits (2026-05-05).** Triggered by 4 user-reported regressions during 2026-05-05 UAT (seek-ahead unusable, HDR→SDR "code error 1", GPU/CPU peg, washed-out HDR). Full audit in [`docs/10_planning/11_streaming_pipeline_issues.md`](docs/10_planning/11_streaming_pipeline_issues.md). All 4 commits shipped same-day: Commit 1 (tonemap unblock + diagnostic upgrade — per-pipeline `playlist_timeout_sec` 60/30/10s + `killed_after_timeout` flag + `-loglevel warning` on transcode); Commit 2 (server-side seek-restart — new `POST /stream/{sid}/seek` + `restart_stream` with per-session `asyncio.Lock` + segment numbering shift + `#EXT-X-DISCONTINUITY` markers); Commit 3 (mobile player wire-up — `seekTo()` threshold-based dispatch with 5 s forward-seek floor + 300 ms debounce + `_SeekingOverlay`); Commit 4 (zombie cleanup + `(client_id, file_id)` dedup + progress-write debounce + log rotation regression-test pin). Also adjacent: library corrupt-path defenses (validator + migration 022 + duration backfill); encoder failure classifier (3 → 4 patterns recognised: QSV old driver, no Intel iGPU, NVENC GeForce session cap, hevc_qsv unsupported encoder block) + desktop notification surfacing.
* **TMDB ISP-block workaround (2026-05-06).** Three layers of mitigation for end users behind ISPs that block TMDB. Triggered by Reliance Jio India returning a sinkhole IP. Layer 1: filename-stem cleanup (`_clean_tmdb_query` + `_TRAILING_SCENE_NOISE` regex). Layer 2: DoH override (`utils/dns_override.py` monkey-patches `socket.getaddrinfo` against Cloudflare's `1.1.1.1` anycast). Layer 3: Cloudflare Worker reverse proxy (`fluxora-tmdb-proxy.marshalgcom.workers.dev`) configurable via `FLUXORA_TMDB_BASE_URL` env var. Field-confirmed working on Jio. Library polish + `POST /api/v1/library/{id}/enrich-tmdb` Rescan TMDB endpoint + new desktop "Rescan TMDB" action tile.
* **§11.1 cosmetic redesign follow-ups (2026-05-06 → 2026-05-07).** F1 (Active Streams stat tile from `SystemStatsCubit`); F2+F3 (Clients screen IP column from migration 023 `clients.last_ip` + per-request heartbeat + `auth_service.list_clients` LEFT-JOIN with `stream_sessions WHERE ended_at IS NULL`); F5 (`url_launcher` external-link wiring on Help screen); F6 (`POST /api/v1/info/support-bundle` localhost-only — gzipped tar with metadata/stats/encoders/redacted-settings/schema-DDL/logs); F7 (5 Material `AlertDialog`s in Groups screen → `FluxGlassDialog` — primitive already shipped, audit's "build a new primitive" assumption was wrong); F8 (Subscription manage tab `_ActionRow` → Polar portal); F9 Sessions subset (revoke session + sign out everywhere + 5 s auto-refresh — Danger Zone deferred for compliance scope); F10 (Encoder Settings → Run Benchmark, full operator surface).
* **Help/Settings audit pass A1–A13 (2026-05-06).** A1–A7 user-flagged surfaces (Help link `HitTestBehavior.opaque` + snackbar feedback + hover tint, Settings → About `_AboutProductCard`, "View Issued Licenses" → `/subscription`, Server URL relabel "Control Panel Connection URL", Custom Server URL relabel "Custom Public URL", `/info` precedence fix `custom_server_url > FLUXORA_PUBLIC_URL`). A8–A13 deeper bugs (`SettingsCubit` `loadSettings`/`saveSettings` extended with all 13 §7.10 fields — M6's claim was previously stale; `_NetworkTab` flattened from Stateful → Stateless; `_SystemInfoCard` reads `SystemStatsCubit` via `context.select`; Max Concurrent Streams chipped via `FluxChip` + `Tooltip`; `_aiSegmentCtrl` / `_sessionTimeoutCtrl` reseat from state; Help screen URL fix to canonical `Marshal-GG/Fluxora-Personal-Streaming-Platform`). 3 new gotchas around Dart 3 records + Stateful→Stateless conversion + flat-with-nullables vs sealed-union `SystemStatsState`.
* **Reachability hardening (2026-05-06).** 3s/10s desktop Dio timeouts (was 30s — long stalls when server is unreachable felt like crashes); `/healthz` Test button on Settings → Advanced; **`emit`-after-`close()` guards on all 16 desktop cubits** — audit found that route-pop disposes cubits while in-flight requests resolve later, throwing `Bad state: Cannot emit new states after calling close`. 2 new gotchas. Server suite 488 → 488 (no behavioural change, hardening only).
* **Legal docs from scratch + Inno Setup installer (2026-05-06).** Six legal documents at repo root (`LICENSE` MIT, `PRIVACY.md` ~280 lines GDPR+CPRA+DPDP, `TERMS.md` ~370 lines Free vs paid + INR pricing + 14-day refunds + Delhi jurisdiction, `SECURITY.md` 72h/7d/90d SLAs, `CODE_OF_CONDUCT.md` project-scaled, `NOTICE` third-party attributions). All emails point at `*@fluxora.marshalx.dev` via Cloudflare Email Routing. **Inno Setup installer**: `installer/Fluxora.iss` (570 lines), `BUILD.md` (mechanical pipeline), `SHIP.md` (22-blocker checklist — 3 hard server code fixes + 5 infra items + 5 external-service configs + 3 doc gaps + 4 smoke tests), `AUDIT.md` (15-finding edge-case audit). All 8 critical+high-severity audit findings fixed in the .iss in this pass. 4 new gotchas around `sc.exe stop` async / `reg.exe REG_MULTI_SZ \0` brittleness / Inno Setup repair UI / ProgramData ACL.
* **Encoder benchmark from zero to a full operator surface (2026-05-07).** F10 ship: `services/benchmark_service.py` runs synthetic `lavfi testsrc` encode through every detected encoder sequentially with 35 s ceiling each. Tier 1 enrichment: switched stderr from tempfile to streamed PIPE for `init_ms` measurement (timestamps first `frame=N≥1` line); midpoint GPU probe per hw encoder for `gpu_utilization_percent` + `vram_used_mb`; surfaced `concurrent_session_cap` from registry; computed `recommended_concurrent`. Switched output mux from `-f null -` to `-f mpegts -` (the muxer discards before measuring, so `bitrate=N/A`). Marker-aware `_pick_error_line` walks stderr for `error`/`failed`/`unsupported`/... before falling back to last line (was grabbing FFmpeg's input header banner). UX maturation: history persistence (migration 024 + `services/benchmark_history_service.py` + auto-prune to 50); 280-px sidebar with Recent Runs list ("Today HH:MM" / "Yesterday HH:MM" formatter, hover-revealed delete); fps selector (24/30/60); resolution selector (720p/1080p/4K with `clamp_resolution` snap); concurrent-cap verification probe (`probe_concurrent_cap` spawns `max(8, registry_cap*3)` parallel encodes — empirical truth for patched/RTX-40/driver-530+ setups vs the registry's documented 3); live progress feedback (module-level `_progress: dict | None` + `GET /transcoding/benchmark/progress` polled every 500 ms + `_BenchmarkProgressCard` with violet `_GradientProgressBar` painting `AppGradients.progress` #8B5CF6 → #A855F7); back-button bugfix (mounted-guarded `_setHover` + `canPop` fallback). `FluxTabBar` cosmetic fix (`mainAxisSize.min` → unspecified so divider extends full-width; `bottom: 16` padding dropped so active underline overlaps divider). 27 new server tests; suite **488 → 565 passing**. Migration 024.
* **Ruff cleanup + F9 Sessions tab (2026-05-07).** 34 ruff violations across 13 server files → 0 (16 auto-fixes for I001/F401/UP035 + 18 manual E501 line wraps; pure formatting). F9 Profile Sessions tab fully wired: tab-scoped `ClientsCubit` + `_activeSessions(clients)` filter to approved+trusted + per-row revoke + bulk "Sign Out All Devices" sequential revoke behind `FluxGlassDialog` confirm. Hardcoded "This device" row dropped (desktop CP is localhost-only, never pairs). Auto-refresh: new `ClientsCubit.refreshSilent()` re-fetches without flickering through `ClientsLoading`, preserves `filter` + `processingIds`, swallows errors silently; `_SessionsTabBody.initState` starts a 5 s `Timer.periodic` calling it. Tests +6 (refreshSilent happy path / filter preserved / processingIds preserved / no-op-when-not-loaded / no-op-on-failure-state / errors-swallowed); 17 → 23 in `clients_cubit_test.dart`. Danger Zone (delete account / export data) deferred for compliance scope. New gotcha: polling cubits need a silent-refresh path or the UI flickers every tick.

**Test counts at archive time (2026-05-07):**
- Server: **565 passing** (351 → 415 → 421 → 438 → 474 → 477 → 486 → 488 → 508 → 522 → 530 → 538 → 559 → 565 across the archive's spans)
- Mobile: **45 passing** (41 → 45 in Streaming Commit 3)
- Desktop: **84 passing** + the new clients_cubit `refreshSilent` cases (clients_cubit file: 17 → 23)
- Core: **8 passing** (unchanged)

**Migrations at archive time:** 001 → **024** (`benchmark_history.sql` is latest; 022 corrupt-path cleanup, 023 `clients.last_ip`, 024 `benchmark_runs`).

**Status of redesign §11.1 follow-ups at archive time:**
- ✅ F1 (Clients Active Streams stat tile) · ✅ F2 (Clients IP column) · ✅ F3 (Clients active-session join) · ⏸ F4 (deferred — Settings 19th column, no consumer) · ✅ F5 (Help external links) · ✅ F6 (support bundle) · ✅ F7 (Groups FluxGlassDialog) · ✅ F8 (Subscription portal action) · 🔵 F9 (Sessions subset shipped 2026-05-07; Danger Zone deferred) · ✅ F10 (Encoder benchmark — full operator surface).

**Next Immediate Steps (carried forward from archive 08):**
1. **Smoke-test F9 + benchmark on the user's box.** Pair 2-3 mobile devices (or curl `POST /auth/request-pair` + `POST /auth/approve/<id>`); open Profile → Sessions; verify auto-refresh surfaces a fresh pair within 5 s; verify single + bulk revoke flows. For benchmark: open Encoder Settings → Benchmark; click Run Benchmark; verify gradient progress bar grows smoothly + sidebar populates with the new run.
2. **F9 Danger Zone (delete account, export data)** if compliance scope is decided. Profile screen `_DangerTab` rows ([profile_screen.dart](apps/desktop/lib/features/profile/presentation/screens/profile_screen.dart)) get wired the same way Sessions did. "Reset All Preferences" is the smallest safe one (PATCH `/settings` with defaults) and could ship independently of the GDPR-DSR work.
3. **Installer hard blockers** — three small server-side code patches gating the v1 ship: `FLUXORA_DATA_DIR` env var in `config.py`, `FLUXORA_FFMPEG_BIN` env var + Nuitka frozen detection in `ffmpeg_service.py`, `if __name__ == "__main__"` Nuitka launcher in `main.py`. Tracked in [`docs/10_planning/04_manual_tasks.md`](docs/10_planning/04_manual_tasks.md). Each ~30 min; without them the first installer ships a service that exits in <1 s.
4. **Tier 2 benchmark axes** (resolution-tier matrix in one click, bitrate-target CBR mode, concurrent-stress test). Same UI shell, additive server changes.
5. **Pre-existing failure flagged 2026-05-06**: `m3_dashboard_golden_test.dart` fails 62.77 % pixel diff against stored baseline (Dashboard untouched in the F2/F3 batch — likely V2 cutover drift). Baseline needs regenerating; not blocking.
6. **Streaming Slice D candidates (carried from archive 07 → 08, still open)** — hardware tonemap on RTX 30+, libdav1d-enabled FFmpeg bundle, per-codec NVDEC capability matrix surfaced in `DetectedHardwareCard`.

---

<!-- New session entries go below this line. -->

## [2026-05-07] — Tier 2 benchmark axis: resolution-tier matrix mode
**Phase:** Phase 5 — encoder benchmark UX maturation
**Status:** Complete

### What Was Done

Same-day continuation of the §11.1 F10 surface (encoder benchmark).  User asked for the Tier 2 axis chosen out of {resolution matrix / CBR mode / concurrent stress} and picked the matrix.  Single-select chip row reworked to multi-select; one click can now produce a per-encoder × per-resolution table comparing 720p / 1080p / 4K throughput.

#### Server

- **`BenchmarkRequest`** (`routers/transcoding.py`): new `resolutions: list[ResolutionTuple] | None` field additive to the existing `width` + `height`.  When set, takes precedence; when null/empty, the router falls back to clamping the legacy single pair.  `ResolutionTuple` is a tiny Pydantic model with `width: int = Field(ge=320, le=3840)` + `height: int = Field(ge=240, le=2160)`.  Backwards compat preserved — old clients passing `width: 1920, height: 1080` produce identical results.
- **`benchmark_service.clamp_resolutions(pairs)`** — new helper.  Snaps each `(w, h)` to the nearest known tier via `clamp_resolution`, then dedupes preserving first-occurrence order.  Operator submitting both `(1280, 720)` and `(1366, 768)` collapses to a single `(1280, 720)` so history rows stay clean.  Empty/None input falls back to `[(1280, 720)]` for single-resolution back-compat.
- **`EncoderBenchmarkResult`** (`benchmark_service.py` dataclass + `routers/transcoding.py` Pydantic): gains required `width: int` + `height: int` fields.  Each row self-describes its resolution — necessary because matrix runs produce N rows per encoder (one per resolution).  `_failed_result` helper extended to accept width/height; `benchmark_encoder` parses the input `size` string at the top and threads the dimensions into every result construction site.  `_with_verified_cap` preserves them across the cap-probe re-derivation.
- **`run_benchmark(encoders, *, resolutions: list[tuple[int, int]] | None = None, ...)`** reworked: signature replaces single `width`/`height` with `resolutions`.  Outer loop per-resolution, inner loop per-encoder.  Total pair count = `len(encoders) × len(resolutions)`.  Each iteration calls `benchmark_encoder` with the right `size` string + invokes the cap-probe (when enabled) at that exact resolution.  Resolution-outer ordering means the desktop sees results land in chunks of "all encoders at 720p, all encoders at 1080p, ..." which matches operator mental model better than encoder-outer would.
- **Module-level `_progress` schema** extended: `total_resolutions`, `current_resolution_index` (1-based), `current_resolution_width`, `current_resolution_height` — populated continuously through the run; single-resolution callers see `total_resolutions=1` and the index pinned at 1, so the desktop can read these unconditionally without a branch.
- **`BenchmarkResponse.resolutions: list[ResolutionTuple]`** echoes the tested list back to the client (operator-selection order preserved); top-level `width`/`height` stay populated as the *primary* (= first tested) tier so old clients that don't know about `resolutions` keep rendering the primary tier.
- **`BenchmarkProgress`** Pydantic mirrors the new `_progress` fields.  Matrix-aware desktop reads them; idle-state response (`running=False`) leaves them all null.
- **`BenchmarkHistoryEntry.resolution_count: int = 1`** new field.  Derived server-side in `benchmark_history_service.list_benchmark_runs` by parsing each row's `results_json` once and counting distinct `(width, height)` tuples.  Defaults to 1 so legacy rows (no per-row width/height in their stored blob) collapse to the historical "1080p · 30 fps · 6 enc" sidebar caption; matrix runs render "3 res · 30 fps · 18 enc" instead.  Cost: parsing 50 ~5 KB blobs is sub-ms; not worth a denormalized column + migration.
- **`benchmark_history_service.get_benchmark_run`** back-fills per-row width/height from the run's primary dimensions when reading legacy rows that pre-date matrix mode — desktop entity expects the field unconditionally and would otherwise fail JSON parse.  New rows already carry per-row dimensions and pass through unchanged.
- **`get_benchmark_run` also returns `resolutions: list[tuple[int, int]]`** derived in-order from the JSON blob's distinct tuples.  Used by the history-by-id router to populate the response's `resolutions` echo for stored runs.
- **Router `run_benchmark`** rewritten: builds the resolution list with `body.resolutions or [single fallback]`, threads through to the service, persists `primary_width`/`primary_height` (= `resolutions[0]`) for back-compat with the existing schema, and constructs the response with the full `resolutions` list + per-row width/height.  Logs include resolution count.
- **No migration** — schema unchanged.  Top-level `width`/`height` columns retain their meaning (= first tested tier).  Per-row dimensions live inside the existing `results_json` blob.

#### Core (`packages/fluxora_core`)

- **New `Resolution` freezed entity** in `entities/encoder_benchmark.dart`.  Tiny `(width, height)` DTO; freezed + json_serializable for uniformity with every other DTO in the surface.  Also makes the cubit-side body construction cleaner than hand-rolling Map<->record converters.
- **`EncoderBenchmarkResult`** gains required `width: int` + `height: int`.
- **`EncoderBenchmarkRun`** gains `@Default(<Resolution>[]) List<Resolution> resolutions` (defaulted so legacy responses without the field still parse — though all new server responses populate it).
- **`BenchmarkHistoryEntry`** gains `@Default(1) int resolutionCount`.
- **`BenchmarkProgress`** gains the four new matrix-mode fields (all nullable).
- Regenerated `.freezed.dart` + `.g.dart` via `dart run build_runner build`.

#### Desktop

- **`TranscodingRepository.benchmark`** signature: `width`/`height` → `resolutions: List<Resolution>?`.  Impl builds the request body with `resolutions` (falls back to legacy width/height only when caller doesn't pass a list — which the desktop UI never does post-Tier-2).
- **`ApiClient` receive timeout** dynamic: 12 minutes in matrix mode (more than 1 resolution), 6 minutes for single-resolution.  3 tiers × cap-probe + 4K + 60 fps can comfortably triple the worst-case wall-clock so the existing 6 min was tight.
- **`_ResolutionSelector`** widget reworked: parameter `selected: ({int width, int height})` → `selected: Set<({int width, int height})>`; callback `onChanged` → `onToggle`.  Each chip toggles its membership in the set.  Header copy + caption updated ("Source resolutions" / "Pick one or more — each runs sequentially through every encoder").
- **`_BenchmarkBlockState._selectedResolutions: Set<…>`** defaults to `{1080p}` so the first-run UX matches the prior single-resolution baseline (operators who don't care about matrix don't notice the change).  Set toggles via copy-and-mutate so `setState` sees a new identity.  Run button gated on non-empty.
- **Run sequence smallest-first** (`_resolutionOptions.where(_selectedResolutions.contains)`) — operator sees results land for the lighter workload before the heavier ones; 4K-first would have the desktop spinning silently for 30+ s before any rows appear.
- **`_BenchmarkResultsTable`** sorts within each vendor section by `(encoder name, resolution pixels)` so matrix rows read as `h264_nvenc[720p, 1080p, 4K]` then `hevc_nvenc[...]`.  Operators want to compare the same encoder across tiers, not all encoders at one tier.
- **`_BenchmarkResultRow.showResolutionChip`** new param.  Set to true by the table when `run.resolutions.length > 1`.  Renders a violet `FluxChip(_resolutionLabel)` (720p/1080p/4K/raw) next to the codec pill.  Off in single-resolution mode — the source caption already names the tier and per-row chips would just be noise.
- **`_SourceWorkloadCaption`** rewritten to take `resolutions: List<Resolution>` (was `width` + `height`).  Single-resolution renders the existing "Source: 1280x720 ..." form; matrix collapses to "Source: 720p, 1080p, 4K · 30 fps · 8 s synthetic clip" (tier list comma-joined).  Wrapped in `Expanded + ellipsis` so a long tier list doesn't overflow.
- **`_BenchmarkProgressCard._statusLine`** matrix-aware: tags the current encoder with its tier when `totalResolutions > 1` ("Encoding h264_nvenc [1080p]" / "Verifying h264_nvenc session cap [4K]").  `_captionLine` swaps "Encoder N of M" → "Step N of M  ·  Res P of Q" so the operator can track both axes.
- **`_HistoryEntryRow._resolutionLabel`** flips to "N res" caption when `widget.entry.resolutionCount > 1`.  Sidebar is 280-px wide; spelling out "720p, 1080p, 4K" would wrap awkwardly.

#### Tests

- **`tests/test_benchmark_service.py`** (+5 cases):
  - `test_clamp_resolutions_dedupes_after_snap` — `[(1280,720), (1366,768), (1920,1080), (3840,2160), (1920,1080)]` → `[(1280,720), (1920,1080), (3840,2160)]`.
  - `test_clamp_resolutions_falls_back_to_default_for_empty` — `None` and `[]` both return `[(1280, 720)]`.
  - `test_run_benchmark_matrix_produces_n_times_m_results` — 2 encoders × 3 resolutions = 6 results in resolution-outer × encoder-inner order; each result self-describes its resolution.
  - `test_run_benchmark_matrix_publishes_resolution_index_in_progress` — progress snapshots carry the right `total_resolutions` / `current_resolution_index` per pair; `total_encoders` tracks pair count, not encoder count.
- **`tests/test_benchmark_history.py`** (+2):
  - `test_history_entry_carries_resolution_count_for_matrix_run` — 6 results across 3 distinct tiers → `resolution_count=3`; `get_benchmark_run` returns `resolutions=[(1280,720), (1920,1080), (3840,2160)]` in operator-selection order.
  - `test_history_entry_resolution_count_defaults_to_one_for_legacy_rows` — 2 results all at 1080p → `resolution_count=1`.
- **`tests/test_transcoding.py`** (+2):
  - `test_benchmark_accepts_matrix_mode_resolutions_list` — POST with `resolutions: [...]` body; service receives the full list; response echoes; per-row width/height match.
  - `test_benchmark_resolutions_list_takes_precedence_over_width_height` — both fields set in body → list wins.
- All existing fixtures updated to thread width/height through `EncoderBenchmarkResult` constructions + the `_fake_run` mocks now accept `resolutions` instead of `width`/`height`.
- **Server suite 565 → 573 passing.**  `flutter analyze` clean across desktop + core (19.3 s desktop, 20.6 s core).  Desktop cubit tests still 23/23.  Ruff still clean.

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `apps/server/services/benchmark_service.py` (EncoderBenchmarkResult dataclass +width/height; benchmark_encoder parses size; _failed_result + _with_verified_cap accept width/height; run_benchmark signature `resolutions: list[tuple[int,int]] \| None`; outer/inner loop reworked; _progress schema extended; new `clamp_resolutions(pairs)` helper) |
| Modified | `apps/server/services/benchmark_history_service.py` (list_benchmark_runs derives `resolution_count` via `_count_resolutions`; get_benchmark_run back-fills per-row dimensions from primary + returns `resolutions` via `_distinct_resolutions`) |
| Modified | `apps/server/routers/transcoding.py` (new ResolutionTuple model; BenchmarkRequest.resolutions field; BenchmarkEncoderResult +width/height; BenchmarkResponse.resolutions echo; BenchmarkProgress matrix-mode fields; BenchmarkHistoryEntry.resolution_count; route handler builds the resolution list with precedence body.resolutions > legacy width/height > default) |
| Modified | `apps/server/tests/test_benchmark_service.py` (fixtures + 5 new matrix cases) |
| Modified | `apps/server/tests/test_benchmark_history.py` (`_result` helper accepts width/height; `_seed_run` builds matrix-shaped results; +2 new cases for resolution_count derivation) |
| Modified | `apps/server/tests/test_transcoding.py` (every `_fake_run` signature swapped width/height → resolutions; +2 new matrix-router cases) |
| Modified | `packages/fluxora_core/lib/entities/encoder_benchmark.dart` (new Resolution freezed entity; EncoderBenchmarkResult +width/height; EncoderBenchmarkRun.resolutions; BenchmarkHistoryEntry.resolutionCount; BenchmarkProgress matrix-mode fields) |
| Regenerated | `packages/fluxora_core/lib/entities/encoder_benchmark.freezed.dart` + `.g.dart` |
| Modified | `apps/desktop/lib/features/transcoding/domain/repositories/transcoding_repository.dart` (`benchmark` signature: width/height → `resolutions: List<Resolution>?`) |
| Modified | `apps/desktop/lib/features/transcoding/data/repositories/transcoding_repository_impl.dart` (sends `resolutions` body; dynamic timeout 6/12 min by mode) |
| Modified | `apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart` (`_ResolutionSelector` multi-select; `_selectedResolutions` Set state; sequential smallest-first walk; `_BenchmarkResultsTable` sorts by (encoder, resolution-pixels); `_BenchmarkResultRow.showResolutionChip` + violet tier pill; `_SourceWorkloadCaption` resolution-list aware; `_BenchmarkProgressCard` matrix-mode status + caption; `_HistoryEntryRow` "N res" caption when resolutionCount > 1) |
| Modified | `docs/00_overview/current_status.md` (new "As of 2026-05-07 (latest)" entry) |
| Modified | `docs/11_design/desktop_redesign_plan.md` (change-log entry) |
| Modified | `AGENT_LOG.md` (this entry) |

### Decisions Made

- **Additive `resolutions` over breaking the existing `width`/`height` API.** Old clients (third-party callers, smoke-test scripts) keep working — the router walks precedence `body.resolutions > body.width/height > server default`.  Cost is minimal (a 4-line precedence block in the route handler) and avoids a coordinated client rollout.
- **Resolution outer × encoder inner order.** Two equally-valid choices; chose resolution-outer because operator mental model is "first I want to see how everyone does at 720p, then move up the ladder".  Encoder-outer would show "h264_nvenc at every tier, then hevc_nvenc at every tier" — useful for some workflows but worse for the live-progress UX (operator sees all tiers cycle for one encoder before any other encoder shows up).  Documented in the run_benchmark docstring.
- **Smallest-first iteration order on the desktop.** The selector renders chips in canonical-tier order (720p → 1080p → 4K) regardless of click sequence.  Submitting in that order means lighter results land first; a 4K-first run would leave the operator staring at silence for 30+ s.
- **`resolution_count` derived on-the-fly, no migration.** Cost of parsing 50 results blobs once for the sidebar list is sub-ms.  Adding a denormalized column would require a migration, a backfill, and a coordinated server-restart — not worth it for a single integer surface.
- **Per-row resolution chip only in matrix mode.** Single-resolution mode already names the tier in the source caption; per-row chips would be redundant noise.  Chip uses `FluxChipColor.purple` (existing variant) so every "1080p" pill in the table shares the same visual identity, helping the operator's eye group rows by tier.
- **`_HistoryEntryRow` caption "N res" instead of full tier list.** Sidebar is 280 px wide; spelling out "720p, 1080p, 4K · 30 fps · 18 enc" wraps awkwardly.  Operators who want the full tier list click into the run — the source caption above the results table renders it.
- **Default selection is `{1080p}`.** Matches the prior single-resolution baseline so first-time UX is unchanged.  Operators who never touch matrix mode get identical behaviour to before; matrix is opt-in by selecting additional chips.
- **Receive timeout 12 min in matrix mode, 6 min single.** 3 tiers × cap probe + 4K + 60 fps can comfortably triple the worst-case wall-clock; a single-tier 6 min ceiling would time out client-side before the server finished a slow CPU's libx265 pass on 4K.

### Issues / Sharp Edges Discovered

- **U+202F NARROW NO-BREAK SPACE in `_SourceWorkloadCaption`'s string literal.**  The pre-existing caption used U+202F (narrow no-break space) between `$durationSec` and `s synthetic clip`.  Edit tool's exact-match couldn't paper over the unicode; had to use Python to do the replacement directly.  Worth flagging to future agents — the file may have other invisible whitespace in literal strings; treat replace-by-substring with care when the surrounding context contains punctuation.
- **`Resolution` freezed entity carries empty `@Default(<Resolution>[])` for `EncoderBenchmarkRun.resolutions`.**  Without this, parsing legacy responses (which don't have the field) blows up.  Same trick used elsewhere in the codebase but worth re-flagging since matrix mode shipped after most of the existing `freezed` patterns settled.
- **Backwards compat for legacy history rows requires per-row width/height back-fill on read.**  `EncoderBenchmarkResult` makes width/height required (no nullable, no default); old rows in `benchmark_runs.results_json` predate matrix mode and don't carry these.  Fix in `get_benchmark_run`: walk the parsed list and `setdefault('width', primary)` / `setdefault('height', primary)` before handing to Pydantic.  Decision documented inline.

### Hard Rules Checklist

- [x] No `git commit` / `git push` / `git add` performed.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No silent exceptions.  `_pollProgress` catch in the desktop is intentional (per-tick noise) and was already there pre-Tier-2.
- [x] No hardcoded secrets, ports, paths.
- [x] No new pip / pub deps.
- [x] No layer-boundary violations.
- [x] No git-history rewrites.
- [x] No edits to past migrations.
- [x] No raw SQL string concatenation.
- [x] No bearer tokens / PII logged.

### Proactive Suggestions for Next Work

- **Smoke-test matrix mode on the user's box** — pick all three tiers, run, verify (a) progress bar advances smoothly across all 3 × N pairs, (b) status line shows "Encoding h264_nvenc [4K]" mid-run, (c) results table shows per-row violet resolution chip, (d) sidebar caption flips to "3 res · 30 fps · 18 enc".
- **CBR mode** (Tier 2 row 2) — `BenchmarkRequest.bitrate_kbps`; FFmpeg switches from `-crf 23` to `-b:v {kbps}k -maxrate {kbps}k -bufsize {2*kbps}k`; result fields gain `bitrate_target_met: bool`.  Same UI shell + an extra knob.
- **Concurrent stress test** (Tier 2 row 3) — extends `probe_concurrent_cap` from survivor counting to per-N throughput measurement (fps + bitrate at N=1, 2, 3, ...).  Surfaceable as a chart in the progress card.
- **Installer hard blockers** — three small server-side patches still gate the v1 ship (config.py FLUXORA_DATA_DIR, ffmpeg_service.py FLUXORA_FFMPEG_BIN + Nuitka frozen detection, main.py __main__ launcher).  Specs in `installer/SHIP.md` §3.

### Next Agent Should

- **Smoke-test matrix mode** — the user's hardware (i7-9750H + integrated UHD 630 + occasional NVENC) is a great test bench since it exercises software + Intel + occasionally NVIDIA all at once.  Three-tier run should take ~3-5 minutes; watch for the progress card flickering or sticking, and confirm the history sidebar entry shows "3 res" + clicking it surfaces the full tier list in the source caption.
- **If results table cramps at narrow widths** — the new violet resolution chip adds ~50 px per row; the encoder-name + codec-pill row was already tight on small windows.  May need a second-line layout for matrix rows on <1280 px wide windows.  Not blocking; bring up if the user's screenshot shows wrapping.
---

## [2026-05-07] — Groups remediation plan written + M1 (restriction editing) shipped
**Phase:** Phase 5 — Client Groups feature completion
**Status:** Complete (M1 only; M2–M5 planned for future sessions)

### What Was Done

User reported "groups are unusable currently" and asked for a detailed plan.  Audit confirmed: backend solid (migration 011 + `group_service.py` + stream-gate at [`stream.py:100-107`](apps/server/routers/stream.py#L100)) but desktop create/edit dialogs only collect name + description, so every group ships with `restrictions = null` and the gate has nothing to deny.  Plan written, then M1 shipped same-day.

#### Plan written: [`docs/10_planning/12_groups_remediation_plan.md`](docs/10_planning/12_groups_remediation_plan.md)

Nine-section doc modelled on [`11_streaming_pipeline_issues.md`](docs/10_planning/11_streaming_pipeline_issues.md) — executive summary, current architecture (data model + stream-gate flow + key files + restriction enforcement matrix), defects (6 UI-side + 4 server-side deferred), 5-milestone remediation plan with code targets per milestone, test strategy, risks, out-of-scope, cross-references.  Cross-refs added to [`01_roadmap.md`](docs/10_planning/01_roadmap.md), [`05_ship_readiness.md`](docs/10_planning/05_ship_readiness.md), and [`CLAUDE.md`](CLAUDE.md) "Where the detail lives" table so future agents discover the plan from the index.

#### M1 shipped — restriction editing

**Desktop** ([`groups_screen.dart`](apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart)):

- New shared `_GroupRestrictionsForm` widget — owns local toggle + value state for time window + library allowlist; calls `onChanged` whenever any field changes so the parent dialog can hold the assembled `GroupRestrictions?` for its Confirm handler.  Single widget reused by both Create and Edit dialogs (DRY over per-dialog duplication).
- New `_TimeWindowPicker` — start/end `_HourField`s (chevron up/down stepper, 0-23 wrap-aware via `(value + 1) % 24`) + 7-chip day-of-week multi-select.  Day order matches Python's `datetime.weekday()` convention (0=Mon … 6=Sun) used server-side; reordering would silently break the gate.  Live preview caption via new `_formatTimeWindow` helper handles common patterns ("All week", "Mon-Fri", "Weekends") and falls back to comma-joined day abbrevs for arbitrary sets.  Renders a midnight-wrap warning when `endH <= startH` ("Window wraps midnight — 22:00 to 06:00 next day"), plus a timezone note ("Times are evaluated in the server's local timezone") per §4.3 of the plan.
- New `_LibraryAllowlistPicker` — multi-select chip row over `widget.libraries`.  When the operator toggles "Restrict to specific libraries" on with an empty selection, pre-selects all libraries so the gate doesn't immediately deny every stream (the operator has to actively *un*-tick what they want gated).  Empty libraries list renders an explanatory placeholder instead of a blank wrap.  "${selected.length} of ${libraries.length} libraries allowed" caption.
- New `_AdvisoryFieldsSection` — bandwidth-cap + max-rating placeholders.  Both rendered as `enabled: false` `TextField`s with `Tooltip`s citing §4.1 and §4.2 of the plan.  Honest UX: operator sees the surface exists for forward-compat without us pretending it works.
- New `_SectionToggleHeader` — icon + label + right-aligned `FluxSwitch` row used as the header for each restriction subsection.  Keeps the dialog vertically compact.
- `_CreateGroupDialog` rewritten — embeds the form + intro caption ("All restrictions are optional.  Combined across every group a client belongs to (most-restrictive wins)."); width bumped 420 → 460 to accommodate the picker; wrapped in `SingleChildScrollView` so long restriction sets don't overflow on small windows.
- `_EditGroupDialog` rewritten — hydrates the form from `widget.group.restrictions` so existing values are preserved; gains a status `FluxSwitch` row above the restrictions form ("Active · restrictions enforced" ↔ "Inactive · restrictions not enforced").  Server gate already filters `WHERE g.status = 'active'` so the toggle takes effect on the next stream-start.
- `_GroupDetailPanel` updated — (a) time window now formatted via the same `_formatTimeWindow` helper the picker uses, so the dialog preview and panel summary render identically; (b) `allowedLibraries` ids resolved → names via the cached library catalog (chips read "Movies, TV" instead of two opaque UUIDs); falls back to the raw id when a library was deleted post-tag.

**Cubit** ([`groups_cubit.dart`](apps/desktop/lib/features/groups/presentation/cubit/groups_cubit.dart)):

- Constructor now takes a `LibraryRepository` alongside `GroupsRepository`.
- New `_safeLoadLibraries()` helper — fetches libraries best-effort, returns empty list on failure with a warn-level log.  Failures must NOT block the groups load itself — that's the whole point of best-effort.
- `load()` reworked to `Future.wait([_repository.list(), _safeLoadLibraries()])` — parallel fetch keeps the initial paint snappy.
- `GroupsLoaded.libraries: List<Library>` exposed for the dialogs + detail panel to consume via the existing `BlocBuilder`.

**State** ([`groups_state.dart`](apps/desktop/lib/features/groups/presentation/cubit/groups_state.dart)):

- `GroupsLoaded` gains `libraries: List<Library> = const []` field + extended `copyWith`.

**Server tests** ([`tests/test_groups.py`](apps/server/tests/test_groups.py)):

- `test_create_then_get_round_trips_full_restrictions` — POST a group with every restriction field populated (`allowed_libraries`, `bandwidth_cap_mbps`, `time_window`, `max_rating`), then GET it and assert byte-for-byte round-trip.  Pins the wire format the desktop M1 dialogs send.  Catches any future serialisation regression that drops a field.
- `test_update_group_status_to_inactive` — POST a group (defaults to active), PATCH `{status: "inactive"}`, assert response, PATCH back to active, assert.  Pins the active↔inactive flip — a regression where status is silently dropped from the PATCH body would re-enable a paused group without the operator noticing.

#### Verification

- `flutter analyze` clean (lib/features/groups + full desktop tree).
- Server suite **573 → 575 passing** (+2 cases).
- No new pip / pub deps; no new server endpoints; no migrations.

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `docs/10_planning/12_groups_remediation_plan.md` (9-section plan: exec summary, architecture, 6 UI defects + 4 deferred server-side, 5-milestone remediation, test strategy, risks, out-of-scope, cross-refs) |
| Modified | `apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart` (new widgets: `_GroupRestrictionsForm`, `_TimeWindowPicker`, `_LibraryAllowlistPicker`, `_AdvisoryFieldsSection`, `_SectionToggleHeader`, `_HourField`, `_ChevronButton`; rewrote `_CreateGroupDialog` + `_EditGroupDialog`; updated `_GroupDetailPanel` for library-name resolution + matched time-window format; new `_formatTimeWindow` top-level helper) |
| Modified | `apps/desktop/lib/features/groups/presentation/cubit/groups_cubit.dart` (`LibraryRepository` injection, `_safeLoadLibraries`, parallel `Future.wait` load) |
| Modified | `apps/desktop/lib/features/groups/presentation/cubit/groups_state.dart` (`GroupsLoaded.libraries: List<Library>`) |
| Modified | `apps/server/tests/test_groups.py` (+2 cases: full-restrictions round-trip + status flip) |
| Modified | `docs/00_overview/current_status.md` (new "As of 2026-05-07 (latest)" entry covering M1 ship) |
| Modified | `docs/10_planning/01_roadmap.md` (Client Groups row flipped from "🔵 Backend done; UI decorative" → "🔵 M1 shipped; M2–M5 polish remaining" with details) |
| Modified | `docs/10_planning/05_ship_readiness.md` (polish-gaps row updated) |
| Modified | `docs/10_planning/12_groups_remediation_plan.md` (top-level status flipped to "🔵 In progress — M1 shipped"; M1 row marked ✅ + shipped-changes block prepended) |
| Modified | `CLAUDE.md` ("Where the detail lives" table gains pointer to the new plan) |
| Modified | `AGENT_LOG.md` (this entry) |

### Decisions Made

- **Single shared `_GroupRestrictionsForm` over per-dialog duplication.**  Both Create and Edit dialogs need the exact same picker tree; DRY is cheap and the form's state model (toggle on/off → null/value emit) is identical for both flows.
- **Pre-select all libraries on first toggle.**  When the operator toggles "Restrict to specific libraries" on, the picker pre-selects every library.  Reasoning: "I want to restrict" almost always means "I want to gate *some* libraries", not "I want to gate *every* library".  Starting empty would immediately deny every stream and confuse the operator.  They can untick what they want gated.
- **Bandwidth + max-rating disabled with tooltip, not hidden.**  Two reasons: (1) operators see the surface exists so the feature reads as "complete with future-tense items" rather than "missing"; (2) adding these fields later won't surprise anyone.  Tooltips cite §4.1 and §4.2 of the plan so anyone hovering can find out what's coming.
- **Status toggle on Edit only, not Create.**  Create defaults to active; nobody creates a group only to immediately pause it.  Edit gets the toggle for the "I want to disable this for the weekend" workflow.
- **Library catalog cached on cubit, not refetched per dialog.**  Libraries change rarely; refetching on every dialog open would add latency for no benefit.  Cubit fetches once on `load()`; dialogs read from `state.libraries`.  If the operator creates a new library mid-session, they'll need to close and re-open the Groups screen for the new library to appear in the allowlist picker — acceptable trade-off documented inline.
- **`Future.wait` parallel load over sequential.**  Saves ~100-200 ms on the initial Groups screen paint by overlapping the groups + libraries fetches.  Best-effort library load means a library failure doesn't block groups.
- **Day-of-week chips in Mon-Sun order, not Sun-Sat.**  Server's `_in_window` uses Python's `datetime.weekday()` (0=Mon).  Reordering the UI without reordering the server would silently break the gate; aligning them removes the trap.
- **Timezone note inline rather than a separate modal.**  The picker shows "Times are evaluated in the server's local timezone" as a quiet caption.  Operators in a single-house deployment never care; remote-paired-clients-across-timezones operators will notice the caption and know to factor it in.
- **No mobile UX work in M1.**  M5 (mobile 403 polish) is its own milestone in the plan because it touches the most-tested mobile surface and warrants its own focused review.  M1 is desktop-only.

### Issues / Sharp Edges Discovered

- **`Library` constructor needs explicit `LibraryType` import.**  My fallback `Library(...)` constructor for resolving deleted library ids → raw id required `LibraryType.movies` as a placeholder.  `LibraryType` lives in `package:fluxora_core/entities/enums.dart`, not in `library.dart` itself.  Easy fix once the analyzer flagged it.
- **Pre-existing static helper `_GroupDetailPanel._showAddMemberDialog` (the raw-UUID prompt) is still on `_GroupsLoaded`, not the panel itself.**  Confused me on first read — the "Add" link in the panel's header forwards via `_GroupsLoaded._showAddMemberDialog(context, group.id)`.  M2 will move it onto the panel for cleaner ownership.
- **`copyWith` on `GroupsLoaded` had to be extended for `libraries`.**  The existing `Group? Function()? selectedGroup` callback pattern (sentinel-via-function for nullable replacement) is unusual but I kept it as-is to match the file's style — `libraries` uses the simpler `?? this.libraries` since it's never set to null externally.
- **Dialog scroll behaviour.**  The original Create + Edit dialogs were short enough that a `Column(mainAxisSize: MainAxisSize.min)` was fine.  The new restriction form makes the dialog tall enough to overflow on small windows; wrapped in `SingleChildScrollView` to fix.

### Hard Rules Checklist

- [x] No `git commit` / `git push` / `git add` performed.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No silent exceptions.  `_safeLoadLibraries` catches deliberately + logs at warn level; documented inline.
- [x] No hardcoded secrets, ports, paths.
- [x] No new pip / pub deps.
- [x] No layer-boundary violations.  `_GroupRestrictionsForm` is presentation; consumes domain `LibraryRepository` through the cubit, never reaches into network code directly.
- [x] No git-history rewrites.
- [x] No edits to past migrations.
- [x] No raw SQL string concatenation.
- [x] No bearer tokens / PII logged.

### Proactive Suggestions for Next Work

- **Smoke-test M1 on the user's box** — open Groups → Create → name "Kids" → toggle "Restrict streaming time" → set 18:00-22:00 + Mon-Fri → toggle "Restrict to specific libraries" → tick only "Movies" → Save.  Verify: detail panel shows "Mon-Fri 18:00-22:00" + an emerald "Movies" chip.  From a paired tablet (member of "Kids"), try playing a TV show at 19:00 → server should return 403 with `detail: "Library not allowed for this client's group(s)"`.  Try playing a movie at 23:00 → 403 with `detail: "Outside the allowed streaming time window"`.
- **M2 — real client picker** is the most-requested next step (drops the raw-UUID paste).  ~3 hr per the plan.  Same pattern as the F9 Sessions tab landed earlier: scrollable list of approved + trusted clients with search, multi-select, sequential add.
- **M3 — Clients-screen cross-link** if the operator wants bidirectional editing.  Needs a small server-side change: extend `auth_service.list_clients` to include `groups: list[GroupSummary]` per client.
- **Tier 2 benchmark axes** (CBR mode, concurrent stress test) still open from earlier in the day if the user pivots back to that surface.
- **Installer hard blockers** still gate the v1 ship — three small server-side patches per `installer/SHIP.md` §3.

### Next Agent Should

- **Verify the picker UX feels right on the user's hardware** — the `_HourField` chevron stepper is the thing most likely to feel weird vs the operator's expectation (some users want a typed-input field; the chevron-only choice is deliberate to avoid validation hell on a 24-value range, but if it draws complaints, easy to swap to a `DropdownButton`).
- **Pick M2 next** unless the user pivots — the plan's milestone ordering puts M2 as the natural follow-up since it builds on the same dialog-pattern muscle.
- **Don't try to ship M2-M5 as a single chunk.**  Each is independently shippable and the plan is structured so they can land in any order; bundling would balloon the diff.
---

## [2026-05-07] — Groups M2-M5 shipped: feature fully usable end-to-end
**Phase:** Phase 5 — Client Groups feature completion
**Status:** Complete (all 5 milestones from `12_groups_remediation_plan.md` shipped)

### What Was Done

User said "continue" after M1 landed.  Powered through the remaining four milestones in plan order (M2 → M4 → M3 → M5 by execution sequence; M4 fit between M2 and M3 since it was trivial and kept fresh).  Groups feature is now fully usable end-to-end: operator configures restrictions, manages membership from either side (Groups detail OR Clients detail), filters the table, and the mobile player surfaces a soft "outside playback hours" card instead of a generic "stream failed".

#### M2 — Real client picker for Add Member

The raw-UUID `TextField` is gone.  New `_AddMemberDialog` widget in [`groups_screen.dart`](apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart):

- Fetches the operator's paired clients via `getIt<ClientsRepository>().getClients()` on dialog open.
- Filters to `status == approved && isTrusted` (so pending pair requests + revoked clients don't pollute the picker), then excludes any client already in the group via the new `existingMemberIds: Set<String>` constructor arg.
- Search box matches both name AND raw id (operators who really want to paste a UUID still can — but they no longer have to).
- Scrollable list with `_ClientPickRow` rows: 14×14 selection box (custom-painted; Material's `Checkbox` chrome doesn't match the glass dialog aesthetic) + platform icon + name + "Android · last seen 3h ago" caption + IP address.
- Multi-select via tap toggle.  Confirm button shows live count: "Add" (disabled when empty) → "Add 1 device" → "Add 3 devices".
- New `GroupsCubit.addMembers(groupId, List<clientIds>)` method — sequential walk; per-call failures swallowed with a warn-level log so one bad insert doesn't abort the rest of the batch.  Final `loadMembers(groupId)` once at the end (existing `addMember` reloads per call which is wasteful for bulk).
- Two distinct empty states: search-narrowed-to-zero ("No clients match…") vs nothing-to-pick-from ("Every paired device is already in this group." / "No paired devices.  Pair one from the Clients screen first.").

#### M4 — Filter chip on Groups table

Wired the disabled "Filter" button.  `_GroupsLoaded` widget converted from `StatelessWidget` to `StatefulWidget` (now `_GroupsLoadedState`) so it can hold filter state locally — kept the filter purely client-side because group lists are small in practice (handful per household).

- New `_GroupsSearchField` widget: compact dark-pill input with a search icon prefix.  Mirrors the Clients screen's `_SearchField` look so the two screens feel identical at the chrome level.  Matches both group `name` AND `description` so an operator who labelled a group via its description still finds it.
- New `_GroupsStatusFilter` widget: `PopupMenuButton` with All / Active / Inactive options.  Mirrors the Clients screen's `_FilterDropdown` pattern.
- Three empty states for the table: zero groups → onboarding "Create one to get started", filter active and zero matches → "No groups match your filters" + a "Clear filters" ghost button, populated → render filtered list.
- Stat tiles still read the unfiltered list so "Total Groups" doesn't lie when a filter is active.

#### M3 — Clients-screen cross-link

The biggest of the four.  Server-side change (extends `auth_service.list_clients`) + new Pydantic + freezed entities + Clients screen detail panel section.

**Server** ([`auth_service.py:list_clients`](apps/server/services/auth_service.py)):

- Extended SQL query with a LEFT-JOIN aggregating group memberships per client via SQLite's `json_group_array(json_object(...))`.  New `groups_json` output column carries a JSON array of `{id, name, status}` objects, NULL when the client is in no groups.  Single query, no N+1 — at home-server scale (handful of clients × handful of groups) the cost is negligible.
- New `GroupSummary` Pydantic model in [`models/client.py`](apps/server/models/client.py) (id, name, status — three fields, intentionally lighter than the full `GroupResponse` since the Clients screen never needs `restrictions` / `member_count` / timestamps).
- `ClientListItem.groups: list[GroupSummary] = []` — defaulted so any pre-M3 caller deserialising the response shape doesn't break.
- [`routers/auth.list_clients`](apps/server/routers/auth.py) parses `groups_json` defensively (malformed JSON → empty list with a warn log; never 500s the entire list call).

**Core** ([`group.dart`](packages/fluxora_core/lib/entities/group.dart) + [`client_list_item.dart`](packages/fluxora_core/lib/entities/client_list_item.dart)):

- New `GroupSummary` freezed entity mirroring the server shape.
- `ClientListItem.groups: List<GroupSummary> = const []` plus the hand-rolled JSON parser updated to walk the new field.

**Desktop** ([`clients_screen.dart`](apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart)):

- New `_ClientGroupsSection` rendered between the Active Session block and the Client Actions section in `_PopulatedDetailPanel`.  Only shown for `approved + isTrusted` clients — pending pair requests can't legally be in a group (server enforces via `group_members` FK + the existing add-member 404 path).  Header row: "Groups" + a violet `+` icon button.  Empty state: "Not in any group.  Click + to add this device to one."  Populated state: `Wrap` of `_ClientGroupChip`s.
- `_ClientGroupChip`: name + emerald/muted status dot + hover-revealed × that triggers a `FluxGlassDialog` confirmation before calling `getIt<GroupsRepository>().removeMember(groupId, clientId)`.  Hover-only removal affordance keeps the chip set scannable when the operator isn't actively trying to detach a client.
- `_PickGroupDialog`: fetches all groups via `GetIt<GroupsRepository>()`, filters to active only (inactive groups appear after the operator re-activates them on the Groups screen), excludes groups the client is already in.  Search + scroll list with `_PickGroupRow`s.  Returns a `GroupSummary` to the caller; the calling site fires `addMember` then `cubit.refreshSilent()` (with `cubit.load()` fallback so the panel updates silently without flickering through the loading state — uses the F9 silent-refresh pattern).
- Defensive `try { refreshSilent } catch { load }` because `refreshSilent` is the post-F9 method and a future agent who refactors `ClientsCubit` shouldn't need to touch the Clients-screen UI to keep this working.

**Tests** ([`tests/test_auth.py`](apps/server/tests/test_auth.py)):

- `test_list_clients_includes_group_memberships` — creates two groups, adds the paired client to both, asserts both surface in the response with the right `{id, name, status}` shape.  Pins the wire format.
- `test_list_clients_groups_empty_for_unaffiliated_client` — a client not in any group returns `groups: []`, not null/missing.  Lets the desktop read the field unconditionally.

#### M5 — Mobile 403 UX polish

The mobile player now distinguishes group-gate denials from generic failures.  Modelled tightly on the existing `PlayerTierLimit` precedent — same shape ("not an error, but you can't play this") so future agents reading the code see the parallel immediately.

- New `PlayerGated(reason: String)` state class in [`player_state.dart`](apps/mobile/lib/features/player/presentation/cubit/player_state.dart).
- `PlayerCubit.startStream` 403 routing in [`player_cubit.dart`](apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart) reworked:
  - 429 (`isTierLimit`) → `PlayerTierLimit` (existing).
  - 403 (`isForbidden`) AND message matches `_isGroupGateMessage` → new `PlayerGated(e.message)`.  Substring match against `'group(s)'` AND `'time window'` — distinctive markers from `services/group_service.reason_to_deny` that won't false-positive on unrelated 403s (e.g. an admin endpoint reached from off-loopback returns "Forbidden: localhost only").
  - Anything else → `PlayerFailure` (existing).
- New `_GatedView` widget in [`player_screen.dart`](apps/mobile/lib/features/player/presentation/screens/player_screen.dart) modelled on `_TierLimitView` but with parental-control framing:
  - Violet lock icon (vs the upgrade-prompt's gradient + premium icon).
  - Title heuristic: detect time-window vs library flavour from the reason text and pick a header that matches — "Outside playback hours" / "Not in your library access" / generic "Not available right now" fallback for any future server reason this client doesn't recognise.
  - Reason text rendered verbatim below as the body so the operator-set message reaches the kid.
  - Single "Got it" button → `Navigator.pop`.
- Tests in [`player_cubit_test.dart`](apps/mobile/test/features/player/player_cubit_test.dart): 3 new bloc-test cases pin the conservative match — library-deny → Gated, time-window-deny → Gated, unrelated 403 → Failure.  The third is the important one: stops a future agent broadening the matcher from accidentally classifying every 403 as a gate.

#### Verification

- Server suite **575 → 577 passing** (+2 cases in test_auth.py for M3).
- Mobile player suite **11 → 14 passing** (+3 cases for M5 403 routing).
- Desktop tree: `flutter analyze` clean.
- Mobile tree: `flutter analyze` clean.
- Core tree: `flutter analyze` clean.
- All M2-M5 work compiles without any non-info-level warnings.

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart` (M2: new `_AddMemberDialog` + `_ClientPickRow` replacing the raw-UUID modal; M4: `_GroupsLoaded` → `_GroupsLoadedState` conversion + `_filteredGroups` getter + `_GroupsSearchField` + `_GroupsStatusFilter` + three empty states + clear-filters action) |
| Modified | `apps/desktop/lib/features/groups/presentation/cubit/groups_cubit.dart` (M2: new `addMembers(groupId, List<clientIds>)` bulk method) |
| Modified | `apps/server/services/auth_service.py` (M3: extended `list_clients` SQL with `json_group_array` aggregation over `group_members`) |
| Modified | `apps/server/models/client.py` (M3: new `GroupSummary` Pydantic + `ClientListItem.groups` field defaulted to `[]`) |
| Modified | `apps/server/routers/auth.py` (M3: parse `groups_json` defensively, build `GroupSummary` list per row) |
| Modified | `packages/fluxora_core/lib/entities/group.dart` (M3: new `GroupSummary` freezed entity) |
| Regenerated | `packages/fluxora_core/lib/entities/group.freezed.dart` + `.g.dart` (`dart run build_runner build`) |
| Modified | `packages/fluxora_core/lib/entities/client_list_item.dart` (M3: `groups: List<GroupSummary>` field + JSON parser update) |
| Modified | `apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart` (M3: new `_ClientGroupsSection` integrated in `_PopulatedDetailPanel`; new `_ClientGroupChip`, `_PickGroupDialog`, `_PickGroupRow`; imports for GroupsRepository + Logger + FluxGlassDialog + group entities) |
| Modified | `apps/server/tests/test_auth.py` (+2 cases for M3 round-trip) |
| Modified | `apps/mobile/lib/features/player/presentation/cubit/player_state.dart` (M5: new `PlayerGated(reason: String)` state class) |
| Modified | `apps/mobile/lib/features/player/presentation/cubit/player_cubit.dart` (M5: 403 routing + `_isGroupGateMessage` helper) |
| Modified | `apps/mobile/lib/features/player/presentation/screens/player_screen.dart` (M5: `switch` case for `PlayerGated` + new `_GatedView` widget) |
| Modified | `apps/mobile/test/features/player/player_cubit_test.dart` (+3 cases for M5: library-deny / time-window-deny / unrelated-403) |
| Modified | `docs/10_planning/12_groups_remediation_plan.md` (top-level status flipped to ✅; M2/M3/M4/M5 sections all flipped to ✅ with shipped-changes blocks) |
| Modified | `docs/10_planning/01_roadmap.md` (Client Groups row flipped from "🔵 M1 shipped; M2-M5 polish remaining" → "✅ Done") |
| Modified | `docs/10_planning/05_ship_readiness.md` (polish-gaps row removed — Groups feature is done) |
| Modified | `docs/00_overview/current_status.md` (M2-M5 narrative prepended to today's "As of" entry) |
| Modified | `AGENT_LOG.md` (this entry) |

### Decisions Made

- **Powered through M2 → M4 → M3 → M5 in execution order, plan order in docs.**  M4 (the trivial filter chip) fit naturally between M2 and M3 to break up the larger M3 server-side work.  Made the diff easier to reason about during reviews — Clients-screen changes (M3) didn't get tangled with Groups-screen changes (M2/M4).
- **Sequential `addMembers` over `Future.wait`.**  M2 bulk-add walks the list in order so per-call failures stay logged sequentially and the final `loadMembers` reflects actually-applied state.  Same justification as the F9 Sessions tab's bulk-revoke pattern.
- **Per-row width/height was M1's; per-row `Resolution` was the matrix-mode shape.**  Don't confuse them — the Groups M3 `GroupSummary` is its own thing, intentionally lighter than the full `Group` entity.
- **`json_group_array` over a per-client follow-up fetch.**  M3 could have been done with a separate `GET /api/v1/auth/clients/{id}/groups` endpoint that the desktop calls per detail-panel-open.  The aggregation join is cheaper (single query, no N+1, sub-ms at home-server scale) and keeps the response self-contained — the desktop renders chips on the table list view too if a future agent wants that, without another fetch.
- **`GroupSummary` is its own type, not the full `Group`.**  Three fields (id, name, status) is what the Clients screen actually needs.  Reusing `Group` would force the join to fabricate `restrictions` / `member_count` / `created_at` / `updated_at` which the Clients screen doesn't display — wasted bytes + potential confusion.
- **Defensive `try { refreshSilent } catch { load }` in the M3 add/remove path.**  `refreshSilent` was added to `ClientsCubit` for F9 Sessions earlier this session.  A future agent refactoring `ClientsCubit` shouldn't have to touch the Clients-screen UI to keep this working — the fallback to `load()` is graceful (operator briefly sees the loading spinner; trade-off acceptable).
- **`PlayerGated` substring match is conservative.**  Two distinctive markers (`'group(s)'` AND `'time window'`); won't false-positive on unrelated 403s like "Forbidden: localhost only".  The third test case (unrelated-403 → Failure, not Gated) pins this — broadens-the-matcher refactors get caught in CI.
- **Mobile gate title heuristic over the raw server reason as the headline.**  The server emits "Library not allowed for this client's group(s)" — fine for ops logs, alarming as a kid-facing headline.  Title heuristic ("Outside playback hours" / "Not in your library access" / "Not available right now") frames the restriction without sounding like a permissions error; the raw server reason still shows verbatim as the body.
- **Inactive-only groups excluded from `_PickGroupDialog`.**  Adding to an inactive group is permitted server-side but the operator's intent is almost certainly to pick an enforcing group.  Inactive groups appear in the picker only after the operator re-activates them on the Groups screen.

### Issues / Sharp Edges Discovered

- **`json_group_array` returns NULL for clients with no group memberships, not an empty array.**  Easy trap — the router has to treat NULL as `[]` rather than passing it through to Pydantic which would reject the type.  Documented in the `auth_service.list_clients` docstring; defensive parsing in the router.
- **Multiple `// ignore: unused_import`-style warnings during incremental edits.**  When adding several new widgets that all need new imports, the analyzer flags the imports as unused until each widget is also written.  Mid-implementation noise; resolved as the work landed.  Worth flagging because future agents running an analyze-and-stop loop (instead of analyze-when-done) will see these and panic.
- **Stale IDE diagnostics for not-yet-defined types.**  When a new method/widget is referenced before the definition is added (e.g. `_GroupsSearchField` referenced at the call site before its class body landed at the bottom of the file), the IDE may report "method not defined" until the file is re-resolved.  CLI `flutter analyze` is the source of truth.
- **`Logger` import wasn't on `groups_screen.dart` even though `_log` was used elsewhere.**  Had to add `import 'package:logger/logger.dart';` for M2's add-member fetch error path.  Caught by analyzer immediately.

### Hard Rules Checklist

- [x] No `git commit` / `git push` / `git add` performed.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No silent exceptions.  M2's bulk-add catches per-call exceptions deliberately and logs at warn level so one bad insert doesn't abort the batch — documented inline.
- [x] No hardcoded secrets, ports, paths.
- [x] No new pip / pub deps.
- [x] No layer-boundary violations.  M3's add/remove path uses `getIt<GroupsRepository>()` from the presentation layer (well-established pattern matching the Library + Clients screens).
- [x] No git-history rewrites.
- [x] No edits to past migrations.
- [x] No raw SQL string concatenation.  M3's join uses a parameterized window function.
- [x] No bearer tokens / PII logged.

### Proactive Suggestions for Next Work

- **Smoke-test the full Groups workflow on the user's box** end-to-end:
  1. Create a "Kids" group → set time window 18:00-22:00 Mon-Fri → restrict to Movies library only → Save.
  2. Open Clients screen → click your kid's tablet → confirm the "Groups" section shows + a violet "+".
  3. Click "+" on Clients → pick "Kids" → confirm chip appears with emerald dot + name.
  4. From the tablet → try to play a TV show at 19:00 → mobile shows `_GatedView` with "Not in your library access" + reason "Library not allowed for this client's group(s)".
  5. Try to play a movie at 23:00 → `_GatedView` with "Outside playback hours" + reason "Outside the allowed streaming time window".
  6. Try to play a movie at 19:00 → succeeds.
  7. From Clients screen → hover the "Kids" chip → click × → confirm dialog → kid no longer gated.
  8. Search for "Kid" in the Groups table search box → "Kids" surfaces; switch status filter to Inactive → empty state with "Clear filters" button.
- **Tier 2 benchmark axes** still open from earlier in the day if the user pivots back: CBR mode + concurrent stress test.  Same UI shell, additive server changes.
- **Installer hard blockers** still gate the v1 ship — three small server-side patches per `installer/SHIP.md` §3.
- **Optional follow-ups for Groups** (deferred per §4 of the plan, not blocking):
  - Real `bandwidth_cap_mbps` enforcement (would need FFmpeg `-maxrate` injection per session, multi-day).
  - `max_rating` enforcement (needs `media_files.rating` column + TMDB-side or operator-tagged source + comparison ladder).
  - Timezone-aware time windows (currently server local; documented as a known limitation).
  - Mid-stream gate violation kills active sessions (currently only checked at start; requires a periodic sweep or push-based hook).

### Next Agent Should

- **Don't touch the gate-string substring match in `PlayerCubit._isGroupGateMessage` without updating the M5 test cases.**  The third test case (unrelated-403 → Failure, not Gated) is intentional and ships the contract.
- **If the operator wants a Group Activity log** (who's been gated, when, by which group), the existing `services/activity_service` already has the infrastructure — `record(type='stream.gated', summary=..., target_kind='group', target_id=...)` would slot in alongside the existing `stream.start` / `stream.end` events.  Out of scope for this remediation; flagged for future work.
- **Per the doc-update protocol, future agents touching `auth_service.list_clients` need to remember the `groups_json` aggregation join.**  The function signature didn't change (still returns `list[Row]`) but the columns the row carries did.  Documented in the docstring; reading it before extending is the safety net.
---

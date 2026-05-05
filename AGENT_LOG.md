# Fluxora — Agent Work Log

> **Rule for all agents:** Before ending any session, append a new entry at the **bottom** of this file using the template below.
> Never edit past entries. This log is append-only.
> **Log Rotation Policy:** If this file exceeds ~1000 lines, archive it (e.g. `docs/logs/AGENT_LOG_archive_08.md`), summarize its contents, and start a fresh `AGENT_LOG.md` with the summary at the top.

---

## Current State Summary (From Archive 07)
**Archived:** 2026-05-05
**Contents:** Full Phase 6 streaming pipeline build-out + GPU UX programme (Slices A/B/C) + desktop polish + mobile real-data backfill Phase B.

* **Mobile real-data backfill — Phase B (2026-05-04):** Continue-watching + Search + Profile stats endpoints landed; mobile Home Continue-watching rail + Search tab + Profile stats row all real-data-backed; `MockData.continueWatching` deleted; Downloads tab hidden in v1.
* **Desktop polish round (2026-05-04):** System Status recessed panel + tier-gated `UpgradeDialog` + full notifications audit (bell-dot wiring, `unread_only` → `unread` query-string fix, panel slide-in, mutation rethrows + SnackBar feedback, 500-cap on liveStream `seen` set); 13 new notifications-cubit tests (38 → 51 desktop suite).
* **GPU hardware acceleration (2026-05-04):** Full `EncoderRegistry` + `EncoderMeta` of 10 encoders across software/NVENC/QSV/VAAPI/VideoToolbox; per-encoder self-test (~1 s lavfi probe); per-vendor GPU monitoring probes (nvidia-smi / intel_gpu_top / radeontop / system_profiler).
* **GPU UX Slice A (2026-05-04):** Encoder advisor + active-encoder strip + recommendation banner + status panel; new `/api/v1/transcoding/advisor` endpoint; `EncoderTestResult` dataclass with `passed/error/tested_at`; desktop Settings → Streaming gains the three new widgets.
* **GPU UX Slice B (2026-05-04):** `services/hardware_probe.py` enumerates CPU + GPU per OS; new `GET /api/v1/transcoding/devices` endpoint; new `DetectedHardwareCard` widget with vendor pills + VRAM + driver + `encoder_support` badges.
* **GPU UX Slice C (2026-05-04):** Multi-encoder priority chain + fallback orchestration; `services/session_router.py` walks `transcoding_chain` and falls through on `concurrent_session_cap`; `EncoderPriorityList` drag-and-drop widget; `FallbackHistoryPanel` polls `/transcoding/fallback-history`; per-session encoder pill on active-sessions table; migrations 020 + 021.
* **Stream pipeline robustness (2026-05-04):** AV1 hw-decode failure → cuvid auto-fallback retry; long-GOP stream-copy fix (`hls_time=10`, `independent_segments` flag dropped for stream-copy); migration 019 sanitises stale `license_key`; `ActivityCubit` polls `/stream/sessions` every 2 s.
* **Phase 6 follow-ups (2026-05-04 → 2026-05-05):** Cuvid auto-fallback widened to cover Turing GPUs (`use_cuvid` → `use_gpu_input` rename; `_CUVID_FAILURE_MARKERS` extended); manual fmp4 init helper (`_ensure_fmp4_init_segment`) + explicit `-hls_fmp4_init_filename`; HLS router content-type fix (`.m4s`/`.mp4` → `video/mp4`); HDR→SDR tonemap chain (`_HDR_TO_SDR_VF` zscale+Hable BT.2020 PQ → BT.709 SDR); `_resolve_source_metadata(db, file_path) -> (codec, hdr_format)`; `start_stream(*, tonemap_hdr: bool = False)`; new `?tonemap=true` query param + `hdr_format`/`tonemapped` response fields; mobile HDR badge + 3-dot overflow with tonemap toggle + `PlayerCubit.setTonemap` restart-with-resume; static VOD playlist (`_write_static_vod_playlist` pre-emits complete `#EXT-X-PLAYLIST-TYPE:VOD` listing). Server suite **312 → 351 passing**.

**Next Immediate Steps (carried forward from Archive 07):**
1. **Watch the user's next HDR playback attempt.** Server log should show `mode=transcode(h264_nvenc/mpegts) source_codec=hevc` plus the tonemap `-vf` value when tonemap is on.
2. **HDR tonemap performance** at higher bitrates is untested. 4K HDR HEVC with tonemap may not keep up in real time; hardware tonemap (libplacebo, NVDEC tonemap) is Slice D territory.
3. **Slice D candidates** — hardware tonemap on RTX 30+; libdav1d-enabled FFmpeg bundle; per-codec NVDEC capability matrix surfaced in `DetectedHardwareCard` so AV1 sources on Turing GPUs fail-fast at scan time.
4. **Bundled FFmpeg lacks libdav1d** — software AV1 decode fails on common HDR sources; tracked in `docs/10_planning/04_manual_tasks.md`.

---

## [2026-05-05] — Library hardening + encoder failure classifier + streaming-pipeline plan + Commit 1
**Phase:** Phase 5 / Phase 6 polish — pre-v1-ship hardening
**Status:** Complete (Commits 2–4 of streaming-pipeline plan still pending — separate work units)

### What Was Done

Triggered by four user-reported regressions during 2026-05-05 user-acceptance testing: seek-ahead unusable, HDR→SDR toggle "code error 1", GPU/CPU pegging, washed-out HDR. Investigation surfaced six other issues that share root causes; full audit + remediation plan written to [`docs/10_planning/11_streaming_pipeline_issues.md`](docs/10_planning/11_streaming_pipeline_issues.md). Commit 1 of that plan landed in this session. Two adjacent batches (corrupt-path defenses + encoder failure classifier) shipped in parallel since they share the "make field failures actionable" goal.

#### Library hardening — corrupt path defenses + duration extraction + backfill

- **Symptom that triggered the work.** A user-reported transcode error on `Avicii - The Nights - YouTube.mkv` in the user's library was traced to a `media_files.path` value of `[\Avicii - The Nights - YouTube.mkv` — a single `[` character followed by the filename. Three rows had this shape; root cause was an old buggy upload code path that consumed `Library.root_paths` as a JSON string instead of parsing it, so `root_paths[0]` returned `'['` (the first character of `'["C:..."]'`) and `Path(root_paths[0]) / filename` produced the corrupt path.
- **Validator** — new `library_service._is_valid_absolute_media_path(path_str)` returns False for paths that are empty, contain null bytes, are not absolute, or start with `[\` / `[/`. Called from `scan_library` (skip + warn) and `upload_file_to_library` (raise `ValueError`).
- **Defensive guards on upload** — before reading `root_paths[0]`, `upload_file_to_library` checks `isinstance(root_paths, list) and all(isinstance(p, str) for p in root_paths)` and that the first element is absolute. Refuses with a clear `ValueError` if not.
- **Migration 022 (`022_remove_corrupt_media_paths.sql`)** — deletes the 3 existing corrupt rows and their 8 dependent `stream_sessions` (FK-aware: stream_sessions deleted first to satisfy `file_id REFERENCES media_files(id)`). Idempotent: future runs find no matching rows once the validator blocks new ones.
- **Probe writes duration** — `probe_video` now passes `-show_format` to ffprobe and parses `format.duration`. `_persist_probe` writes it to `media_files.duration_sec` via `COALESCE(?, duration_sec)`. Without this, the static VOD playlist generator has no duration to base its segment count on and falls back to FFmpeg's growing playlist (which the mobile/desktop seek bar can't span).
- **Startup duration backfill** — new `library_service.backfill_missing_durations(db, batch_size=50, max_rows=5000)` keyset-paginates over rows where `duration_sec IS NULL`, calls `probe_video`, and writes the result. `apps/server/main.py` schedules it as a background task on startup. On the user's machine it probed and persisted 29 rows on first run.
- **Tests** — new `test_library_service.py` (16 cases — parametrized validator, upload-rejects-malformed-root_paths, backfill persists + paginates) and `test_probe_video.py` (4 cases — extracts from format, returns None for missing/zero, returns None when ffprobe missing).

#### Encoder failure classifier + desktop notification surfacing

- **Symptom.** User's Intel UHD 630 detected and `h264_qsv` self-test ran, but `[QSV @ ...] Error creating a MFX session: -9.` failed every time. Root cause is driver 26.20.100.7262 (late 2020) ships only legacy MSDK 1.x; bundled FFmpeg requires oneVPL 2.x runtime. No FFmpeg-side fallback works (DXVA2/D3D11VA both fail the same way). User pushed back on "tell users to update drivers" — needed a ship-ready fallback.
- **Approach** — recognise the failure signature, surface a plain-language suggestion the user can act on, fall through to libx264 (already happens via priority chain). Three signatures recognised:
  1. **QSV old driver** — `[QSV ...] Error creating a MFX session: -9.` (case-insensitive) → "Intel Quick Sync detected but the driver is too old to load the runtime. Update Intel Graphics driver to a oneVPL Runtime build (driver 31.x or newer) at https://www.intel.com/content/www/us/en/download-center/home.html."
  2. **No Intel iGPU at all** — `Device creation failed: ...\nNo device available.` → "No Intel iGPU detected on this machine; switching to CPU encode."
  3. **NVENC GeForce session cap** — `OpenEncodeSessionEx failed: out of memory (10):` → "NVENC concurrent-session cap reached (consumer GeForce cards allow 3); existing sessions must end first."
- **Pure function** — `transcoding_service.classify_encoder_failure(encoder, error)` is side-effect-free and returns `str | None` so the caller can fall through to the raw error when the failure isn't recognised.
- **EncoderTestResult dataclass** extended with `suggestion: str | None = None` (default keeps prior call sites working).
- **Notification emission** — new `emit_encoder_failure_notifications(db)` writes one notification per failed encoder, dedup-keyed on `category=transcode + related_kind=encoder + related_id=<encoder> + dismissed_at IS NULL`. `_ENCODER_LABELS` provides friendly titles ("H.264 (Intel Quick Sync)" etc.). Called from `apps/server/main.py` startup after self-tests AND from `apps/server/routers/settings.py` after on-settings-change retest. Dismissed-then-re-detected = a fresh notification on the next restart.
- **Desktop surfacing** — `EncoderStatusInfo` extended with `suggestion`; `EncoderStatusPanel` tooltip prefers the suggestion line when present, falling back to the raw error line.
- **Wire across the stack** — `EncoderLoad` Pydantic model gains `encoder_test_suggestion: str | None`; Dart `TranscodingStatus.encoderTestSuggestion` field; `transcoding_status.freezed.dart` + `.g.dart` regenerated via `dart run build_runner build`.
- **`test_encoder` log level demoted** — was logging WARNING with raw stderr immediately on failure, which doubled with the outer `run_encoder_self_tests` log line. Now DEBUG so `run_encoder_self_tests` is the single source of truth for user-facing log level (it logs INFO with the suggestion when the classifier matches; WARNING with the raw error otherwise).
- **Tests** — new `test_encoder_failure_classifier.py` (15 cases — three signatures + parametrized unrecognised-pattern fallthrough + emit dedup/dismiss-recreate/skip-passed/skip-without-suggestion).

#### Streaming pipeline plan + cross-references

New planning doc [`docs/10_planning/11_streaming_pipeline_issues.md`](docs/10_planning/11_streaming_pipeline_issues.md). Nine sections:

- **§1 Executive summary** — four user-reported failures + cross-cutting "<no stderr captured>" diagnostic gap.
- **§2 Architecture** — one-page summary of player → server → FFmpeg flow + key files + pipeline modes (stream-copy mpegts / stream-copy fmp4 / transcode) + static VOD playlist mechanics.
- **§3 User-reported issues** — four issues with verbatim symptom, root cause, code targets, server-side bandage, player-side amplification.
  - 3.1 Seek-ahead takes minutes / 404s — no `-ss` restart; static VOD playlist over-promises.
  - 3.2 HDR→SDR toggle "code error 1" — 10 s playlist-appearance timeout kills FFmpeg right as it produces first tonemapped segment; Windows `TerminateProcess(handle, 1)` masquerades as exit code 1.
  - 3.3 GPU/CPU pegs on every stream — three contributors: zombie FFmpeg from rapid re-spins; tonemap is CPU-only; encoder priority chain may pick libx264 silently.
  - 3.4 HDR is "not even working" — `media_kit` (libmpv on Android) does no display-side tonemap; server-side tonemap is the only fix and depends on 3.2 shipping.
- **§4 Spotted during investigation** — 10 additional issues including `<no stderr captured>` for three failure modes; no session_dir cleanup on FFmpeg startup failure; 5 s wait blocks HTTP worker; `update_progress` floods WAL; static VOD over-promises segments; no `(client_id, file_id)` dedup on start_stream; hardcoded Hable tonemap; redundant fmp4 init generator; no log rotation; no "Start over" affordance.
- **§5 Remediation plan** — four commits, ~1.5 days end-to-end. Commit 1 marked **landed 2026-05-05** with shipped-changes detail.
- **§6 Test strategy** + **§7 Risks** + **§8 Out of scope** + **§9 Cross-references**.

Cross-refs added to:
- `CLAUDE.md` — Key files table and "Networking / streaming" task row.
- `docs/10_planning/01_roadmap.md` — pointer paragraph.
- `docs/10_planning/05_ship_readiness.md` — new "Streaming pipeline regressions (demo-visible)" section listing the four headline defects with location + sequencing guidance ("Commit 1 independently shippable; unblocks the most visible demo issue immediately"). Also bumped status date.
- `docs/12_guidelines/03_gotchas.md` — new gotcha "FFmpeg failed: exit code 1 with `<no stderr captured>` actually means we killed it ourselves" covering the Windows `TerminateProcess(handle, 1)` trap. Updated post-Commit-1 to reflect shipped fix.

#### Streaming pipeline Commit 1 — Tonemap unblock + diagnostic upgrade

Code in [`apps/server/services/ffmpeg_service.py`](apps/server/services/ffmpeg_service.py):

- **`_spawn_ffmpeg_attempt` accepts `playlist_timeout_sec`** (default 10 s). Returns a 4-tuple `(succeeded, tail, returncode, killed_after_timeout)`. The new `killed_after_timeout: bool` flag lets the caller distinguish "we terminated FFmpeg" from "FFmpeg crashed with exit 1" — on Windows, `proc.terminate()` is `TerminateProcess(handle, 1)` so the returncode is identical for both cases without this flag.
- **`start_stream` selects per-pipeline timeout** — 60 s for tonemap, 30 s for software transcode (`meta.vendor == "software"`), 10 s otherwise. Cuvid retry path bumps to ≥30 s since software-decode-into-NVENC is materially slower than the GPU-input first attempt.
- **Error path emits a meaningful diagnostic.** When `killed_after_timeout` is True, the log + RuntimeError say `FFmpeg killed after Ns timeout: session=<sid> no first segment — likely a slow tonemap or software transcode on this CPU` instead of the misleading "exit code 1". The hint suffix is conditional on `apply_hdr_tonemap or (not direct_remux and meta.vendor == "software")`.
- **`_build_ffmpeg_cmd` switches transcode sessions to `-loglevel warning`** (was `error`). Transcode failures (unsupported pixel format, missing decoder, hwaccel rejection) frequently surface only at WARNING and were being swallowed under ERROR — leaving operators with `<no stderr captured>` when the process was killed. Stream-copy keeps `-loglevel error` because its hot path (re-muxing source bitstream) is verbose at WARNING.

Tests in [`apps/server/tests/test_stream.py`](apps/server/tests/test_stream.py) (+6 tests, suite **391 → 397**):

- `test_build_ffmpeg_cmd_uses_warning_loglevel_for_transcode`
- `test_build_ffmpeg_cmd_uses_error_loglevel_for_stream_copy`
- `test_spawn_attempt_succeeds_when_playlist_appears` — happy path; mocked subprocess + playlist file written from the start.
- `test_spawn_attempt_returns_killed_after_timeout_when_playlist_never_appears` — process alive, playlist never appears, short 0.3 s timeout to keep test snappy.
- `test_spawn_attempt_returns_not_killed_when_process_exits_prematurely` — process returncode goes None→2 mid-poll; killed_after_timeout=False; terminate() not called.
- `test_spawn_attempt_respects_supplied_timeout` — wall-time bound on the wait (0.18 s ≤ elapsed < 1.5 s).

Mocking pattern lifted from `test_probe_video.py`: patch `asyncio.create_subprocess_exec` to return a `MagicMock` proc with a `returncode` property backed by a list (so we can simulate "alive on first poll, exited on second"), `wait()` as `AsyncMock`, and `terminate()` / `kill()` as `MagicMock` so `assert_called_once()` works.

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `apps/server/database/migrations/022_remove_corrupt_media_paths.sql` |
| Created | `apps/server/tests/test_library_service.py` (16 cases) |
| Created | `apps/server/tests/test_probe_video.py` (4 cases) |
| Created | `apps/server/tests/test_encoder_failure_classifier.py` (15 cases) |
| Created | `docs/10_planning/11_streaming_pipeline_issues.md` (nine-section plan + Commit 1 landed) |
| Created | `docs/logs/AGENT_LOG_archive_07.md` (rotation of prior log; 1180 lines) |
| Modified | `apps/server/services/library_service.py` (`_is_valid_absolute_media_path`; scan + upload guards; `_persist_probe` writes duration; `backfill_missing_durations`) |
| Modified | `apps/server/services/ffmpeg_service.py` (probe extracts duration; lazy-probe persists duration; `_spawn_ffmpeg_attempt` 4-tuple + `playlist_timeout_sec`; `start_stream` per-pipeline timeout selection + `killed_after_timeout` error path; `_build_ffmpeg_cmd` `-loglevel warning` for transcode; `test_encoder` WARNING → DEBUG) |
| Modified | `apps/server/services/transcoding_service.py` (`classify_encoder_failure`; `EncoderTestResult.suggestion`; `emit_encoder_failure_notifications`; `_ENCODER_LABELS`; `run_encoder_self_tests` INFO with suggestion / WARNING with raw stderr) |
| Modified | `apps/server/main.py` (background `_duration_backfill_task`; `emit_encoder_failure_notifications` after self-tests) |
| Modified | `apps/server/routers/settings.py` (`emit_encoder_failure_notifications` after on-settings-change retest) |
| Modified | `apps/server/models/transcoding.py` (`EncoderLoad.encoder_test_suggestion`) |
| Modified | `apps/server/tests/test_stream.py` (+6 tests for spawn / build-cmd) |
| Modified | `packages/fluxora_core/lib/entities/transcoding_status.dart` (`encoderTestSuggestion`; `.freezed.dart` + `.g.dart` regenerated) |
| Modified | `apps/desktop/lib/features/transcoding/presentation/widgets/encoder_status_panel.dart` (`EncoderStatusInfo.suggestion`; tooltip prefers suggestion) |
| Modified | `CLAUDE.md` (Key files table) |
| Modified | `docs/10_planning/01_roadmap.md` (cross-ref to streaming pipeline plan) |
| Modified | `docs/10_planning/04_manual_tasks.md` (cache-management deferred entry; PyInstaller spec deferred entry) |
| Modified | `docs/10_planning/05_ship_readiness.md` (new "Streaming pipeline regressions" section + status date) |
| Modified | `docs/12_guidelines/03_gotchas.md` (new "exit code 1 with `<no stderr captured>`" gotcha; updated to reflect shipped fix) |
| Modified | `docs/00_overview/current_status.md` (this batch; suite 351 → 397; migrations 001–022) |
| Modified | `docs/00_overview/README.md` (Last Updated 2026-05-05) |
| Modified | `docs/04_api/01_api_contracts.md` (`encoder_test_suggestion` in `/transcoding/status` example + notes) |
| Modified | `docs/03_data/02_database_schema.md` (migration 022 entry) |
| Modified | `docs/09_backend/01_backend_architecture.md` (`library_service` validator + backfill; `transcoding_service` classifier + emit) |
| Modified | `docs/09_backend/02_hardware_acceleration.md` (`EncoderTestResult.suggestion`; classifier + notification surfacing paragraph) |
| Modified | `AGENT_LOG.md` (rotated to archive_07; this entry seeded) |

### Decisions Made

- **Classifier returns `None` for unrecognised patterns rather than echoing the raw error.** Lets the caller fall through to displaying `encoder_test_error` in the desktop tooltip rather than producing two slightly-different message strings for the same failure. The classifier owns plain-language suggestions; raw stderr ownership stays with `test_encoder`.
- **Notification dedup on `dismissed_at IS NULL` only.** A future server start that re-detects the same failure after the user dismissed the notification creates a fresh one. This is intentional — the user might dismiss too aggressively; a restart loop won't spam (within-session-restart still hits the dedup).
- **`-loglevel warning` for transcode, `-loglevel error` for stream-copy.** Stream-copy at WARNING is too noisy (every keyframe triggers a heuristic note). Transcode at ERROR was suppressing decoder/hwaccel rejection notes that surface as warnings. The split keeps logs readable in the common (stream-copy) path while restoring diagnostic quality on the failure-prone (transcode) path.
- **`killed_after_timeout` as an explicit tuple field, not inferred from `proc.returncode`.** Inferring it would require knowing the OS's terminate-signal returncode (1 on Windows, -SIGTERM on Linux). Cleaner to just have the spawn function set the flag where it actually killed the process.
- **Plan doc cross-references in Commit 4 of the chunked commits, not Commit 3.** The plan doc reflects "Commit 1 ✅ landed" reality after this session — bundling the doc with the code that completes its first commit keeps the message of each PR honest. Other docs (roadmap, ship-readiness, gotchas, CLAUDE.md) carry only forward references and can ship in Commit 3.
- **`fluxora_server.spec` deferred.** The file is a 35-byte placeholder with a corrupted character. Filling in a working PyInstaller spec is a 60–90 min task (assets, hidden imports, icon, version info, code-signing pipeline) and the user said "we can do spec work later". Tracked in `docs/10_planning/04_manual_tasks.md`.
- **Cache-management UI deferred.** User asked about cache visibility/management on desktop and server. Inventoried what's cached (HLS segments, SQLite WAL, log file, in-memory caches; desktop's `cached_network_image`) but the UI work to surface + clear it is post-v1. Tracked in `docs/10_planning/04_manual_tasks.md`.

### Blockers / Open Issues

- **Commits 2–4 of the streaming pipeline plan are pending.**
  - Commit 2 (~4–6 hr) — server-side seek-restart endpoint `POST /api/v1/stream/{session_id}/seek?seek_sec=` + `restart_stream(session_id, seek_sec)` + `#EXT-X-DISCONTINUITY-SEQUENCE` re-emit.
  - Commit 3 (~3 hr) — mobile player wire-up: `seekTo(Duration)` debounced, threshold for in-player vs restart-based seek.
  - Commit 4 (~2 hr) — kill prior session for same `(client_id, file_id)`; cleanup `session_dir` on FFmpeg startup failure; debounce `update_progress` to 30 s; `RotatingFileHandler`.
- **Acceptance test on the user's box still pending for Commit 1.** The test suite confirms behaviour but not "Genshin HDR clip plays through tonemap toggle on the user's i7-9750H + UHD 630". Listed in §5 of the plan as part of the Commit 1 acceptance criteria.

### Issues / Sharp Edges Discovered

- **The previous corrupt-path bug went undetected because nothing validated paths on insert.** The validator landed in scan + upload but doesn't run on the existing rows — the migration cleans them out as a one-shot. If similar bugs land in the future, we'll need either a per-startup integrity check or a unique constraint on `path` shape (SQLite CHECK constraint with `LIKE` patterns), neither shipped here.
- **The cuvid retry path uses `playlist=playlist` (the served path) instead of `ff_playlist` while the first attempt uses `ff_playlist`.** Pre-existing inconsistency, not introduced by Commit 1, but visible now that the spawn function distinguishes the two clearly. Flagged in the plan doc's Commit 1 caveat so Commit 2 picks it up.
- **`EncoderTestResult.suggestion` defaults to None for back-compat with existing `_TEST_RESULTS` consumers.** All current consumers either build the dataclass with kwargs (so the new field is optional) or read the field defensively. Adding a required field would have been a bigger blast radius.
- **`media_files.duration_sec` was nullable since migration 001 but never populated by the probe path.** All 32 rows on the user's box had `duration_sec = NULL`. The static VOD playlist generator silently fell through to the incremental playlist for every stream — symptom was the seek bar growing during playback. Fixed by `probe_video` → `_persist_probe` write + startup backfill.
- **Notification dedup hinges on `category + related_id` + `dismissed_at`.** That tuple is *not* indexed. The dedup query reads at most 32 notification rows on the user's machine; on a multi-encoder failure scenario (NVENC cap + QSV old driver + AMD missing) it'd be 3 rows. Not a perf concern at v1 scale, but worth noting if notification volume ever grows.

### Hard Rules Checklist
- [x] No `git commit` / `git push` / `git add` performed. Owner reviews staged changes separately. Chunked commit plan provided in conversation.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()` introduced. All logging via `logger`.
- [x] No silent exceptions. `_duration_backfill_task` logs WARNING on failure; classifier returns None on no-match (caller falls through); `emit_encoder_failure_notifications` reports inserted-count for caller logging.
- [x] No hardcoded secrets, ports, paths.
- [x] No new pip / pub deps.
- [x] No layer-boundary violations. Classifier is pure; emit reads/writes via `aiosqlite`; desktop reads from cubit; cubit reads from repo.
- [x] No git-history rewrites.
- [x] No edits to past migrations (022 is a new file).

### Next Agent Should

- **Land Commit 2 of the streaming pipeline plan** — server-side seek-restart endpoint + `restart_stream()`. Pre-design covered in `docs/10_planning/11_streaming_pipeline_issues.md` §5 Commit 2. Acceptance: two seeks within 200 ms result in only the second restart taking effect; segments produced match `seg<N>.m4s` where N starts at the seek index.
- **After Commit 2 ships, do Commit 3** — mobile cubit `seekTo(Duration)` with debounce + threshold for in-player vs restart-based seek. The two are useless individually.
- **Commit 4 (zombie cleanup + dedup + log polish)** can land any time — it's hygiene and depends on no other commit. Consider landing it before Commit 2 if the user reports more zombie FFmpegs in the meantime.
- **Visual / acceptance test on the user's box for Commit 1.** Server log on a tonemap session should show `playlist_timeout=60s` in the FFmpeg-started line; first segment should land in <90 s; mobile player should start. If timeout still fires, the kill diagnostic now says "killed after 60s" instead of "exit code 1" so the user can report a meaningful error.
- **Verify migration 022 ran cleanly** on next user-side server start. Log line `FOREIGN KEY constraint failed` on application startup means the migration didn't apply (FK enforcement was off when I tested) — would need to re-investigate. The migration file deletes stream_sessions first specifically to avoid this.
---

---
## [2026-05-06] — TMDB ISP-block workaround + Cloudflare Worker proxy
**Phase:** Phase 5 polish — pre-v1-ship hardening
**Status:** Complete (Worker deployed, proxy URL verified working on user's Jio network, end-to-end TMDB metadata flowing)

### What Was Done

Field user (in India, on Reliance Jio) reported every TMDB enrichment producing `0/N files updated`.  The original error log read `TMDB search failed for 'X': ` with nothing after the colon — empty `str(exc)` from `httpx.ConnectError` variants.  Three layers of fix shipped, plus a Cloudflare Worker that the user deployed to bypass the ISP block entirely.

#### Layer 0 — better diagnostics

`TmdbService.search` error log now uses `exc.__class__.__name__` + `repr(exc)`.  The "empty colon" log lines now read `ConnectTimeout: ConnectTimeout('')` — class name visible, operator can distinguish a network timeout from a JSON parse error from a 401.

#### Layer 1 — filename-stem cleanup

`library_service._clean_tmdb_query(stem)` normalises filename stems before TMDB search.

- Replaces `_` and `.` with spaces — `Harry_Potter_and_the_Half_Blood_Prince` was returning zero matches because TMDB doesn't tokenise across underscores; same for torrent-scene `Inception.2010.1080p.BluRay.x264`.
- Strips trailing scene-noise (4-digit year + optional quality / source / codec / audio markers) — TMDB's fuzzy `?query=` treats every word as a content keyword that must appear in title or overview.  Movies don't have their year / `1080p` / `x264` in the title, so leaving those tokens poisons the match.  `_TRAILING_SCENE_NOISE` regex is trailing-only — `Blade Runner 2049 sequel notes` keeps its year because the strip pattern only fires when year-and-after runs cleanly to end-of-string through known noise tokens.
- Handles Plex naming (`Inception (2010)`, `The Matrix [1999]`, `Inception - 2010`) — bracket / dash wrappers around the year all collapse the same way.

This alone made TMDB queries return matches for files that previously got nothing.

#### Layer 2 — DoH override

New `apps/server/utils/dns_override.py`:

- Monkey-patches `socket.getaddrinfo` with a per-process override map (`_DNS_OVERRIDES`).  Hostnames in the map return a synthesised IPv4 A record pointing at the override IP; non-overridden hostnames pass through to the original resolver.
- `resolve_via_doh(hostname)` queries Cloudflare's anycast `https://1.1.1.1/dns-query` (DoH JSON API).  The DoH endpoint is reached *by IP* — `1.1.1.1`'s certificate covers `cloudflare-dns.com` so SNI works without DNS — meaning the bypass doesn't itself depend on the broken DNS path.
- `register_doh_override(hostname)` resolves + populates the map.

`TmdbService.search` retry loop: on `ConnectError`/`ConnectTimeout`, registers the override and retries once.  Subsequent calls go to the override IP directly; the overhead is paid exactly once per process.  Works for users whose ISP only does DNS hijacking (returns sinkhole IP for the hostname but doesn't IP-block the real CDN).

**Did not solve the user's case.**  Jio is doing DNS hijack *and* IP block — even when DoH gave us the correct CloudFront IP, packets to `3.165.239.x` still timed out.

#### Layer 3 — Cloudflare Worker reverse proxy (the actual fix)

New env vars on the server:

- `FLUXORA_TMDB_BASE_URL` (default empty → falls back to `https://api.themoviedb.org/3`)
- `FLUXORA_TMDB_IMAGE_BASE_URL` (default empty → falls back to `https://image.tmdb.org/t/p/w342`)

`TmdbService.__init__` accepts optional `base_url` + `poster_base_url`; `library_service._enrich_with_tmdb` reads the settings and threads them through.  When the base URL is overridden, every TMDB search + every poster URL stored in `media_files.poster_url` flows through the operator's domain.

The user (Marshal) deployed a Cloudflare Worker named `fluxora-tmdb-proxy`:

- Routes `/tmdb/*` to `api.themoviedb.org/*`
- Routes `/tmdb-img/*` to `image.tmdb.org/*`
- Caches at the edge with `cf.cacheEverything = true` + 24h TTL on API, 30d TTL on images
- Strips client-supplied headers (only `Accept` + `User-Agent` forwarded) to prevent accidental leaks

Worker code + dashboard click-by-click in [`docs/05_infrastructure/runbooks/12_tmdb_proxy_worker.md`](docs/05_infrastructure/runbooks/12_tmdb_proxy_worker.md).

The user's `.env` was set to:
```
FLUXORA_TMDB_BASE_URL=https://fluxora-tmdb-proxy.marshalgcom.workers.dev/tmdb/3
FLUXORA_TMDB_IMAGE_BASE_URL=https://fluxora-tmdb-proxy.marshalgcom.workers.dev/tmdb-img/t/p/w342
```

(Workers.dev URL rather than the custom `fluxora-api.marshalx.dev` because the latter hit a Windows DNS Client negative-cache stickiness on the user's machine — `nslookup` resolved correctly but `curl` / Python `getaddrinfo` couldn't.  Workers.dev URL is functionally identical and doesn't trigger that quirk.)

**Field-confirmed working:** server log post-restart shows `HTTP Request: GET https://fluxora-tmdb-proxy.marshalgcom.workers.dev/tmdb/3/search/multi?... 200 OK` for every previously-failing query.  Posters + titles now resolve.

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `apps/server/utils/dns_override.py` (monkey-patched getaddrinfo + DoH resolver) |
| Created | `apps/server/tests/test_dns_override.py` (+11 tests) |
| Created | `docs/05_infrastructure/runbooks/12_tmdb_proxy_worker.md` (Worker code + deployment guide + diagnostic checklist) |
| Modified | `apps/server/services/tmdb_service.py` (better error log; retry-with-DoH; optional base_url + poster_base_url; trailing-slash normalisation; `_extract_host`) |
| Modified | `apps/server/services/library_service.py` (`_clean_tmdb_query` — underscores/dots → spaces, strip trailing year + scene noise; `_TRAILING_SCENE_NOISE` regex; `_enrich_with_tmdb` reads settings + cleans queries; `enrich_library_tmdb` for the Rescan TMDB action) |
| Modified | `apps/server/config.py` (`fluxora_tmdb_base_url`, `fluxora_tmdb_image_base_url` settings fields) |
| Modified | `apps/server/main.py` (TMDB DoH pre-warm task on startup; non-blocking) |
| Modified | `apps/server/tests/test_tmdb_service.py` (+10 tests: retry-after-DoH, no-retry-when-override-set, no-retry-on-non-connection-errors, default base URL, custom base URL, custom poster base, host extraction, trailing-slash normalisation) |
| Modified | `apps/server/tests/test_library_service.py` (+8 cleaning tests, +1 enrich uses cleaned query, +1 skip when cleanup yields empty) |
| Modified | `C:\Users\marsh\AppData\Roaming\Fluxora\.env` (operator-side: added the two FLUXORA_TMDB_*_URL entries pointing at the deployed Worker) |
| Modified | `docs/12_guidelines/03_gotchas.md` (3 new gotchas: TMDB year/quality suffix poisoning, ISP DNS hijack + IP block patterns, Windows DNS Client NXDOMAIN cache stickiness) |
| Modified | `docs/10_planning/04_manual_tasks.md` (2 new entries: poster-URL migration to proxy prefix, fluxora-api.marshalx.dev DNS investigation) |
| Modified | `docs/00_overview/current_status.md` (this round's work; test count 438 → 474) |
| Modified | `docs/05_infrastructure/02_url_inventory.md` (TMDB row updated with proxy guidance + new image.tmdb.org row + DoH endpoint row) |
| Modified | `docs/04_api/01_api_contracts.md` (encoder_test_suggestion field examples updated; not directly TMDB-related but landed alongside) |
| Modified | `AGENT_LOG.md` (this entry) |

### Decisions Made

- **Three layers stack rather than choose one.**  Each layer handles a strictly larger class of network breakage:
  1. Cleanup helps every user (filenames are usually messy regardless of network).
  2. DoH override helps users whose ISP only does DNS hijacking — zero ops cost.
  3. Worker proxy is the operator's deliberate setup that handles ISPs with full IP blocks.

  Shipping all three keeps the cheap fixes for the easy cases and reserves the expensive setup for the operator who knows they have users on hostile networks.
- **Workers.dev URL > custom domain for shipping.**  After the user's Windows DNS Client negative-cache issue with `fluxora-api.marshalx.dev`, defaulted documentation to recommend the workers.dev subdomain.  Functionally identical — same Worker, same anycast, same TMDB results.  Avoids an entire class of local-resolver issue on user machines.
- **Trailing-only year strip.**  The naive regex (strip any 4-digit year token) would have silently broken titles like `Blade Runner 2049` and `2001 A Space Odyssey`.  Trailing-only + scene-noise-anchor pattern preserves those while still handling `Inception.2010.1080p.BluRay.x264` and `Harry_Potter_..._2009`.
- **Conservative scene-noise token list.**  Listed only tokens we've observed in field installs (1080p, BluRay, x264, HEVC, etc.).  Over-listing risks eating content from legitimate titles ("BluRay" could be a documentary name; some band albums are titled "10bit").  Easy to extend later when more patterns surface.
- **Per-user TMDB API keys, not Worker-level.**  Each Fluxora install carries its own TMDB key, forwarded as `?api_key=` through the Worker.  Worker injection would couple every user's traffic to the operator's key (rate-limit + revocation risk).  Field experience first, refine if signup friction becomes an issue.

### Blockers / Open Issues

- **Existing `media_files.poster_url` rows are still pointed at `image.tmdb.org`.**  The proxy fix only writes new poster URLs; rows enriched before the env var was set keep the original CDN URL, which the client still can't reach.  Tracked in `docs/10_planning/04_manual_tasks.md` as a one-shot SQL migration.  Until that lands, the user can run **Rescan TMDB** *only* on libraries where rows have `tmdb_id IS NULL`; rows with metadata won't be touched.  An alternative: ship a setting / migration that rewrites existing rows on next startup if the env var is set.
- **Custom domain DNS quirk on user's Windows machine** — `fluxora-api.marshalx.dev` resolves correctly via `nslookup` from any DNS server but `curl.exe` and `httpx.AsyncClient` can't resolve.  Diagnosed as Windows DNS Client negative cache holding NXDOMAIN past `ipconfig /flushdns`.  Workers.dev URL is the workaround in use.

### Issues / Sharp Edges Discovered

- **`getaddrinfo` and `nslookup` use different code paths on Windows.**  `nslookup` queries DNS directly; `getaddrinfo` consults Windows' DNS Client cache (which can hold NXDOMAIN past explicit flush).  Easy to confuse during diagnosis — `nslookup` returning a result doesn't mean code that uses `getaddrinfo` will resolve.  Documented in [`docs/12_guidelines/03_gotchas.md`](docs/12_guidelines/03_gotchas.md).
- **Cloudflare DoH JSON endpoint is reached BY IP** to bypass the DNS hijack, but TLS still validates against `1.1.1.1`'s real cert (which covers both `1.1.1.1` and `cloudflare-dns.com`).  The pattern is "connect to known-good IP, let SNI carry the original hostname for cert validation" — same pattern any Worker proxy uses.  This is what makes the DoH layer self-bootstrapping (it doesn't need DNS to find DNS).
- **TMDB `?query=` is content-keyword fuzzy, not metadata-filter.**  `query=Harry Potter 2009` requires "2009" to appear in title or overview; "Harry Potter and the Half-Blood Prince" doesn't have "2009" anywhere, so total_results = 0.  TMDB has a separate `&year=` param for year filters; we don't use it currently because the cleaned title-only query matches reliably enough.  Could be a refinement — strip the year from the search keyword AND pass it as `&year=` for stricter matching.  Defer.
- **Empty `str(exc)` is a real Python footgun.**  `httpx.ConnectError("")` has empty str() and produces "X: " log lines.  Always use `repr(exc)` or `f"{type(exc).__name__}: {exc}"` in error logs.  This pattern was duplicated across several other services — review and unify in a future pass.

### Hard Rules Checklist
- [x] No `git commit` / `git push` / `git add` performed.  Owner reviews staged changes before commit.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()` introduced.  All logging via `logger`.
- [x] No silent exceptions.  DoH resolution failure logs WARNING; TMDB retry only fires on connection errors, other exceptions surface with full repr().
- [x] No hardcoded secrets, ports, paths.  TMDB URLs configurable via env; defaults are documented constants.
- [x] No new pip / pub deps.  DoH uses existing httpx; monkey-patch is stdlib socket.
- [x] No layer-boundary violations.  Worker proxy lives at the network layer; service layer just sees a different base URL.
- [x] No git-history rewrites.
- [x] No edits to past migrations.  Future migration `023_rewrite_poster_urls_to_proxy.sql` is queued in manual_tasks.

### Next Agent Should

- **Ship the poster-URL migration** referenced in `docs/10_planning/04_manual_tasks.md` so existing `media_files.poster_url` rows get rewritten to the proxy prefix.  Without it, posters stay broken on every pre-existing media file even after the proxy is fully wired.
- **Investigate `fluxora-api.marshalx.dev` DNS quirk** if the user reports it again after a 24-48 hour cache cycle.  Workers.dev URL is the documented workaround for now.
- **Consider unifying error-logging patterns** across services to always use `repr(exc)`.  The empty-string-coloon issue masked the entire field investigation for hours; same footgun exists in other services that catch generic Exception.
- **Optional refinement**: extend `_clean_tmdb_query` to extract the year and pass it as TMDB's `&year=` filter for stricter matching.  Currently we strip the year entirely; passing it back as a filter could improve precision on common-title disambiguation (`The Matrix` vs `The Matrix Reloaded`).
---

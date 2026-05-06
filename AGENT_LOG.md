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

## [2026-05-06] — Desktop redesign plan reconciled + cosmetic follow-ups quick-wins batch (F1+F5+F7+F8)
**Phase:** Phase 5 desktop redesign — post-M10 polish
**Status:** Complete

### What Was Done

User asked whether the desktop redesign plan was fully done. Audit surfaced two issues: (1) the M0 backend prerequisites table in `docs/11_design/desktop_redesign_plan.md` claimed §7.3 / §7.4 / §7.8 / §7.9 / §7.10 / §7.11 were still 🔲 Pending despite the backend code having shipped weeks earlier (had been stale for that long); (2) several cosmetic placeholders / stale TODOs remained in the redesigned screens. Reconciled the doc, then shipped the four quick-wins (F1 + F5 + F7 + F8) per the freshly-written §11.1 follow-up table.

#### Plan reconciliation (doc-only)

- Verified each of the 6 "pending" M0 rows against `apps/server/`: every endpoint + migration claimed by M5 / M6 / M7 has actually shipped. Marked all six ✅ Done with the concrete landed-file evidence (router + line + migration number) inline in the table.
- Top-of-doc Status banner rewritten from "Complete — partially shipped" to "✅ Complete — every milestone shipped".
- M4 milestone label flipped from "🔵 In Progress" to "✅ Done 2026-05-02"; deferred per-client backend joins (IP, session-count) itemised separately.
- §5 Screen translation order table: 11 of 12 stale "🔲 Pending" rows updated to ✅ Done — only Dashboard had been correctly marked.
- §9 milestone-breakdown table: M0 / M1 / M2 / M3 / M4 each gained the `✅ Done <date>` annotation that M5–M10 already had.
- §11 split into 11.1 Residual follow-ups and 11.2 Original risk register. 11.1 enumerates F1–F10 — every cosmetic placeholder, every stale TODO, plus the four backend-joins blocked on real server work.

#### Quick-wins shipped (code)

- **F1 — Active Streams stat tile (Clients screen).** `_buildStatTiles` signature gained `BuildContext`; reads `context.select<SystemStatsCubit, int?>((c) => c.state.latest?.activeStreams) ?? 0`; `const StatTile` dropped to allow runtime value. Mirrors the same pattern Dashboard already uses at `dashboard_screen.dart:166`.
- **F5 — Help screen external links.** `url_launcher: ^6.3.2` added to `apps/desktop/pubspec.yaml` (latest stable per `pub.dev/api/packages/url_launcher`; established Flutter team package — meets Hard Prohibition #6 + #12). New `_LinkRowState._open()` async helper — null/empty guard, `Uri.tryParse`, `launchUrl(uri, mode: LaunchMode.externalApplication)`, `Logger`-wrapped failure paths (no silent exceptions). Replaces 4 no-op rows on the Help screen ("Documentation", "Community", "Report an Issue", "What's New").
- **F7 — Groups dialogs swap.** Discovered `FluxGlassDialog` already shipped at `lib/shared/widgets/flux_glass_dialog.dart` (used by Library + Pair Device + Subscription Upgrade dialogs). The original audit's "build a new primitive" assumption was wrong. Swapped **5** Material `AlertDialog` instances in `groups_screen.dart` (Create / Edit / Add-Member / 2× Delete confirm — original audit only counted 3 because two were inside named widget classes `_CreateGroupDialog` / `_EditGroupDialog`). Violet `FilledButton` for affirmative actions, red for destructive. `_CreateGroupDialog` and `_EditGroupDialog` `TextField` `style:` overrides removed since `FluxGlassDialog`'s default text style cascades correctly through `DefaultTextStyle.merge`.
- **F8 — Subscription manage tab `_ActionRow`.** `_ActionRow` gained `VoidCallback? onTap`; both call sites ("Upgrade Plan" + "Cancel Subscription") now pass `() => _openPortal(context)`. New `_ManageTab._openPortal` calls `OrdersCubit.openPortal()` + shows snackbar feedback. Correct per the parent comment "Actions (all deferred to portal)" — Polar handles all subscription mutations, so every plan action route through the portal is the right call.

`flutter analyze` clean (0 issues, 82.8 s).

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `docs/11_design/desktop_redesign_plan.md` (M0 table reconciled with shipped reality + landed-file evidence; M4 label updated; §5 screen-translation table updated; status banner rewritten; §11 split into 11.1 + 11.2; F1/F5/F7/F8 marked ✅ Done; two new change-log entries) |
| Modified | `apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart` (F1 — `_buildStatTiles` reads `SystemStatsCubit.state.latest?.activeStreams`; new `system_stats_cubit.dart` import) |
| Modified | `apps/desktop/lib/features/help/presentation/screens/help_screen.dart` (F5 — `_LinkRowState._open()` opens via `launchUrl`; `url_launcher` + `logger` imports) |
| Modified | `apps/desktop/lib/features/groups/presentation/screens/groups_screen.dart` (F7 — 5× `AlertDialog` → `FluxGlassDialog`; `flux_glass_dialog.dart` import) |
| Modified | `apps/desktop/lib/features/subscription/presentation/screens/subscription_screen.dart` (F8 — `_ActionRow.onTap` param + `_ManageTab._openPortal()` helper) |
| Modified | `apps/desktop/pubspec.yaml` (added `url_launcher: ^6.3.2`) |
| Modified | `AGENT_LOG.md` (this entry) |

### Docs Updated

- `docs/11_design/desktop_redesign_plan.md` — M0 reconciliation, status banner rewrite, M4/M5 label fixes, §11.1 follow-up table introduced, F1/F5/F7/F8 marked ✅, two 2026-05-06 change-log entries.

### Decisions Made

- **Reconcile-first, code-second.** Audited the M0 table against the actual code before writing any new code so we'd know which "follow-ups" were real vs. doc drift. 6 of 6 "pending" M0 rows turned out to be stale — backend had shipped weeks ago without the table being updated. Saved an entire pretend-implementation pass.
- **Reuse `FluxGlassDialog`, don't build a new primitive.** F7's original framing ("build a `FluxDialog` primitive") was wrong — primitive existed and was already in production use on three other screens. Adopting the existing one keeps the design system uniform and avoids a third dialog widget that would have to be reconciled later.
- **Wire `_ActionRow` instead of deleting it.** Considered deleting the row as obsolete (since `_PortalButton` already exists at the top of the manage tab). Re-read the parent comment "Actions (all deferred to portal)" and the rows clearly serve a different UX purpose (action-oriented entry points labelled "Upgrade Plan" / "Cancel Subscription" rather than a generic "Open Portal" button). Wiring them to the same destination is the right call.
- **Defer F2 / F3 / F6 / F10 (backend work) and F9 (compliance).** The remaining six follow-ups in §11.1 either need server endpoints that don't exist yet (F2/F3/F6/F10) or have compliance implications (F9 — "delete account" + "sign out everywhere" need a Phase 3 spec decision before implementation). Quick-wins batch was strictly the items that needed only frontend wiring or a single-dep-add.

### Blockers / Open Issues

- **F2 / F3 — Clients table IP + per-client active session join.** Need server changes to the `clients` table (`last_ip` column persisted at handshake/heartbeat) and an `active_session: {file, started_at, codec, ...}` join on `GET /api/v1/clients[/{id}]`. Cosmetic-only — table cells render `—`.
- **F6 — Help screen support bundle export.** Needs `POST /api/v1/info/support-bundle` returning a tar/zip of last-N-day logs + system_stats snapshot + redacted settings. Frontend can use existing `file_picker` dep for the save dialog.
- **F9 — Profile danger-zone actions** (revoke session, sign out everywhere, delete account, export data). Compliance-sensitive; needs explicit scope decision before any of the four endpoints land. Likely Phase 3 territory.
- **F10 — Encoder Settings benchmark button.** Needs `POST /api/v1/transcoding/benchmark` running ~10 s test encode against each available encoder, returning fps + speed + quality metrics.

### Issues / Sharp Edges Discovered

- **Plan-doc drift is invisible until you compare line-by-line.** The desktop redesign plan claimed M0 was "in progress" while the rest of the file (M5 / M6 / M7 entries) described features that demonstrably required those endpoints. The doc was internally inconsistent for weeks — the change-log only catches drift if every author remembers to write to it. Worth a periodic "verify the M0/M1/... headers against the actual code" pass on any long-lived plan doc.
- **`FluxGlassDialog` existed but wasn't discoverable from the M3-M7 task descriptions.** It was originally introduced for the Library "Remove library?" confirm dialog and quietly reused on Pair Device + Upgrade dialogs, but the redesign plan never name-dropped it as the canonical primitive. Future agents picking up dialog tasks will hit the same "should I build one?" decision unless DESIGN.md or `frontend_architecture.md` calls it out as the Material `AlertDialog` replacement.
- **`pub outdated` reports a lot of constraint-incompatible newer versions.** 22 packages with newer-but-blocked versions and 1 discontinued (`golden_toolkit`). Not blocking — but the `golden_toolkit` discontinuation is worth a follow-up: the package recommended replacement is direct use of `flutter_test`'s `matchesGoldenFile` matcher with `flutter_test`'s baked-in golden infrastructure. Add to manual_tasks if not already there.

### Proactive Suggestions for Next Work

1. **F2 + F3 backend join** — single PR. Server adds `last_ip` column + handshake/heartbeat persist + active-session join on the existing `GET /api/v1/clients` response. Frontend gets two `—` cells filled in. Concrete, contained, no compliance surface.
2. **F6 support-bundle endpoint** — one server endpoint + a button wire-up. Genuinely useful for field debugging (the TMDB ISP-block investigation last session would have been twice as fast with a one-click "send me your last N hours of logs"). New `services/support_bundle_service.py` for the redaction logic + tarball assembly.
3. **`golden_toolkit` discontinuation follow-up** — migrate the existing golden tests off `golden_toolkit` onto `flutter_test`'s built-in `matchesGoldenFile`. Low priority (current tests still run), but the dep will eventually rot.

### Hard Rules Checklist
- [x] No `git commit` / `git push` / `git add` performed.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()` introduced. F5 + F8 use the project `Logger()` pattern.
- [x] No silent exceptions. F5 `_open()` catches `Exception`, logs with stack trace, returns gracefully.
- [x] No hardcoded secrets, ports, paths.
- [x] One new pub dep added (`url_launcher: ^6.3.2`) — justified per Hard Prohibition #6: established Flutter-team package, single-purpose, primary feature is exactly what we need, no existing dep covers it. Latest version verified via pub.dev API per Hard Prohibition #12.
- [x] No layer-boundary violations.
- [x] No git-history rewrites.
- [x] No edits to past migrations.

### Next Agent Should

- **F2 + F3 server join** if they want to fully clear the Clients screen of `—` placeholders. Server changes only — the frontend reads exist already, just have to plumb the new fields through.
- **F6 support-bundle** if field-debug ergonomics are the priority. Genuinely high leverage for any user issue where logs matter.
- **`golden_toolkit` migration** when the discontinued-dep notice becomes annoying enough. Not urgent.
- **Defer F9** until there's a real product decision on the four danger-zone actions.
---

## [2026-05-06] — F2 + F3 shipped: Clients screen IP column + active-session join
**Phase:** Phase 5 desktop redesign — post-M10 polish (§11.1 follow-up)
**Status:** Complete

### What Was Done

Cleared the last `—` placeholders from the Clients screen by adding the backend join the redesign was always blocked on. Two follow-ups in one PR because they share the SQL surface (`clients` row + `stream_sessions` join).

#### Server

- **Migration `023_clients_last_ip.sql`** — `ALTER TABLE clients ADD COLUMN last_ip TEXT` (nullable). Existing rows show `—` until their next authenticated request.
- **`auth_service.create_pair_request`** — gained `client_ip: str | None = None` kwarg. INSERT writes `last_ip`; ON CONFLICT uses `COALESCE(excluded.last_ip, clients.last_ip)` so re-pair from an unknown source (e.g. caller passes None) doesn't clobber a previously-recorded IP.
- **`auth_service.update_client_heartbeat(db, client_id, last_ip=None)`** — new helper that touches `last_seen` (and optionally `last_ip`) for an authenticated client.
- **`routers/deps.validate_token`** — gained `request: Request` param; calls `update_client_heartbeat(db, client["id"], last_ip=request.client.host)` after successful token validation. Wrapped in try/except + WARNING log so a transient SQLite write failure can't block an authenticated request. **Side effect:** also fixes a pre-existing latent bug — `last_seen` was previously frozen at pair/approval time and never refreshed by API traffic. The desktop's "Online Now" stat tile counts trusted+approved rows so this didn't surface as a visible bug, but `last_seen` is now actually live.
- **`routers/auth.request_pair`** — passes `request.client.host` as `client_ip` into `create_pair_request`.
- **`auth_service.list_clients`** — rewritten with a window-function LEFT JOIN:

  ```sql
  LEFT JOIN (
      SELECT s.client_id, s.id AS session_id, s.started_at, s.encoder_used,
             COALESCE(m.title, m.name) AS media_title,
             ROW_NUMBER() OVER (PARTITION BY s.client_id ORDER BY s.started_at DESC) AS rn
        FROM stream_sessions s
   LEFT JOIN media_files m ON m.id = s.file_id
       WHERE s.ended_at IS NULL
  ) sess ON sess.client_id = c.id AND sess.rn = 1
  ```

  Defensive in case multiple in-flight sessions ever appear for one client (v1's `concurrent_session_cap` is 1 per encoder so the practical answer is always 0 or 1, but the query stays correct under future relaxation).
- **`models/client.py`** — new `ActiveSessionInfo(BaseModel)` with `session_id` / `started_at` / `encoder_used?` / `media_title?`. `ClientListItem` extended with `last_ip: str | None = None` and `active_session: ActiveSessionInfo | None = None`.
- **`routers/auth.list_clients`** — builds the nested `ActiveSessionInfo` from the joined columns; nulls when no in-flight session.
- **`routers/stream.py:425`** — direct `validate_token(credentials, db)` call site updated to `validate_token(request, credentials, db)` to match the new signature. Pytest caught this — no manual code review would have.

Pre-existing latent gap closed as a side effect of routing the heartbeat through `validate_token`: every authenticated request now touches `last_seen`, so a "stale" client whose `last_seen` is hours old is genuinely offline rather than just not having re-paired.

#### Frontend

- **`packages/fluxora_core/lib/entities/client_list_item.dart`** — new `ActiveSessionInfo` class with `sessionId`/`startedAt`/`encoderUsed?`/`mediaTitle?` + `fromJson`. `ClientListItem` gains `lastIp: String?` and `activeSession: ActiveSessionInfo?` plus `fromJson` parsing.
- **`apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart`** —
  - **Table row IP cell** (line ~747): reads `c.lastIp ?? '—'` (was hardcoded `'—'`). `const Expanded` dropped to allow runtime value.
  - **Table row "Current Stream" cell** (line ~770): shows `c.activeSession?.mediaTitle ?? '—'` with `TextOverflow.ellipsis`; when populated, switches color from `textFaint` → `textBody`.
  - **Detail-panel info row** (`_buildInfoRows()`): `('IP Address', client.lastIp ?? '—', false)` (was `('IP Address', '—', false)`).
  - **New `_ActiveSessionBlock` widget**: emerald-tinted card (`#10B981` 8 % bg + 20 % border) rendered under the info rows when `client.activeSession != null`. Status dot (streaming) + "Currently Streaming" label + media title + `Encoder $name · $elapsed` line where `elapsed` formats like `1h 23m` / `45m` / `30s`.

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `apps/server/database/migrations/023_clients_last_ip.sql` |
| Modified | `apps/server/services/auth_service.py` (`create_pair_request` accepts `client_ip`; new `update_client_heartbeat`; `list_clients` window-function LEFT JOIN) |
| Modified | `apps/server/routers/auth.py` (`request_pair` passes `client_ip`; `list_clients` builds nested `ActiveSessionInfo`) |
| Modified | `apps/server/routers/deps.py` (`validate_token` gains `request: Request`; calls heartbeat) |
| Modified | `apps/server/routers/stream.py` (line 425 — `validate_token(request, credentials, db)`) |
| Modified | `apps/server/models/client.py` (new `ActiveSessionInfo`; `ClientListItem` gains `last_ip` + `active_session`) |
| Modified | `apps/server/tests/test_auth.py` (+3 tests: pair persists IP, list surfaces fields, ended sessions excluded) |
| Modified | `packages/fluxora_core/lib/entities/client_list_item.dart` (new `ActiveSessionInfo`; `ClientListItem` gains `lastIp` + `activeSession`) |
| Modified | `apps/desktop/lib/features/clients/presentation/screens/clients_screen.dart` (3 cell wirings + new `_ActiveSessionBlock` widget) |
| Modified | `docs/11_design/desktop_redesign_plan.md` (§11.1 F2 + F3 marked ✅; new 2026-05-06 change-log entry) |
| Modified | `docs/00_overview/current_status.md` (test count 474 → 477; F2/F3 paragraph appended) |
| Modified | `AGENT_LOG.md` (this entry) |

### Docs Updated

- `docs/11_design/desktop_redesign_plan.md` — F2 + F3 status flipped to ✅ Done with file-line evidence; change-log entry appended.
- `docs/00_overview/current_status.md` — test count bumped to 477; F2/F3 paragraph added to the "as of" header.

### Decisions Made

- **Heartbeat in `validate_token`, not a dedicated endpoint.** Considered adding a `POST /auth/heartbeat` for explicit pings, but every authenticated request already passes through `validate_token` — piggybacking is one line, has the right cadence (request rate, not poll rate), and it doubles as a fix for the pre-existing "`last_seen` only updates at pair/approval" bug. SQLite write throughput easily covers a home server's request volume.
- **Window function over correlated subquery for the active-session pick.** Two alternatives considered: (a) `LEFT JOIN ... LIMIT 1` — not portable across DB engines, no ORDER BY guarantee per row; (b) correlated subquery — works but reads worse and forces a per-row plan. `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` is the standard idiom, SQLite has supported it since 3.25 (we require 3.40+ for json_each), and it makes the "tie-break by most recent" semantics explicit in the SQL rather than implicit in the executor.
- **Fail-soft heartbeat write.** Wrapped `update_client_heartbeat` in try/except → WARNING log. A transient SQLite write failure (e.g. `database is locked` during a concurrent migration) shouldn't 401 a valid request. The client is still authenticated; the cosmetic refresh just gets skipped this poll.
- **Trust `request.client.host` for `last_ip`.** Currently true behind cloudflared too — the LAN socket sees the loopback IP from cloudflared, not the original public IP. This means tunneled requests will record `127.0.0.1`. The redesign doesn't carry the "real" remote IP through `CF-Connecting-IP` here; if/when it matters we can read that header in the heartbeat path. Logged as a known limitation, not a follow-up — the desktop UI's primary use case is "what LAN IP is this device on" for pair-debug, which this captures correctly.

### Blockers / Open Issues

- **Pre-existing golden test failure** — `test/goldens/m3_dashboard_golden_test.dart` fails with 62.77 % pixel diff against the stored baseline. Dashboard wasn't touched in this batch; the diff is presumably leftover V2 cutover drift that was never re-baselined. Fix: regenerate baseline via `flutter test --update-goldens test/goldens/`. Tracked but not in this PR — fixing a stale golden during an unrelated change just confuses git history.
- **Tunneled `last_ip`** — captures the loopback IP cloudflared forwards from, not the real public IP. See decisions above. Not blocking the redesign milestone since the field's primary value is for LAN device identification.

### Issues / Sharp Edges Discovered

- **`validate_token` direct-call site at `routers/stream.py:425`** — function signature changes that add a parameter at position 0 don't surface in mypy under FastAPI's `Depends()` mechanism because the dependency injector binds by name, not position. The direct call site (not using `Depends`) was the only path the type-checker could catch, and it didn't because Python's gradual typing is loose about call-site positional arguments to async functions. **The pytest suite caught it.** This is a small but real argument for keeping at least one integration test that exercises the `Depends`-resolved path; in this case, `test_stop_stream_wrong_client` did exactly that.
- **`last_seen` was effectively frozen across the codebase before this change.** I started with the assumption that "every authenticated request updates `last_seen`" was already true and that I just needed to add `last_ip` alongside it. Wrong — `last_seen` was only written at pair / approval. The desktop's "online now" tile counts approved+trusted rows, which masks the bug visually. Worth a follow-up audit of the mobile profile screen and any feature that displays `last_seen` to make sure stale values aren't being interpreted as "X minutes ago".

### Proactive Suggestions for Next Work

1. **F6 — Support bundle export endpoint.** The next §11.1 follow-up that's still pending and field-impactful. `POST /api/v1/info/support-bundle` returning a tar/zip of last-N-day logs + `system_stats` snapshot + redacted `user_settings`. Frontend uses existing `file_picker` dep for save dialog.
2. **F10 — Encoder benchmark endpoint.** `POST /api/v1/transcoding/benchmark` running a 10 s lavfi probe per available encoder, returning fps + speed + quality metrics. Wires to the disabled "Run Benchmark" button on the Encoder Settings screen.
3. **`m3_dashboard_golden_test.dart` regenerate** — when the `dart_test.yaml` skip is supposed to be off (per M8 deferred entry), the baseline being stale is a constant source of false-fails. Either regenerate or re-skip until the migration off `golden_toolkit` happens.
4. **`last_seen` audit** on the mobile + desktop surfaces to confirm nothing depends on the old "frozen" semantics. Now that it actually updates, anything that was treating it as "paired-at proxy" might surprise a user.

### Hard Rules Checklist
- [x] No `git commit` / `git push` / `git add` performed.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()` introduced.
- [x] No silent exceptions. Heartbeat failure logged WARNING with full traceback; no bare `except: pass`.
- [x] No hardcoded secrets, ports, paths.
- [x] No new pip / pub deps.
- [x] No layer-boundary violations. Heartbeat write lives in `auth_service`; routers call through; the `validate_token` dep is the right seam (it already had service-layer access via `Depends(get_db)`).
- [x] No git-history rewrites.
- [x] No edits to past migrations. `023` is a new file.
- [x] No raw SQL string concatenation. All parameters bound. The window-function query is a plain SELECT with no user-derived variables.
- [x] No bearer tokens / PII logged. Heartbeat path logs `client["id"]` (the public UUID), never the token.

### Next Agent Should

- **F6 support-bundle** for the next §11.1 cosmetic-follow-ups slice.
- **Stale-baseline audit** on `m3_dashboard_golden_test.dart` — either regenerate or re-skip until the `golden_toolkit` migration.
- **Audit `last_seen` consumers** on mobile + desktop now that the field actually refreshes per-request.
---

## [2026-05-06] — F6 shipped: support bundle export endpoint + Help screen wire-up
**Phase:** Phase 5 desktop redesign — post-M10 polish (§11.1 follow-up)
**Status:** Complete

### What Was Done

The "Generate Bundle" button on the Help screen's Diagnostics card has been disabled since M7 (ship blocker for any field-debug round). Per the prior session's "Next Agent Should" note, F6 was the highest-leverage remaining §11.1 follow-up — the TMDB ISP-block investigation last week would have been twice as fast with a one-click "send me your last N hours of state."

#### Server

- **`apps/server/services/support_bundle_service.py`** (new). Builds a gzipped tar in memory. Members:
  - `metadata.json` — `generated_at`, `server_version`, `python_version`, `platform`, `platform_machine`, `data_dir`.
  - `system/stats.json` — one psutil snapshot via `system_stats.collect(db)`.
  - `system/encoders.json` — encoder self-test results (passed / error / tested_at / suggestion per encoder) read via the new `transcoding_service.get_test_results()` accessor.
  - `settings/redacted.json` — `user_settings` row dumped to JSON, with `tmdb_api_key` / `license_key` / `email` replaced by `***REDACTED***` sentinel when non-null. Null values stay null so the bundle distinguishes "never configured" from "had a value, redacted".
  - `database/schema.sql` — `sqlite_master.sql` DDL only. Rejects rows where `name LIKE 'sqlite_%'` so internal tables stay out. Never carries row data — the test asserts `INSERT` does not appear and a `CanaryDevice` insert does not bleed in.
  - `logs/<filename>` — active rotating log file + up to 4 rotated siblings. Capped at 5 to bound memory.
- **Failure-isolation policy:** every sub-collector wrapped in try/except. A single failure ships a partial bundle with `_collect_error: <repr>` markers in the affected member rather than aborting the download. Test asserts `system_stats.collect` raising still produces a valid bundle.
- **`apps/server/services/transcoding_service.get_test_results()`** (new public accessor) — returns a shallow copy of `_TEST_RESULTS`. Added so the bundle service does not reach into module-private state. Preserves the existing pattern of `get_status()` being the heavy-lifting public API while exposing just the slice the bundle needs.
- **`apps/server/routers/info.py`** — new `POST /info/support-bundle`, `require_local_caller` guard. Returns `Response(content=payload, media_type="application/gzip", headers={"Content-Disposition": f'attachment; filename="{filename}"'})`. Filename format: `fluxora-support-<UTC YYYYMMDD_HHMMSS>.tar.gz`.
- **`apps/server/tests/test_support_bundle.py`** (new, 9 tests). Coverage:
  - bundle contains expected top-level members
  - filename has timestamp prefix + `.tar.gz` extension
  - secret settings get redacted (asserted by absence of the real values in the gzip payload bytes, not just by inspecting the JSON)
  - null secrets stay null
  - schema dump has CREATE statements but no INSERT statements or row data (canary INSERT before bundle generation)
  - metadata fields present
  - sub-collector failure isolation (force `system_stats.collect` to raise; bundle still ships with `_collect_error`)
  - localhost endpoint returns gzip + Content-Disposition; non-localhost returns 403

Server suite **477 → 486** passing.

#### Frontend

- **`packages/fluxora_core/lib/network/endpoints.dart`** — `infoSupportBundle = '$_base/info/support-bundle'`.
- **`packages/fluxora_core/lib/network/api_client.dart`** — new `postBytes(path, {data, queryParameters}) -> ({Uint8List bytes, String? filename})`. Sets `responseType: ResponseType.bytes` on the underlying Dio call; parses Content-Disposition's `filename="<name>"` (RFC 6266 simple form) into the returned record. Reuses the existing `_rethrow` ApiException-mapping path. First binary response method on the client; documented as "for binary downloads (support bundles, archive exports, etc.)".
- **`apps/desktop/lib/features/help/presentation/screens/help_screen.dart`** — `_DiagnosticsCard` converted from `StatelessWidget` → `StatefulWidget`. New `_DiagnosticsCardState._generate()` wires:
  1. Set `_busy = true`; capture `messenger` from current `context` *before* the await (mounted-after-async pattern).
  2. `getIt<ApiClient>().postBytes(Endpoints.infoSupportBundle)` — returns `(bytes, filename)`.
  3. `FilePicker.saveFile(dialogTitle, fileName: result.filename ?? 'fluxora-support.tar.gz', type: FileType.custom, allowedExtensions: ['gz'])` — null = user cancelled, silent return.
  4. `File(savePath).writeAsBytes(result.bytes, flush: true)`.
  5. Snackbar with "Saved support bundle to $savePath".
  - Catches `Exception`, logger.e with stack trace, snackbar with "Could not generate support bundle. See logs."
  - Button label switches to "Generating…" while busy; disabled during the call.
  - Card subtitle updated to mention "Secrets are redacted before export." so the user knows what they're sharing before they click Generate.

`flutter analyze` clean (desktop 26.9 s, fluxora_core 8.3 s).

### Files Created / Modified

| Action | Path |
|--------|------|
| Created | `apps/server/services/support_bundle_service.py` |
| Created | `apps/server/tests/test_support_bundle.py` (+9 tests) |
| Modified | `apps/server/services/transcoding_service.py` (+ new public `get_test_results()` accessor) |
| Modified | `apps/server/routers/info.py` (+ `POST /info/support-bundle`) |
| Modified | `packages/fluxora_core/lib/network/endpoints.dart` (+ `infoSupportBundle`) |
| Modified | `packages/fluxora_core/lib/network/api_client.dart` (+ `postBytes` returning `({Uint8List bytes, String? filename})`) |
| Modified | `apps/desktop/lib/features/help/presentation/screens/help_screen.dart` (`_DiagnosticsCard` stateful + wire) |
| Modified | `docs/11_design/desktop_redesign_plan.md` (F6 row flipped to Done with full implementation summary; new 2026-05-06 change-log entry) |
| Modified | `docs/04_api/01_api_contracts.md` (full endpoint spec for `POST /info/support-bundle`; added to localhost-only auth-modes row) |
| Modified | `docs/09_backend/01_backend_architecture.md` (`support_bundle_service` row + `transcoding_service.get_test_results()` row) |
| Modified | `docs/06_security/01_security.md` (Sensitive Data Handling row for support bundles) |
| Modified | `docs/00_overview/current_status.md` (test count 477 → 486; routers + services lines updated; new 2026-05-06 paragraph) |
| Modified | `AGENT_LOG.md` (this entry) |

### Decisions Made

- **`postBytes` on the shared ApiClient, not a one-shot in the help screen.** First binary endpoint, but unlikely to be the last (encoder benchmark, eventual export-library tarball, etc. would all want the same). Adding a typed method on the shared client now beats sprinkling raw `getIt<Dio>()` calls later. Returns a record `({bytes, filename})` because Content-Disposition is the right place to source the default save name.
- **Gzipped tar, not zip.** `tarfile` + `gzip` are stdlib; `zipfile` is also stdlib but tar+gz is the universal Linux/macOS pattern and is well-supported by Windows 11's built-in extractor since 22H2. Single-file output with one extension (`.tar.gz`) reads cleaner than a `.zip` of mixed-mime members.
- **Build in memory, not stream.** Bundles cap at ~50 MB on a normal home server (logs are biggest at 10 MB × 5 rotations max; everything else is JSON kilobytes). Memory cost is bounded; streaming-tar would have meant either generating-on-demand (FastAPI `StreamingResponse` + async generator) or temp file (cleanup risk if request aborts). Buffered is the simpler safer default.
- **Public `get_test_results()` over reaching into `_TEST_RESULTS`.** Module-private convention exists for a reason. The bundle service is in the same package but not the same module — exposing a one-line accessor (returns a copy) is the right boundary. The new accessor also gives any future consumer the same clean read path.
- **Sub-collector failure isolation, not all-or-nothing.** Operator's case for needing the bundle is "something is broken." The most common collectors-might-fail scenarios — psutil flake on a weird platform, schema corruption, encoder probe state cleared — are exactly the situations where the partial bundle is most useful. `_collect_error` markers tell the receiving engineer what is missing without lying about it.
- **No streaming, no token-based download.** Considered a two-step "request a bundle, get a one-shot URL, fetch bytes from the URL" flow to allow large bundles. Rejected — the localhost-only constraint means the operator's machine *is* the server's machine, the bytes never leave that box during generation, and the OS file picker handles the disk write. Two-step adds state without benefit.
- **Subtitle copy includes "Secrets are redacted before export."** Trust signal — the operator clicks Generate knowing the bundle is safe to attach to a public issue. Without that assurance the button stays scary.

### Blockers / Open Issues

- **Tunneled `last_ip` carries through to the bundle.** `settings/redacted.json` doesn't include the `clients` table at all (settings dump is `user_settings` only), but if a future iteration adds a `clients_summary` member it should respect the same tunneling caveat documented in [`gotchas.md`](docs/12_guidelines/03_gotchas.md) — record `last_ip` only when it's a real public IP we want to share.
- **No size cap on the response.** A misconfigured server with a 100 GB log file and disabled rotation would stream that file into memory then return 100 GB. The default rotation (10 MB × 5) bounds this; if rotation is ever disabled by mistake the bundle endpoint would OOM the server. Not worth a hard cap today (the operational shape is single-tenant home server), but worth a cap if we ever ship a multi-tenant build.

### Issues / Sharp Edges Discovered

- **`file_picker` 11.0.2 dropped the `FilePicker.platform` accessor.** The package's older `FilePicker.platform.saveFile(...)` form is gone in 11.x; `FilePicker.saveFile(...)` is now a static. The library_screen had migrated to the new form; help_screen didn't (was first wire-up). Caught by `flutter analyze`. Worth a `gotchas.md` entry if more file_picker call sites land — the type checker catches it cleanly so the cost is low, but the pattern of "API moved to static" repeats in Flutter packages and is easy to miss in PR review.
- **`response.headers.value('content-disposition')` is the right Dio API for a single-valued header.** `headers.map['content-disposition']` returns `List<String>?` and forces an empty-list / null dance; `.value(...)` returns the `String?` directly. Used in `ApiClient.postBytes`.
- **`postBytes` had to import `dart:typed_data` for `Uint8List`.** Without that import the symbol resolves through `flutter` re-exports in app code but not in the `fluxora_core` package (no Flutter dep). Easy miss because the IDE auto-completes the type without flagging the import.

### Proactive Suggestions for Next Work

1. **F10 — Encoder benchmark endpoint** is the last shippable §11.1 item. `POST /api/v1/transcoding/benchmark` running a 10 s lavfi probe per available encoder, returning fps + speed + quality metrics. Wires the disabled "Run Benchmark" button on Encoder Settings. Similar shape to F6 (one server endpoint + one frontend wire-up).
2. **Audit other `pubspec.yaml` deps for major-version moves** the way `file_picker.platform → static` change happened. `dio` 6.x is in early adoption, `flutter_bloc` 9.x is settled, but the 5.x → 6.x dio jump removed several APIs. Worth a one-pass before next dep refresh.
3. **Add `FilePicker.saveFile` to gotchas.md** if a third call site shows up — pattern is "package version was bumped, static method moved, only flutter_analyze catches it."

### Hard Rules Checklist
- [x] No `git commit` / `git push` / `git add` performed.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()` introduced. Help screen wire uses the project `Logger()` pattern.
- [x] No silent exceptions. Help screen catches `Exception`, logs with stack trace, surfaces snackbar; service-level sub-collectors log WARNING with `repr(exc)`.
- [x] No hardcoded secrets, ports, paths.
- [x] No new pip / pub deps. `tarfile` + `gzip` are stdlib; `file_picker` was already in the desktop pubspec; `url_launcher` was added in the F5 chunk earlier today.
- [x] No layer-boundary violations. New service lives at `services/support_bundle_service.py`; new accessor on `transcoding_service`; router glue only in `routers/info.py`.
- [x] No git-history rewrites.
- [x] No edits to past migrations.
- [x] No raw SQL string concatenation. Schema dump uses bound parameters; the new accessor reads `sqlite_master` via parameterised SELECT.
- [x] No bearer tokens / PII logged. Service logs only the byte size + log file count on success; sub-collector failure logs include `repr(exc)` of the exception, never the underlying secret.

### Next Agent Should

- **F10 encoder benchmark endpoint** if completing the §11.1 sweep is the goal.
- **Push the 4 unpushed commits** if the operator wants today's work on the remote.
- **Verify the support bundle end-to-end on the operator's machine** — restart the server, click Generate Bundle on Help screen, confirm the saved `.tar.gz` extracts cleanly with the expected member tree.
---

## [2026-05-06] — Help/Settings audit pass 2: A8–A13 wired + correct repo URLs
**Phase:** Phase 5 desktop redesign — post-audit cleanup
**Status:** Complete

### What Was Done

User-flagged second batch after the first audit pass: links pointing at the wrong repo, plus the deeper A8–A13 follow-ups that were deferred to the manual-tasks doc.

#### Help screen link URLs corrected

`help_screen.dart` `_kLinks` constants were pointing at `github.com/marshalx/fluxora` — that account / repo doesn't exist. Swapped all four entries to the canonical `Marshal-GG/Fluxora-Personal-Streaming-Platform` (matching what the Settings → About → Links card already used). Documentation now points at `/wiki`, Community at `/discussions`, Report Issue at `/issues`, What's New at `/releases`.

#### A8 — `SettingsCubit` now wires all 13 §7.10 extended-settings fields

- `SettingsState.SettingsLoaded` extended with 13 new fields: `defaultLibraryView`, `scanLibrariesOnStartup`, `generateThumbnails`, `preferredMode`, `enableMdns`, `enableWebrtc`, `relayServerUrl`, `defaultQuality`, `aiSegmentDurationSeconds`, `enablePairingRequired`, `sessionTimeoutMinutes`, `enableLogExport`, `customServerUrl`. Defaults match `models/settings.py` `UserSettingsResponse` so an offline load and a successful load produce the same baseline values.
- `SettingsCubit.loadSettings()` reads each one from `GET /settings`. Best-effort: missing fields fall back to defaults; types preserved (`int? as int?`, `bool? as bool?`, `String? as String?`).
- `SettingsCubit.saveSettings()` accepts all 13 as optional kwargs and emits them in the PATCH body via the `?value` operator (already used for transcoding fields). Each field nulls out at the call site when unchanged so the PATCH stays minimal — server logs are clean, not flooded with no-ops.

#### A9 — `_NetworkTab` flattened to stateless

`_NetworkTabState` was holding `_enableMdns / _enableWebrtc / _preferredMode / _relayCtrl` locally. Even if A8 had wired them, after a screen rebuild the values would revert. Converted `_NetworkTab` to `StatelessWidget`; the four values now live on the parent `_SettingsViewState`. The `Tab` switch passes them down + receives `ValueChanged<T>` callbacks for each.

#### A8/A12/A13 — `_syncFromState` reseats every controller from state

`_relayCtrl`, `_customUrlCtrl`, `_sessionTimeoutCtrl`, `_aiSegmentCtrl` are now reseated on every `SettingsLoaded` (not gated by `_initialized`) so a fresh server-side change picks up automatically. Non-text values (`_defaultLibraryView`, `_scanOnStartup`, `_generateThumbnails`, `_preferredMode`, `_enableMdns`, `_enableWebrtc`, `_defaultQuality`, `_enablePairingRequired`, `_enableLogExport`) are seeded once on first load to avoid clobbering in-progress edits.

`_aiSegmentCtrl` default fallback also corrected from `'6'` (no source — looked like a typo) to `'4'` matching the server's `UserSettingsResponse` default of `4`.

#### A10 — System Status row reads SystemStatsCubit

`_SystemInfoCard` calls `context.select<SystemStatsCubit, SystemStatsState>` and derives the row from `(latest, errorMessage)`:
- `latest != null && errorMessage == null` → emerald "Running" + online dot.
- `errorMessage != null && latest != null` → red "Degraded" + offline dot (last known sample is stale but we have one).
- `errorMessage != null && latest == null` → red "Unreachable" + offline dot (never reached).
- Otherwise (initial state before first poll lands) → muted "Checking…" + idle dot.

The shell-scoped `SystemStatsCubit` polls at 1.1 s already; this card is just a new consumer.

#### A11 — Max Concurrent Streams as a read-only chip

The greyed-out `FluxTextField(enabled: false)` was confusing — looked like a typo'd disabled input. Replaced with a `FluxChip` (`'<n> · tier-locked'` neutral or `'Unlimited'` purple) wrapped in a `Tooltip` explaining that the value is set automatically by subscription tier and pointing at the Subscription screen for upgrades. Removes any "did the field break?" ambiguity.

#### Save-flow change detection

`_save()` rewritten to compare every field against `_loadedSnapshot` and pass `null` for unchanged fields. The `?value` PATCH-body operator drops nulls — server only sees the diff. Mirrors the existing transcoding-fields pattern.

### Files Created / Modified

| Action | Path |
|--------|------|
| Modified | `apps/desktop/lib/features/help/presentation/screens/help_screen.dart` (link URLs `marshalx/fluxora` → `Marshal-GG/Fluxora-Personal-Streaming-Platform`) |
| Modified | `apps/desktop/lib/features/settings/presentation/cubit/settings_state.dart` (13 new fields + extended copyWith) |
| Modified | `apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart` (loadSettings reads 13 fields; saveSettings accepts 13 fields + emits in PATCH body) |
| Modified | `apps/desktop/lib/features/settings/presentation/screens/settings_screen.dart` (A8/A9/A10/A11/A12/A13 — ~250 LOC: lift Network state, _syncFromState extension, _save change-detection, _SystemInfoCard SystemStatsCubit wire, Max Concurrent Streams chip+tooltip, removed `_NetworkTabState`) |
| Modified | `docs/10_planning/04_manual_tasks.md` (A8–A13 sections flipped to ✅ Done with implementation summary) |
| Modified | `AGENT_LOG.md` (this entry) |

### Decisions Made

- **`?value` PATCH operator + null-on-unchanged at the call site, not in the cubit.** The cubit's `saveSettings` could in theory diff against an internal snapshot, but the screen already owns `_loadedSnapshot` and the per-field comparison is a one-line ternary at each call site. Keeping diff logic where the controllers live makes future per-field validation easier (e.g. "only send custom_server_url if it parses as a URL"). The cubit just translates kwargs into the PATCH body.
- **Reseat free-form text controllers on every load, but seed switch/select state once.** Text controllers reading divergent server values is fine — the user can re-edit if mid-keystroke. Seeding non-text state every time would clobber in-progress toggle changes the user hasn't saved yet, which is silently destructive. The `_initialized` guard preserves the existing pattern; the new fields follow it.
- **Stateless `_NetworkTab` over keeping it Stateful and seeding in `didUpdateWidget`.** Stateful would have meant duplicating the seeding logic across the Network tab and `_SettingsViewState._syncFromState`. Stateless pushes everything to the parent — single source of truth, no possibility of drift. Tradeoff: the network controls now rebuild whenever any other state on the page rebuilds, but the rebuild is cheap and the screen is not perf-critical.
- **A11 chip + tooltip over inline help icon.** A help icon next to a disabled input still leaves the question "is this broken or intentionally locked?" The chip says "this is a value, not an input" at a glance; the tooltip explains why. Same UX is now consistent with how Subscription Tier renders (also a `FluxChip`).
- **A10 "Degraded" vs "Unreachable" distinction.** Could have collapsed both to a single offline state, but the operator's troubleshooting path differs: "Degraded" means the server was up at some point this session and may be transiently flaky (check uptime, FFmpeg subprocess); "Unreachable" means the URL or auth might be wrong (check Settings → Connection URL). Two labels = two different first guesses.

### Blockers / Open Issues

- **No frontend test for the wireless-fields fix.** Server-side `test_settings_extended.py` already covers PATCH round-trips for every column (20 passing), and `flutter analyze` is clean. A widget test that drives the UI through a save would be valuable but bundles with the broader desktop-test infra work tracked under "golden_toolkit migration." Not blocking — the integration is mechanical and the server side is well-tested.
- **`_aiSegmentCtrl` and `_sessionTimeoutCtrl` text validation** — currently free-form numeric input via `FilteringTextInputFormatter.digitsOnly`. The server clamps to `[1, 30]` and `[1, 1440]` respectively and returns 422 for out-of-range; the frontend just relies on the server-error snackbar. Could pre-validate on save, but the current pattern matches every other settings field — out of scope.

### Issues / Sharp Edges Discovered

- **Dart record-style triple destructure declarations don't exist.** Tried `final (String label, Color color, DotStatus dot);` as a forward-declaration before an if/else — that's a parse error (`type` `;` is treated as a record literal at expression position). Worked around with three `late final` declarations. Worth a gotcha entry if the pattern shows up again — Dart 3 records support destructuring assignment + pattern matching, but not "declare uninitialised vars in record shape."
- **Stateful → Stateless conversion forgets `widget.X` references** in unchanged blocks. `widget.cubit.checkRemoteAccess()` and `_relayCtrl` survived the conversion's first pass because they're inside conditional branches the editor pattern-match didn't touch. `flutter analyze` caught both. Worth scripting "convert to stateless" as a recipe: rename the class, drop `State<...>`, replace every `widget.` with bare access, replace every instance field with constructor param. The compiler errors are mechanical to follow.
- **`SystemStatsState` is a single class, not a sealed-with-subclasses union.** The pattern-match `switch (stats) { SystemStatsLoaded() ... SystemStatsError() ... }` compiled into "undefined class" errors. Re-checked the cubit: it's a single state class with nullable `latest` + nullable `errorMessage`. The audit summary was assuming a different shape than the code. Pattern-matching on `(latest, errorMessage)` tuples works; pattern-matching on subclass types doesn't because there are no subclasses.

### Proactive Suggestions for Next Work

1. **F10 — Encoder benchmark endpoint** is the last shippable §11.1 follow-up. Same shape as F6: one server endpoint + one frontend wire-up. Fits a single small PR.
2. **Widget test for the settings save flow** — drive a `SettingsCubit` through a `BlocConsumer`, toggle each field, click Save, assert the PATCH body. Catches regressions like A8 silently. Bundles with the `golden_toolkit` → `alchemist` migration if that's the broader test-infra pass.
3. **Per-field validation on numeric settings** (`session_timeout_minutes`, `ai_segment_duration_seconds`) — currently relies on server 422 + snackbar. Pre-validate on Save with `int.tryParse` + range check; show inline error before the network round-trip.

### Hard Rules Checklist
- [x] No `git commit` / `git push` / `git add` performed.
- [x] No agent / AI branding.
- [x] No `print()` / `debugPrint()` introduced. Cubit logging via `Logger`.
- [x] No silent exceptions. `_save` reuses the existing two-phase persist + PATCH error mapping (4xx vs 5xx vs CONNECTION_ERROR), surfacing each via `SettingsError`.
- [x] No hardcoded secrets, ports, paths.
- [x] No new pip / pub deps.
- [x] No layer-boundary violations.
- [x] No git-history rewrites.
- [x] No edits to past migrations.
- [x] No raw SQL string concatenation. PATCH body is JSON, server-side parameter binding unchanged.
- [x] No bearer tokens / PII logged.

### Next Agent Should

- **F10 encoder benchmark** to close out the §11.1 sweep.
- **Widget test** for the settings save flow when the test-infra refresh lands.
- **Push the unpushed commits** when ready.
---

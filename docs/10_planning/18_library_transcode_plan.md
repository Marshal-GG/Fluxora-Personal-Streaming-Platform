# User-Initiated Library Transcode Plan

> **Category:** Planning
> **Status:** Drafted 2026-05-09. Not started. Awaiting design-decision answers (§9) before scope-lock.
> **Scope:** A user-driven workflow to pre-transcode AV1 / VP9 (and optionally HEVC) sources to H.264 + AAC, stored side-by-side with the original, so that subsequent playback stream-copies instead of doing live software-decode → NVENC.
> **Non-goals:** Auto-transcode without user consent. Quality-rescaling (downscaling). Anything that mutates or deletes the original source file. Subtitle / chapter editing.
> **Triggered by:** Operator-reported pain 2026-05-09 — playing a 60 MB AV1 YouTube `.mkv` resulted in CPU-bound software AV1 decode → NVENC encode pipeline running at ~1× realtime, segments produced at the player's own playback rate, intermittent `seg00018 404 → retry` stalls. Source: `D:\user\24-08-2021\Video\Song\Avicii - The Nights - YouTube.mkv` (1080p AV1, 3:10, 60 MB).

---

## 1 · Why this exists

The streaming pipeline already does the **right thing** for problem codecs: cuvid auto-fallback (§17 / `ffmpeg_service.py`) hands off to software decode + NVENC when the GPU's NVDEC can't take the source profile. But "the right thing" for AV1 / VP9 on a non-AV1-NVDEC GPU is still **CPU-bound at 1× realtime**, which means:

1. First-segment latency 6-10 s (vs <1 s for stream-copy).
2. Player buffer-ahead asks for segments faster than they're produced → 404 → retry stalls visible to the user as mid-playback hitches.
3. CPU load on the server during every play of the same file.

The proper fix is **one-time, opt-in pre-transcode**. Pay the cost once, stream-copy forever after.

**Why not auto-transcode?**
- Disk: a 60 MB AV1 → ~150 MB H.264 at cq 19 is 2.5× growth. A 4 GB AV1 movie → ~10 GB. User must consent.
- Compute: software AV1 decode of a feature-length file is 20-40 minutes of CPU on a typical machine. User needs to be in control of when this runs.
- Some users want the AV1. Don't presume.

---

## 2 · User flow (target)

```
Library scan completes
        │
        ▼
┌───────────────────────────────────────────────┐
│ Toast: "12 files use codecs that transcode    │
│         live. Pre-convert for instant playback?" │
│ [Review files] [Dismiss]                      │
└───────────────────────────────────────────────┘
        │ click "Review files"
        ▼
┌───────────────────────────────────────────────┐
│ Library page filtered to "Live-transcode      │
│ candidates" with a checkbox column:           │
│                                               │
│ ☑ Avicii - The Nights.mkv      AV1   60 MB    │
│ ☑ Some Big File.mkv            AV1   3.2 GB   │
│ ☐ Old Movie.webm               VP9   780 MB   │
│ ...                                           │
│                                               │
│ Selected: 2  •  Source: 3.26 GB               │
│ Estimated: ~7.8 GB H.264 / ~50 min runtime    │
│ Free disk on D:: 412 GB                       │
│                                               │
│           [Cancel]  [Start transcode]         │
└───────────────────────────────────────────────┘
        │ click Start
        ▼
┌───────────────────────────────────────────────┐
│ Jobs panel (dockable, persistent until        │
│ user dismisses):                              │
│                                               │
│ Avicii - The Nights.mkv   ▓▓▓▓▓▓▓▓▓▓ Done    │
│ Some Big File.mkv         ▓▓▓░░░░░░░  31% …  │
│                                               │
│ [Pause queue] [Cancel selected]               │
└───────────────────────────────────────────────┘
```

The "Live-transcode candidates" filter is **also reachable** from the library sidebar at any time, not only post-scan. Multi-select is the primary interaction; per-row "Convert this file" exists too for the one-off case.

---

## 3 · Data model

### 3.1 New columns on `media_files`

| Column | Type | Why |
|---|---|---|
| `transcoded_path` | TEXT NULL | Absolute path to the H.264 sidecar, or NULL |
| `transcoded_size_bytes` | INTEGER NULL | For "stream uses transcoded copy" UI, disk accounting |
| `transcoded_at` | INTEGER NULL | Epoch seconds; lets us invalidate if source's `mtime` advances past it |

Indexed: `transcoded_path` (NULL filtering for library queries).

### 3.2 New table `transcode_jobs`

```sql
CREATE TABLE transcode_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id TEXT NOT NULL REFERENCES media_files(id) ON DELETE CASCADE,
    target_codec TEXT NOT NULL DEFAULT 'h264',           -- future-proof; v1 only writes 'h264'
    encoder TEXT NOT NULL,                               -- 'h264_nvenc' / 'libx264' / etc.
    quality_preset TEXT NOT NULL,                        -- 'slow_cq19' / 'medium_cq21' / etc.
    status TEXT NOT NULL CHECK(status IN
        ('queued','running','done','failed','cancelled')),
    progress_pct REAL NOT NULL DEFAULT 0.0,
    eta_sec INTEGER NULL,
    error TEXT NULL,                                     -- last 240 chars of stderr on failure
    output_path TEXT NULL,                               -- the final .h264.mkv (NULL until done)
    created_at INTEGER NOT NULL,
    started_at INTEGER NULL,
    finished_at INTEGER NULL
);
CREATE INDEX idx_transcode_jobs_status ON transcode_jobs(status);
CREATE INDEX idx_transcode_jobs_file ON transcode_jobs(file_id);
```

Migration: `apps/server/database/migrations/021_transcode_jobs.sql`.

---

## 4 · Server changes

### 4.1 New service `apps/server/services/transcode_service.py`

```python
class TranscodeService:
    async def candidates(db) -> list[FileCandidate]: ...
    async def queue(db, file_ids: list[str], opts: TranscodeOpts) -> list[int]: ...
    async def cancel(db, job_id: int) -> bool: ...
    async def list_jobs(db, status: list[str] | None = None) -> list[Job]: ...
    async def progress(db, job_id: int) -> Job: ...
```

Worker loop (single-threaded, started at app boot):

```python
async def _worker():
    while True:
        job = await _pop_queued()                # SELECT … LIMIT 1 FOR UPDATE-equiv
        if not job: await asyncio.sleep(2); continue
        try:
            await _run_ffmpeg_for(job)            # streams progress via stderr parse
        except CancelledError:
            await _mark_cancelled(job)
        except Exception as exc:
            await _mark_failed(job, exc)
        else:
            await _mark_done(job)                 # also writes media_files.transcoded_path
```

Concurrency cap: **1 by default**. Settings-configurable up to `max(1, cpu_count // 2)` once the user understands the trade-off (transcoding alongside streaming hurts streaming responsiveness).

### 4.2 New router `apps/server/routers/transcode.py`

| Method | Path | Body / Query | Response |
|---|---|---|---|
| `GET` | `/api/v1/transcode/candidates` | — | `[{file_id, name, size, codec, est_output_size}]` |
| `POST` | `/api/v1/transcode/queue` | `{file_ids: [...], encoder?, preset?}` | `{job_ids: [...]}` |
| `GET` | `/api/v1/transcode/jobs` | `?status=running,queued` | `[{id, file_id, status, progress_pct, eta_sec, error}]` |
| `DELETE` | `/api/v1/transcode/jobs/{id}` | — | `204` (cancels if running, removes if queued) |
| `POST` | `/api/v1/transcode/jobs/{id}/retry` | — | `{new_job_id}` |

Wired through `apps/server/main.py` like other routers. Auth: same bearer-token validation as the rest.

### 4.3 Streaming pipeline change (one line of logic)

In `ffmpeg_service.start_stream`, after resolving `file_path` from `media_files`:

```python
file_row = await library_service.get_file(db, file_id)
playback_path = file_row.get("transcoded_path") or file_row["path"]
# Optional verification: stat the transcoded path; if missing, fall back to source
# and log a warning (probably the user moved/deleted it manually).
```

The transcoded copy is, by construction, H.264 + AAC + MKV → matches the existing `direct_remux_h264` branch → stream-copies → instant.

### 4.4 Library scan change

`library_service.scan_library` already runs ffprobe per file. Add to its existing dispatch:

```python
codec = probe_result.video_codec
codec_low = (codec or "").lower()
is_candidate = codec_low in {"av1", "vp9"}  # §9 will decide if hevc joins this
# Stored as a derived flag on the file row in DB? Or computed at query time?
# Recommendation: computed at query time — codec is already in DB, no schema growth.
```

The `/api/v1/transcode/candidates` endpoint runs the WHERE clause directly:
```sql
SELECT id, name, size, video_codec FROM media_files
WHERE LOWER(video_codec) IN ('av1','vp9') AND transcoded_path IS NULL
```

### 4.5 FFmpeg invocation per job

```
ffmpeg -y -hide_banner -loglevel info -progress pipe:2 \
  -i <source> \
  -map 0:v:0 -map 0:a? -map 0:s? \
  -c:v h264_nvenc -preset slow -cq 19 -profile:v high -pix_fmt yuv420p \
  -c:a copy \                 # if source audio is AAC; else `-c:a aac -b:a 192k`
  -c:s copy \                 # subtitle passthrough
  -movflags +faststart \
  <source>.h264.mkv
```

`-progress pipe:2` emits `out_time_ms=…` lines to stderr; the worker parses these to update `progress_pct` and `eta_sec` in the DB.

Encoder fallback: if `h264_nvenc` is not in the encoder registry's `available_encoders`, fall back to `libx264` and warn in the job log. `slow + cq 19` for NVENC; `slow + crf 19` for libx264 (visually equivalent).

Output filename: `<original_basename>.h264.<original_extension>`. Lives next to the source. **Never overwrites** an existing file — if `<original>.h264.mkv` exists, fail the job with `output_path_collision` so the user can investigate.

### 4.6 Cancellation

Cancel = SIGTERM the FFmpeg process + delete the partial output file. Mark job `cancelled`. Rate-limit cancel-and-resubmit so a UI bug can't thrash.

### 4.7 Resilience

- Worker crash: orphan `running` rows on next boot → mark them `failed` with `error="server restarted mid-job"`. User can retry.
- Disk-full mid-encode: FFmpeg returns nonzero, error captured, partial file deleted. Surface a specific error string in the UI.
- Source `mtime` change: stale-detection runs on next library scan. If `transcoded_at < source.mtime`, mark the transcoded copy as **stale** (advisory; don't auto-delete). UI shows a "source has changed since last transcode" badge.

---

## 5 · Desktop control panel changes

### 5.1 New page or panel

A "Transcode" panel inside the Library section, with three tabs:

| Tab | Contents |
|---|---|
| **Candidates** | Multi-select list of files matching the candidate criteria, with an aggregate-disk / aggregate-runtime estimator and a `[Start transcode]` button |
| **Queue** | Currently-running + queued jobs, with progress bars, cancel buttons |
| **History** | Done / failed / cancelled jobs, with retry buttons on the failed ones |

Filter chips on Candidates: codec (AV1/VP9/HEVC), size (>1 GB, >100 MB, etc.), library.

### 5.2 Post-scan toast

After a `library_service.scan_library` invocation that finds new candidates, the desktop UI receives a notification (existing notifications WS — `apps/server/services/notifications_service.py`) with:

```json
{"type": "scan_completed",
 "candidate_count": 12,
 "candidate_size_bytes": 8543201234}
```

UI shows a non-modal toast linking to the Candidates tab. Dismissible. Don't re-show until next scan.

### 5.3 Estimation logic (client-side)

| Estimate | Formula |
|---|---|
| Output size | `source_size × 2.0` for AV1, `× 1.5` for VP9, `× 1.0` for HEVC. Wide ranges; surface as "≈". |
| Runtime | `source_duration_sec / N×realtime`, where N=`{nvenc:5.0, libx264_slow:0.8}`. |
| Free disk | `os.statvfs` / `GetDiskFreeSpaceEx` on the library's drive. |

These are estimates — make that visually clear in the UI ("~", italic, tooltip explaining ±50% spread).

---

## 6 · Mobile changes

**Zero.** The mobile player streams from `/api/v1/stream/start/{file_id}`, gets back a session and a playlist URL. Whether the playlist serves stream-copy of the source or stream-copy of the transcoded sidecar is invisible to the mobile.

The desktop is the only client that needs UI for this feature.

---

## 7 · Sequenced milestones

```
M1 — Schema + service skeleton                       │ ~1 h    │ low risk    │
M2 — Worker loop + FFmpeg invocation                 │ ~2 h    │ medium risk │
M3 — REST API + tests                                │ ~1 h    │ low risk    │
M4 — Streaming pipeline rewires playback path        │ ~30 min │ medium risk │
M5 — Desktop Candidates / Queue / History UI         │ ~3 h    │ medium risk │
M6 — Post-scan toast + notification wiring           │ ~1 h    │ low risk    │
M7 — Stale-detection on rescan                       │ ~30 min │ low risk    │
M8 — Cancel / retry + crash-recovery on boot         │ ~1 h    │ medium risk │
─────────────────────────────────────────────────────│─────────│─────────────│
Total                                                │ ~10 h   │             │
```

Each milestone ships independently. M1-M4 give a fully working backend (queue via curl, stream from the transcoded copy). M5+ surfaces it.

---

## 8 · Tests

### 8.1 New server tests

- `test_transcode_service.py`:
  - candidate detection picks AV1/VP9, ignores H.264, ignores files already transcoded
  - queue dedup: same file_id twice in one batch → one job, not two
  - cancel during running → process killed + partial output deleted
  - retry of a failed job → new job_id, original error preserved in history
- `test_transcode_router.py`: 401 / 403 / payload validation; same shape as existing routers.
- `test_stream_uses_transcoded_path.py`: when `media_files.transcoded_path` is set + the file exists on disk, the FFmpeg cmd reads from that path, not the source.

### 8.2 New desktop tests

- Candidate list pumps + multi-select gestures (dart `flutter_test`).
- Estimation text rendering with edge cases (0 bytes, 1 file, 100 files).
- Job-progress widget renders running / queued / done / failed states from a fake state stream.

---

## 9 · Open design questions (need user answer before M1 starts)

1. **Codec target — H.264 only, or also HEVC?**
   - H.264 covers all clients and stream-copies on every device.
   - HEVC files are ~30% smaller but still hit the cuvid path on some sources (color metadata) and aren't faster to play. Recommendation: **H.264 only for v1**, revisit if a user has a strong HEVC preference.

2. **Quality preset(s) exposed to the user?**
   - Default: `nvenc preset=slow cq=19` ≈ visually transparent, ~2× source size.
   - Faster option: `nvenc preset=p4 cq=23` ≈ "good enough", ~1.5× source size, ~1.5× faster.
   - Smaller-output option: `nvenc preset=slow cq=23` ≈ visible degradation, ~1.2× source size.
   - Recommendation: **Default-only for v1** (cq 19 slow). Add presets in v1.1 if users ask.

3. **Concurrency cap default?**
   - 1 keeps streaming responsive.
   - 2 halves the wall-clock for a multi-file batch but stresses the CPU/GPU during streaming.
   - Recommendation: **1 default, settings slider 1-4 with a clear "may slow streaming" warning at >1**.

4. **HEVC sources — also flag as candidates?**
   - HEVC stream-copies just fine via the existing `direct_remux_hevc` path → fmp4. So pre-transcoding HEVC → H.264 only buys you "MPEG-TS instead of fmp4 segments" which is mostly invisible.
   - Recommendation: **NO**, exclude HEVC from candidates. AV1 + VP9 only.

5. **Subtitle / chapters / multi-track audio handling?**
   - `-c:s copy -map 0` covers most cases. Edge cases: PGS subs in MKV → may need MOV_text re-encode; multi-track audio → keep all tracks, copy as-is.
   - Recommendation: **copy everything, fail loudly if FFmpeg complains**. Document per-source quirks if they emerge.

6. **What happens if the user transcodes, then the source file moves?**
   - Library rescan re-discovers under a new path; the `transcoded_path` row is now orphaned.
   - Options: (a) keep the orphan transcoded file, attached to nothing; (b) delete it; (c) try to find the new source by hash and re-link.
   - Recommendation: **(a) for v1 — keep the orphan, log a warning, surface it in History tab as "source missing"**. Future enhancement: link by content hash.

7. **Original file disposition after successful transcode?**
   - Always preserve. User can delete manually after verifying.
   - Recommendation: **never auto-delete**. Maybe v1.1 add a "delete originals after verification" power-user toggle.

8. **Where does the transcoded file live?**
   - Side-by-side with the source: `<source_dir>/<basename>.h264.<ext>`.
   - Centralized cache dir: `<config_dir>/transcoded/<file_id>.mkv`.
   - Recommendation: **side-by-side**. The user already trusts that directory; backup tools follow the source naturally; deleting the original takes the transcode with it (good for cleanup).

---

## 10 · Files Created / Modified (forecast)

| Action | Path | Why |
|--------|------|-----|
| 🆕 | `apps/server/database/migrations/021_transcode_jobs.sql` | Schema |
| 🆕 | `apps/server/services/transcode_service.py` | Worker, queue, candidate detection |
| 🆕 | `apps/server/routers/transcode.py` | REST API |
| 🆕 | `apps/server/models/transcode.py` | Pydantic models for jobs / requests |
| ✏️ | `apps/server/services/ffmpeg_service.py` | One-line `playback_path = transcoded or source` swap |
| ✏️ | `apps/server/services/library_service.py` | Probe-codec already done; no schema-change needed |
| ✏️ | `apps/server/services/notifications_service.py` | Emit `scan_completed` payload with candidate counts |
| ✏️ | `apps/server/main.py` | Mount transcode router; start worker on app boot |
| 🆕 | `apps/server/tests/test_transcode_service.py` | Unit tests |
| 🆕 | `apps/server/tests/test_transcode_router.py` | API tests |
| ✏️ | `apps/server/tests/test_stream.py` | Add: stream uses transcoded_path if present |
| 🆕 | `apps/desktop/lib/features/transcode/` | New feature folder (cubit, screens, widgets) |
| ✏️ | `apps/desktop/lib/features/library/...` | Add Candidates filter chip + post-scan toast hook |
| ✏️ | `docs/04_api/01_api_contracts.md` | Document the new endpoints |
| ✏️ | `docs/03_data/02_database_schema.md` | Document the new table + columns |
| ✏️ | `docs/00_overview/current_status.md` | Test counts; feature line |
| ✏️ | `docs/10_planning/01_roadmap.md` | New row for "Library transcode" |

---

## 11 · Cross-references

- Streaming pipeline that this works around: [`11_streaming_pipeline_issues.md`](./11_streaming_pipeline_issues.md), [`16_streaming_resume_and_throttle_plan.md`](./16_streaming_resume_and_throttle_plan.md), [`17_ffmpeg_diagnostics_and_m2_retry_plan.md`](./17_ffmpeg_diagnostics_and_m2_retry_plan.md).
- Encoder selection logic this builds on: `apps/server/services/encoder_registry.py`, `apps/server/services/session_router.py`.
- Library scan it hooks into: `apps/server/services/library_service.py::scan_library`.
- Existing notifications service it extends: `apps/server/services/notifications_service.py`.

---

## 12 · TL;DR

User-driven, opt-in pre-transcode of AV1 / VP9 sources to H.264 sidecars so playback stream-copies. **Library scan flags candidates → desktop UI shows a toast + filter view → user multi-selects → server queue runs FFmpeg jobs in the background → playback automatically uses the transcoded copy.** ~10 hours of work split across 8 milestones; M1-M4 backend-only, M5+ surfaces it. Eight design questions in §9 are gating M1.

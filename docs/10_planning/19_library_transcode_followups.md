# Library Transcode — Phase 2 Follow-ups

> **Category:** Planning
> **Status:** Drafted 2026-05-09. **Strategy pivot 2026-05-09 (same day):** v1 launches with client-side decoding as the **default streaming mode**. M7 shipped same day as launch-priority commit `627cdf1`. **M1, M2, M3, M4, M5, M6, M8 ALL ✅ shipped 2026-05-09** via 2 parallel Opus subagents — full plan 19 scope is closed. Server suite **734 → 775 (+41)**; desktop **104 → 113 (+9)**.
> **Scope (v1 LAUNCH only):** A single global `Settings → Transcoding → Streaming mode` toggle that switches between `client-decode` (default — server stream-copies AV1/VP9 directly; modern devices hardware-decode) and `server-transcode` (current behaviour — server live-transcodes to H.264 before streaming). Sidecar pickup unchanged: if a transcoded sidecar exists, it always wins regardless of mode.
> **Scope (v1.1 deferred):** The four pain points originally drafted here — quality preset chooser, storage-location chooser, storage-info UI strip, folder-grouped tree — stay deferred. They're real and worth shipping, just not blocking launch. See §7 milestone table for which are which.
> **Non-goals (still out for v1.2+):** Multi-job concurrency slider · resolution downscale (4K → 1080p sidecar) · per-device codec capability negotiation · auto-retry on transient failures · "detect orphan sidecars on disk" cleanup tool · re-link by content hash. See §13.
> **Triggered by:** Operator real-device test of plan 18 — *"the copy of the files are too big to handle, almost 4 times the size, also keeping all new file in the same folder confuses in long term"* — followed by the architectural reframe — *"we will just launch project currently with client side decoding, priority casue that is more reliable and work with more clients as server load is very low … dont remove the server work code, for now just create a toggle in encoding settings."*

---

## 1 · Why this exists

Plan 18 shipped a working pipeline (queue → worker → sidecar → stream-copy) but the **defaults are wrong for everyday use**:

1. **Quality preset is too aggressive.** `nvenc cq=19` is visually-lossless mastering quality. For YouTube-sourced AV1 (typically 2 Mbps source) the H.264 sidecar lands at 8-10 Mbps → ~4× the source's bytes. Operators see disk usage explode and assume the feature is broken; really it's just over-encoding.

2. **Side-by-side storage clutters source folders.** `Movie.mkv` next to `Movie.h264.mkv` is fine for one file; for a library of 200 movies it's 400 files in the browse view, only half of them "real". Users can't easily tell what to delete when freeing space.

3. **No control over where sidecars land.** Operators with tight C: drives need the cache on D: / E: / network share / external. Plan 18 hardcodes "next to source" with no escape hatch.

4. **No UI feedback on storage usage.** No way to see total transcoded size, free space at the cache root, or per-job size. Operators who blow through their disk find out via FFmpeg's "no space left on device" stderr in a notification.

There's also a **5th conceptual pivot** worth surfacing now: most modern devices (Snapdragon 8 Gen 1+, Tensor, A17 Pro, recent Pixels) have hardware AV1 decode. For those clients we don't need a transcode at all — we can just stream-copy AV1 directly via fmp4, the same way we already stream-copy HEVC. Plan 18 forces transcoding because the original assumption was "older devices can't AV1-decode." That's increasingly less true; we should make AV1 stream-copy a first-class opt-in path and reserve transcode for the actually-incompatible cases.

---

## 2 · User flow (target after this ships)

### Library scan completes — modal experience unchanged

The post-scan toast (deferred from plan 18 §M6 — still deferred here) is out of scope. Operators discover candidates the way they do today: sidebar `Transcode` entry, now with a count badge.

### Transcode page — restructured

**Top:** new persistent storage strip:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Transcoded:  5.4 GB / 12 files     Cache:  D:\Fluxora\transcodes  [Open]    │
│ Free on disk:  847 GB              Sources by codec:  AV1 8 · VP9 3 · …     │
└─────────────────────────────────────────────────────────────────────────────┘
[Candidates 17]  [Queue 2]  [History 28]
```

**Candidates tab** — folder-grouped tree replaces the flat list:

```
▼ Movies (4 candidates · ~9.2 GB est. transcode)            [Select all]
   ▼ 2024 (3)                                                [Select folder]
      ☐ Dune Part 2 (2024).mkv          AV1   3.2 GB   ~6.4 GB
      ☐ Inside Out 2 (2024).mkv         AV1   2.8 GB   ~5.6 GB
      ☐ Wicked.mkv                      AV1   2.0 GB   ~4.0 GB
   ▼ 2023 (1)
      ☐ Oppenheimer (2023).mkv          AV1   3.5 GB   ~7.0 GB
▼ TV / Friends (10 candidates · ~6 GB est.)                  [Select folder]
   ☐ S01E01.mkv                          VP9   400 MB  ~600 MB
   ☐ ...

Selected: 0  •  Source: 0 B  •  Estimated output: 0 B
                                                  [Cancel]  [Start transcode]
```

Clicking `[Start transcode]` opens the **Queue dialog** with the new preset chooser:

```
┌──────────────────────────────────────────────────────────────┐
│  Queue 4 files for transcoding                               │
│                                                              │
│  Quality preset                                              │
│  ○ Smaller       ~1.2× source                              │
│                  Noticeable on critical viewing              │
│  ● Recommended   ~2× source       (default)                  │
│                  Indistinguishable in normal viewing         │
│  ○ Mastering     ~4× source                                  │
│                  Visually lossless                           │
│                                                              │
│  Estimated total output: ~22 GB  ·  Free on D:: 847 GB       │
│  Stored at: D:\Fluxora\transcodes  [Change in Settings]      │
│                                                              │
│                                       [Cancel]  [Queue]      │
└──────────────────────────────────────────────────────────────┘
```

**Queue tab** — adds a `Source → Sidecar` size column + per-row "Stored at" path with copy and open-folder icons.

**History tab** — same folder-grouped tree as Candidates, but for terminal-state jobs. Each completed job shows its actual `output_size_bytes`. Per-folder "Delete all transcodes in this folder" affordance with strong confirmation (deletes both `media_files.transcoded_path` rows AND the on-disk sidecars).

### Settings → Transcoding → new "Storage" subsection

```
┌──────────────────────────────────────────────────────────────┐
│  Transcoded files location                                   │
│                                                              │
│  ● Dedicated cache folder (recommended)                      │
│    All sidecars stored under one folder you can delete       │
│    when freeing space.                                       │
│    Cache root: D:\Fluxora\transcodes  [Browse]               │
│                                                              │
│  ○ Inline (next to source, in .fluxora-transcodes subfolder) │
│    Sidecars stay near their source file but in a separate    │
│    subfolder so they don't clutter library views.            │
│                                                              │
│  Total transcoded size: 5.4 GB                               │
│  Free on cache disk:    847 GB                               │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Stream sources directly to capable devices                  │
│                                                              │
│  ☐ AV1 sources — stream directly without transcoding         │
│  ☐ VP9 sources — stream directly without transcoding         │
│                                                              │
│  Skips the H.264 transcode entirely for clients that can     │
│  hardware-decode the source codec. Older devices may not     │
│  play — verify your client lineup before enabling.           │
│                                                              │
│  Per-library overrides: configure on each library page.      │
└──────────────────────────────────────────────────────────────┘
```

---

## 3 · Data model

### Migration 028 (LAUNCH) — `028_streaming_mode.sql`

The launch-scope migration is **one column**:

```sql
-- Global streaming mode toggle.  Default = 'client-decode' so v1 ships
-- with the new low-server-load behaviour out of the box; operators with
-- mixed device pools (older phones, anything <2021) can switch to
-- 'server-transcode' to restore the legacy live-transcode pipeline.
ALTER TABLE user_settings ADD COLUMN
    streaming_mode TEXT NOT NULL DEFAULT 'client-decode'
    CHECK(streaming_mode IN ('client-decode','server-transcode'));
```

### Migration 029+ (DEFERRED — v1.1)

The columns originally bundled into 028 in this plan's first draft now ship as separate migrations when their milestones execute:

```sql
-- 029_transcode_storage_settings.sql  (M2 — deferred)
ALTER TABLE user_settings ADD COLUMN transcode_storage_mode TEXT NOT NULL
    DEFAULT 'dedicated' CHECK(transcode_storage_mode IN ('dedicated','inline'));
ALTER TABLE user_settings ADD COLUMN transcode_cache_root TEXT;

-- 030_per_library_codec_passthrough.sql  (M8 — deferred)
ALTER TABLE libraries ADD COLUMN av1_stream_copy_override INTEGER;
ALTER TABLE libraries ADD COLUMN vp9_stream_copy_override INTEGER;

-- 031_sidecar_source_mtime.sql  (M6 — deferred)
ALTER TABLE media_files ADD COLUMN transcoded_source_mtime INTEGER;
```

`quality_preset` on `transcode_jobs` already exists (plan 18, migration 027). The launch round does NOT change its default value or migrate existing rows — preset chooser is M1, deferred.

---

## 4 · Server changes

### 4.1 · Quality preset map (`services/transcode_service.py`)

```python
QUALITY_PRESETS = {
    "smaller": {
        "nvenc": ["-preset", "p4", "-cq", "28"],
        "libx264": ["-preset", "medium", "-crf", "28"],
        "size_multiplier": 1.2,        # used by /candidates est. + UI
    },
    "recommended": {                    # ← new default
        "nvenc": ["-preset", "slow", "-cq", "23"],
        "libx264": ["-preset", "slow", "-crf", "23"],
        "size_multiplier": 2.0,
    },
    "mastering": {
        "nvenc": ["-preset", "slow", "-cq", "19"],
        "libx264": ["-preset", "slow", "-crf", "19"],
        "size_multiplier": 4.0,
    },
}
```

`POST /api/v1/transcode/queue` body extends to accept `preset: Literal["smaller","recommended","mastering"] = "recommended"`. Worker reads the preset off each job's `quality_preset` column and translates via `QUALITY_PRESETS`.

### 4.2 · Sidecar path resolution (`services/transcode_service.py::_sidecar_path`)

```python
def _sidecar_path(file_row, settings_row, library_row) -> Path:
    """Where the H.264 sidecar for `file_row` lands.

    Driven by `user_settings.transcode_storage_mode`.  Both modes nest
    the sidecar inside a subfolder (loose side-by-side dropped) so the
    operator can always rm the cache without scanning per-file.
    """
    mode = settings_row.get("transcode_storage_mode", "dedicated")
    src = Path(file_row["path"])
    basename = src.stem
    ext = ".mkv" if src.suffix.lower() == ".webm" else src.suffix  # M6 #19

    if mode == "inline":
        cache_dir = src.parent / ".fluxora-transcodes"
    else:  # dedicated
        cache_root = (
            Path(settings_row.get("transcode_cache_root") or _default_cache_root())
        )
        # Mirror the source's directory hierarchy under the cache root
        # so the operator browsing the cache sees the same tree shape.
        try:
            rel = src.parent.relative_to(library_row["root_path"])
        except ValueError:
            # Source is outside the library root (shouldn't happen for
            # scanned files; defensive). Fall back to a flat layout.
            rel = Path(".")
        cache_dir = cache_root / library_row["name"] / rel

    return cache_dir / f"{basename}.h264{ext}"
```

`_default_cache_root()` resolves to `<server-data-dir>/transcodes/`, **never** the system drive's user profile. Configurable at settings save.

### 4.3 · Settings validation (`services/settings_service.py`)

When an operator PATCHes `transcode_cache_root`:

- Path must be absolute.
- Path must be writable (write a 1-byte test file, then unlink).
- Path must NOT be inside any `libraries.root_path` (would loop on rescan).
- Free space at path ≥ 1 GB warns but doesn't block.

422 with a structured error if any check fails. Existing queued jobs are NOT re-validated against the new path — they pick up the new path at run-time per the worker's "consult settings at job-start" semantics.

### 4.4 · New endpoint — `GET /api/v1/transcode/storage`

```json
{
  "cache_root": "D:\\Fluxora\\transcodes",
  "storage_mode": "dedicated",
  "transcoded_size_bytes": 5832019712,
  "transcoded_file_count": 12,
  "free_bytes_at_cache_root": 909521817600,
  "by_codec": { "av1": {"count": 8, "bytes": 4_500_000_000},
                "vp9": {"count": 4, "bytes": 1_300_000_000} }
}
```

Polled by the desktop's `_StorageStrip` widget every 5 s. `validate_token_or_local`. Cheap query (one SUM, one `os.statvfs`).

### 4.5 · AV1 / VP9 stream-copy in `routers/stream.py + ffmpeg_service.py`

The current direct-remux check is:

```python
direct_remux_h264 = source_codec == "h264"
direct_remux_hevc = source_codec in ("hevc", "h265")
direct_remux = direct_remux_h264 or direct_remux_hevc
```

Extend with two new gated checks:

```python
av1_stream_copy_on = _resolve_codec_passthrough_setting(
    settings_row, library_row, codec="av1"
)
vp9_stream_copy_on = _resolve_codec_passthrough_setting(
    settings_row, library_row, codec="vp9"
)
direct_remux_av1 = av1_stream_copy_on and source_codec == "av1"
direct_remux_vp9 = vp9_stream_copy_on and source_codec == "vp9"
direct_remux = (
    direct_remux_h264 or direct_remux_hevc
    or direct_remux_av1 or direct_remux_vp9
)
```

`_resolve_codec_passthrough_setting` reads `libraries.<codec>_stream_copy_override` first (per-library override), then falls back to `user_settings.<codec>_stream_copy_enabled` (global). NULL override → inherit; explicit 0 or 1 → use.

When direct-remux fires for AV1 / VP9: use the existing fmp4 segment path (already in place for HEVC). FFmpeg flags:

```
-c:v copy -c:a aac -b:a 128k -hls_segment_type fmp4 -hls_fmp4_init_filename init.mp4
```

No tonemap / cuvid / NVENC. Same straight-mux pipeline that HEVC uses today.

### 4.6 · Stale-sidecar detection (M6 #18)

On every library scan that re-discovers a row with `transcoded_path != NULL`:

```python
if row["transcoded_source_mtime"] is not None:
    src_mtime = int(Path(row["path"]).stat().st_mtime)
    if src_mtime > row["transcoded_source_mtime"]:
        # Source has been overwritten since last transcode. Don't
        # auto-re-transcode (might be intentional remux). Mark stale
        # so the History tab can surface a ⚠ badge.
        await db.execute(
            "UPDATE media_files SET transcoded_path = NULL "
            " WHERE id = ?",
            (row["id"],),
        )
```

Sidecar file on disk stays — operator's call whether to delete via the History tab's per-folder cleanup affordance.

---

## 5 · Desktop control panel changes

### 5.1 · `_StorageStrip` widget — new

Mounted at the top of `transcode_screen.dart`, above the TabBar. Reads from `TranscodeCubit`'s new `storage` slice (populated by the 5 s polling timer that already polls `/jobs`). Renders the four facts (transcoded size, cache root with `[Open]` button → launches `Process.start("explorer", [path])` on Windows / `open` on macOS / `xdg-open` on Linux, free disk, by-codec breakdown).

### 5.2 · Folder-grouped tree (Candidates + History)

Replace `ListView.builder` with a recursive `_FolderNode` widget. Computed once per `state.candidates` change in the cubit:

```dart
class _FolderNode {
  final String path;
  final String name;
  final List<_FolderNode> children;
  final List<TranscodeCandidate> candidates;
  int get totalCount => candidates.length + children.fold(0, (a, n) => a + n.totalCount);
  int get totalSize => /* sum bytes */;
}
```

State: `Set<String> _expandedPaths` persisted in cubit so expand/collapse survives rebuilds. Folder checkbox = "select all leaves under this node"; tri-state when partial.

### 5.3 · Queue dialog — new

`_QueueDialog` widget (FluxGlassDialog wrapping). Three radio rows for preset, live "Estimated total" recompute, "Stored at" path readout with `[Change in Settings]` button. Stored selection passed to `TranscodeRepository.queue(file_ids, preset)`.

### 5.4 · Per-row affordances

Queue tab row gets a new column rendering `_formatSize(srcBytes) → _formatSize(estBytes)` (e.g. `62 MB → ~124 MB`). History tab uses the actual `output_size_bytes` after job completion.

`Stored at` icon in row trailing slot opens a `FluxGlassMenu` with two items: `Copy path` (clipboard write) and `Open folder` (process launch). For Queue tab rows the `output_path` is null until done; the icon is dimmed.

### 5.5 · Transcode discoverability

`flux_sidebar.dart`'s existing `Transcode` entry: extend the row to render a violet count badge when `state.candidates.length > 0`. Reads from a lightweight `TranscodeCountCubit` (factory) that polls `GET /transcode/candidates` every 30 s while the shell is mounted. Badge hides at zero.

Library detail panel (`library_screen.dart`'s right side panel when a library is selected): new chip `[ 4 candidates → ]` linking to `/transcode?library=<id>`. The transcode screen accepts the `library` query param and pre-filters the Candidates tab.

### 5.6 · Settings → Transcoding → Storage subsection

New `_TranscodeStorageSection` widget at the bottom of the existing transcoding settings page. Two radio rows for storage mode, `[Browse]` button opening a Flutter folder-picker dialog (existing `file_selector` plugin already in pubspec for the upload flow), aggregate size + free space readouts (re-uses the `/transcode/storage` endpoint).

Two checkbox rows for AV1 / VP9 stream-copy with a clear "Older devices may not play" advisory under each. Per-library overrides documented in the description but configured on the library page (separate widget; same boolean shape).

### 5.7 · Library page — codec passthrough overrides

Each library's edit form gains:

```
Stream original codec to clients
  ☐ AV1 ─── [○ Use global setting | ○ Always | ○ Never]
  ☐ VP9 ─── [○ Use global setting | ○ Always | ○ Never]
```

3-state segmented control per codec → maps to NULL / 1 / 0 in `libraries.<codec>_stream_copy_override`.

---

## 6 · Mobile changes

**Zero.** Same as plan 18.

The AV1 stream-copy path lands as fmp4 segments served from `/api/v1/hls/...`; media_kit / libmpv plays AV1-in-fmp4 transparently if the device's libmpv build supports AV1 decode. Modern Android builds do; iOS via media_kit's Apple-Silicon backend does on A17 Pro+. If a device falls back to software AV1 decode and stutters, that's the same failure mode as today's "force transcode" path on the server — just shifted to the device. Operator-facing knob is the per-library override.

---

## 7 · Sequenced milestones

```
M7 — AV1 / VP9 stream-copy path + global "Streaming  │ ~3 h    │ medium risk │ ✅ shipped 2026-05-09 (commit 627cdf1)
       mode" toggle in encoder settings              │         │             │
─────────────────────────────────────────────────────│─────────│─────────────│
M1 — Quality preset chooser (default → cq=23)        │ ~1 h    │ low risk    │ ✅ shipped 2026-05-09
M2 — Storage mode + cache root setting               │ ~2 h    │ medium risk │ ✅ shipped 2026-05-09
M3 — `/transcode/storage` + _StorageStrip widget     │ ~1.5 h  │ low risk    │ ✅ shipped 2026-05-09
M4 — Folder-grouped tree (Candidates + History)      │ ~2 h    │ medium risk │ ✅ shipped 2026-05-09
M5 — Queue dialog + per-row size + path affordances  │ ~1.5 h  │ low risk    │ ✅ shipped 2026-05-09
M6 — Edge-case hardening (validation, mtime stale,   │         │             │
       .webm ext override, partial cleanup on boot)  │ ~1.5 h  │ medium risk │ ✅ shipped 2026-05-09
M8 — Per-library override UI + library-delete with   │         │             │
       sidecar-cleanup confirmation                  │ ~1.5 h  │ low risk    │ ✅ shipped 2026-05-09
─────────────────────────────────────────────────────│─────────│─────────────│
Total                                                │ ~13 h                   │ all 8 milestones closed
```

**Execution.** M7 shipped same-day as the strategy-pivot commit `627cdf1`. M1-M6 + M8 shipped same-day via 2 parallel Opus subagents partitioned along the server / desktop boundary, with the API contract locked in both prompts so they couldn't diverge. Migrations 029, 030, 031 added per §3. Net: server **734 → 775 (+41 tests)**, desktop **104 → 113 (+9 tests)**, ruff + flutter analyze clean across the round.

**Sharp edges flagged for follow-up rounds:**
- The desktop's library-delete confirmation shows a checkbox "Also delete N transcoded sidecars" but **no per-library count** — the storage endpoint surfaces aggregate cache size only. Adding per-library breakdown to the storage endpoint is a small server-side enhancement.
- Folder-tree memoisation isn't there yet — `buildFolderTree` runs on every Candidates rebuild. Free for ≤17 candidates; at 5000+ it'd want caching keyed by the candidates-list identity hash.
- `ApiClient.delete` had no query-param hook before this round; the subagent appended `?delete_sidecars=…` to the path string. Worth landing a proper `delete<T>(path, {queryParameters})` overload eventually.

---

## 8 · Tests

### 8.1 · Server

- `test_transcode_service.py`: extend with `test_quality_preset_maps_to_cq_args` (smaller/recommended/mastering produce the right NVENC + libx264 args), `test_sidecar_path_dedicated_mirrors_library_tree`, `test_sidecar_path_inline_uses_subfolder`, `test_sidecar_path_webm_forces_mkv`, `test_settings_validation_rejects_cache_root_inside_library`, `test_stale_sidecar_detection_clears_transcoded_path_on_source_mtime_advance`.
- `test_stream.py`: new `test_av1_stream_copies_when_enabled_global`, `test_av1_stream_copies_when_library_override_overrides_off_global`, `test_av1_falls_back_to_transcode_when_disabled`, `test_vp9_*` mirrors. Plus an end-to-end `test_av1_passthrough_outputs_fmp4_segments` verifying the FFmpeg cmd uses `-hls_segment_type fmp4 -c:v copy`.
- `test_transcode_router.py`: `POST /queue` accepts `preset` field; `GET /transcode/storage` schema + auth.

### 8.2 · Desktop

- `transcode_cubit_test.dart`: existing 14 tests + ~6 new for the storage strip, folder-tree expansion, preset selection passing through to `repository.queue`, `library` filter pre-application.
- `_FolderNode` is a pure data structure — small unit tests for `totalCount` / `totalSize` recursion + tri-state checkbox logic.

### 8.3 · Manual

- 4K AV1 source through the smaller preset — verify size is in the 1.0-1.3× range, not 4×.
- Queue 5 jobs, change `transcode_storage_mode` mid-queue, verify queued jobs respect the new mode and the running job finishes at its original location.
- Disconnect the cache drive (USB) mid-job — verify graceful fail with clear error in History.
- Modern phone: enable AV1 stream-copy, play AV1 source, verify server log shows `mode=stream-copy(av1/fmp4) source_codec=av1` and CPU/GPU stay near zero.

---

## 9 · Design decisions

### 9.1 · Resolved (M7 launch)

**Default streaming mode = `client-decode`.** Matches the launch intent: server CPU near zero on day 1, modern devices "just work", legacy operators flip to `server-transcode` after seeing one device fail. The settings UI carries an explicit "Older devices may not play AV1 / VP9 directly" warning under the recommended option so the failure mode is set as expectation rather than discovered.

**Single global toggle, not per-codec.** AV1 and VP9 both flip together. Per-codec granularity (separate `av1_stream_copy_enabled` / `vp9_stream_copy_enabled`) was the original draft; collapsing to one `streaming_mode` enum is simpler UI and mirrors the operator's mental model ("do I want my server to do work or not?"). When per-library overrides ship in M8 (deferred), they'll re-introduce per-codec granularity at the per-library scope.

**Sidecar pickup wins regardless of mode.** If `media_files.transcoded_path` is set + the file exists on disk, the existing H.264 sidecar streams (stream-copy from H.264). Mode only governs what happens when there's no sidecar. Operators who already ran plan-18 jobs don't lose that work when v1 ships with `client-decode` default.

### 9.2 · Carried forward (deferred milestones)

The original 8 design questions for the full follow-up scope are in [`19_library_transcode_followups.md` git history at the drafted version](#) — they don't need answering for the M7 launch round. When M1-M6 + M8 actually execute, that's when we revisit. Briefly:

- M1: `smaller` preset uses `nvenc p4 cq=28`; default flips to `recommended` (`slow cq=23`).
- M2: storage modes are `dedicated` (default) and `inline`; both nest in subfolders.
- M3: storage strip polls `/transcode/storage` every 5 s while the screen is mounted.
- M4: folder tree state persisted in cubit; tri-state checkboxes for partial selection.
- M8: 3-state per-library overrides (NULL / 0 / 1), library-delete confirmation defaults to "also delete sidecars."

---

## 10 · Files Created / Modified

### 10.1 · Launch round (M7) — actually shipping

| Action | Path | Why |
|--------|------|-----|
| 🆕 | `apps/server/database/migrations/028_streaming_mode.sql` | One column on `user_settings`: `streaming_mode TEXT NOT NULL DEFAULT 'client-decode' CHECK(...)` |
| ✏️ | `apps/server/services/ffmpeg_service.py` | Extend direct-remux check: `direct_remux_av1` + `direct_remux_vp9` gated on `streaming_mode == 'client-decode'`; `use_fmp4` derivation also fires for AV1/VP9 stream-copy |
| ✏️ | `apps/server/models/settings.py` | `UpdateSettingsBody` adds `streaming_mode: Literal['client-decode','server-transcode'] \| None = None` |
| ✏️ | `apps/server/routers/settings.py` | Dynamic SET-list for `streaming_mode` PATCH |
| ✏️ | `apps/server/services/settings_service.py` | `get_settings` returns `streaming_mode` field (defensive default for pre-028 rows) |
| ✏️ | `apps/server/tests/test_stream.py` | `test_av1_stream_copies_when_streaming_mode_is_client_decode` + `test_av1_falls_to_transcode_when_server_transcode` + VP9 mirrors |
| ✏️ | `apps/server/tests/test_settings_extended.py` | `streaming_mode` round-trip + invalid-value 422 |
| ✏️ | `apps/desktop/lib/features/transcoding/presentation/screens/encoder_settings_screen.dart` | New `_StreamingModeSection` widget at top: 2 radio rows + warning advisory |
| ✏️ | `apps/desktop/lib/features/settings/presentation/cubit/settings_cubit.dart` | `streamingMode` field; PATCH wiring |
| ✏️ | `apps/desktop/lib/features/settings/presentation/cubit/settings_state.dart` | New field on `SettingsLoaded` |
| ✏️ | `apps/desktop/lib/features/settings/data/repositories/settings_repository_impl.dart` | Maps `streaming_mode` JSON ↔ Dart field |
| ✏️ | All launch-affected docs: `current_status.md`, `folder_structure.md`, `tech_stack.md`, `04_api/01_api_contracts.md` (settings PATCH field), `03_data/02_database_schema.md` (migration 028 row), `03_data/04_migration_guide.md` (file-layout extended), `09_backend/01_backend_architecture.md` (test count), `08_frontend/01_frontend_architecture.md` (encoder settings widget), `01_roadmap.md` (new "Client-side codec passthrough" row), `05_ship_readiness.md` (test count + feature line) | Standard doc-update protocol |
| ✏️ | `AGENT_LOG.md` | Entry for the M7 launch round |
| ✏️ | `docs/10_planning/19_library_transcode_followups.md` | This plan's status banner + milestone table reflect the launch-priority pivot |

### 10.2 · Deferred (M1-M6 + M8) — NOT shipping in this round

The list from this plan's first draft stays valid for v1.1+ execution. Migrations 029, 030, 031 split out by milestone (see §3). Concrete file paths land when the milestones execute.

---

## 11 · Cross-references

- Predecessor plan: [`18_library_transcode_plan.md`](./18_library_transcode_plan.md) — landed M1-M5 + M8 on 2026-05-09; sidecar-metadata-override hotfix tracked separately.
- Streaming pipeline this builds on: [`16_streaming_resume_and_throttle_plan.md`](./16_streaming_resume_and_throttle_plan.md), [`17_ffmpeg_diagnostics_and_m2_retry_plan.md`](./17_ffmpeg_diagnostics_and_m2_retry_plan.md).
- Encoder selection / fmp4 path: `apps/server/services/ffmpeg_service.py::start_stream` (the existing HEVC fmp4 branch is what AV1 / VP9 will reuse).
- Settings UI surface: `apps/desktop/lib/features/settings/presentation/screens/settings_screen.dart` Transcoding tab.
- Library UI surface: `apps/desktop/lib/features/library/presentation/screens/library_screen.dart` detail panel.

---

## 12 · TL;DR

Plan 18 shipped a working transcode pipeline but the operator's real-device test surfaced **wrong defaults** (4× sized sidecars, side-by-side clutter, no storage controls). Mid-review the strategy reframed: **v1 launches with client-side decoding as the default**, transcoding becomes the legacy / opt-in fallback. **M7 shipped same-day as `627cdf1` with `client-decode` default; M1-M6 + M8 shipped same-day via 2 parallel Opus subagents — full plan 19 closed in a single working day.** Server stream-copies AV1/VP9 sources via fmp4 by default; quality presets (smaller / recommended / mastering) replace the over-aggressive `cq=19` default; cache lives at an operator-configurable root with a mirrored library tree (or `.fluxora-transcodes/` inline subfolder); `/transcode/storage` + storage strip surface usage at the top of the Transcode page; folder-grouped tree replaces the flat candidate list with tri-state checkboxes; per-library AV1/VP9 overrides + library-delete-with-sidecar-cleanup checkbox close the polish surface. Server **734 → 775 tests**; desktop **104 → 113 tests**. The transcode pipeline code from plan 18 stays intact — toggle only changes which path new playback sessions hit by default.

---

## 13 · v1.2+ candidates (NOT in this plan)

- **Multi-job concurrency slider** (1–N, default 1) with a "may slow streaming" warning.
- **Resolution downscale option** (4K → 1080p sidecar to reclaim disk).
- **Per-device codec capability negotiation** (mobile reports decoders at pair time; server picks per-stream codec).
- **Auto-retry on transient failures** with exponential backoff.
- **"Detect orphan sidecars on disk" cleanup tool** — scan cache root, flag entries with no matching `media_files.transcoded_path`.
- **Re-link by content hash** when a source file moves.
- **WS push for the sidebar candidate-count badge** (replaces 30 s polling).
- **Per-library storage breakdown** in the storage strip.
- **Auto-transcode policies** per library ("transcode every AV1 in this library at scan time").
- **HEVC sidecar option** (smaller than H.264 at same quality; needs HEVC patent / royalty consideration).

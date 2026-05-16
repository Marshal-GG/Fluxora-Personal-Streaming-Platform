# Thumbnail Generation — Plan 27

> **Category:** Planning
> **Status:** 📝 Draft (revised 2026-05-16, scope expanded) — owner review pending
> **Scope:** Generate real per-file thumbnails (video frame, image preview, embedded album art, **PDF first page**) **asynchronously in the background** so library cards without TMDB enrichment have a proper visual instead of a gradient placeholder.  Scan path stays instant — work is queued + processed by an in-process worker with a concurrency cap.  Includes **HDR tone-mapping**, **per-library priority queue**, **operator-triggered regeneration**, **size configurability**, **CDN-friendly URL versioning**, and **operator notifications on failure**.
> **Triggered by:** owner review 2026-05-16 — current TMDB-missing fallback (gradient mosaic landed earlier same day) is a stopgap; operator expectation is that any populated library shows real per-file thumbs the way Plex / Jellyfin do.  Original draft had a deferred "v1.1 follow-up" list; owner re-scoped 2026-05-16 to pull them into v1.

---

## 1 · Executive Summary

Today, library cards source `cover_urls` exclusively from `media_files.poster_url` (TMDB-enriched).  When TMDB enrichment fails or doesn't apply (Music / Documents / un-enriched movies), the card falls back to a gradient-mosaic placeholder.  The operator wants **real thumbs** from the actual file contents.

**Decision:** add a server-side **thumbnail-extraction subsystem** that generates per-file JPEG previews asynchronously in the background and exposes them via a new endpoint.  Four extractor paths:

| Source | Engine | Argv / call shape | Notes |
|---|---|---|---|
| Video frame | FFmpeg | `ffmpeg -ss <T> -i <path> -vframes 1 -vf "<vf chain>" -q:v 5` | `<T>` = `min(10, duration/3)` to skip title cards.  `<vf chain>` includes HDR→SDR tonemap when `hdr_format IS NOT NULL`. |
| Image | FFmpeg | `ffmpeg -i <path> -vf scale=<W>:-2 -q:v 5` | Works for JPEG/PNG/WEBP/HEIC/BMP/TIFF |
| Audio cover art | FFmpeg | `ffmpeg -i <path> -an -vcodec copy` (extracts embedded APIC frame) | Skipped when no embedded art present |
| PDF first page | **PyMuPDF** (`pip install pymupdf`) | `fitz.open(path)[0].get_pixmap(matrix=fitz.Matrix(W/72,W/72)).save(out)` | Pure-Python wheel; AGPL license (compatible with current distribution — no LGPL/proprietary linking concerns) |

**Headline:**
- Scan latency **unchanged** — generation runs on a background asyncio worker pool with a small concurrency cap (default **2**).
- New `media_thumbnails` table tracks per-file generation state (pending / generating / ready / failed / skipped) + `priority INTEGER NOT NULL DEFAULT 0` for per-library boost.
- New endpoint `GET /api/v1/files/{file_id}/thumbnail` serves the cached JPEG with **CDN-friendly `?v=<generated_at_unix>` cache-buster URLs**; 404 when not yet ready (client falls back to the existing gradient mosaic).  **No on-demand generation in the endpoint** (per owner direction — BG worker only).
- `_library_aggregates` (the function that builds `cover_urls`) now fills the 4 slots with TMDB posters first, then generated thumbnails (with `?v=` suffix) — so a half-enriched library shows real TMDB posters mixed with extracted frames.
- **Per-library priority queue**: when the operator opens a library (`GET /files?library_id=X`), pending thumbnails for that library get `priority=10`; worker orders `ORDER BY priority DESC, created_at ASC` so the just-opened library jumps to the front of the queue.
- **Operator regeneration UI**: new "Regenerate thumbnails" affordance in the library detail panel + new `POST /library/{id}/regenerate-thumbnails` endpoint resets pending rows.
- **Configurable thumbnail width** via `user_settings.thumbnail_width` (default 320 px, range 160–640) — settings UI exposes it under Settings → Advanced.
- **Failure notification**: when ≥ N files (default 5) in a library fail generation after exhausting retries, write one aggregated notification (`category='thumbnail'`) instead of N per-file noise.
- Settings toggle `generate_thumbnails: bool` already exists; this plan finally wires it.

**What's NOT changing:**
- Scan-time DB writes — `media_files` row insert is untouched.  Thumbnail row is inserted **after** the file row, in a non-blocking helper that just adds a `(file_id, status='pending')` entry.
- TMDB enrichment path — orthogonal subsystem; both run independently.
- Client `_PosterMosaic` / `_GradientMosaicFallback` widgets — they consume `cover_urls` and the existing fallback chain handles every state.
- Mobile client — `Library.coverUrls: List<String>` already deserialises the new mixed-source URL list; no mobile code change needed.

**Sequencing:** **six milestones, ~8–10 h end-to-end** (was 3 h in the original 4-milestone draft).  M1 schema + extractors; M2 worker + scan-path enqueue + priority + failure notifications; M3 endpoint + cover_urls integration + URL versioning; M4 settings field (thumbnail_width); M5 desktop regeneration UI; M6 sweeper + docs.

---

## 2 · Why This Plan, Why Now

| Pain point | Symptom | Fix |
|---|---|---|
| Library cards without TMDB look like placeholders, not libraries | Operator sees gradient mosaic on Music + Documents + un-enriched Movies; the card doesn't feel "populated" | Generate per-file thumbnails from the actual file contents |
| `generate_thumbnails: bool = True` setting is a lie | Flag exists in `user_settings` since migration 015 but no code reads it | Plan 27 finally honours the flag |
| Plex / Jellyfin parity | Operator's reference frame is competing self-hosted streamers; both generate thumbs at scan time | Match the UX without copying the synchronous scan-time pattern |
| Scan latency is already a known sore point | Each video file = 2 ffprobe subprocesses (video + audio probe); adding a 3rd FFmpeg subprocess per file would double scan time on real-world libraries | Decouple generation from scan via async worker |

Owner explicitly said: "scans must be really fast we can generate thumb lazy, in bg".  That's the rationale for the async-worker shape over the obvious inline-at-scan approach.

---

## 3 · Architecture

```
┌────────────────────────────┐
│   library_service.scan     │   adds (file_id, 'pending') to
│                            │──▶ media_thumbnails (best-effort,
└────────────────────────────┘    swallows errors)
              │
              │  Scan returns immediately — no FFmpeg
              ▼
┌────────────────────────────┐
│   media_thumbnails table   │   FIFO queue of pending rows
└────────────────────────────┘
              ▲
              │  poll every N seconds
┌─────────────┴──────────────┐
│  ThumbnailWorker (asyncio) │   N concurrent slots
│  - claims pending row      │   (default 2)
│  - dispatches by file.kind │
│  - writes JPEG to disk     │
│  - updates row status      │
└────────────────────────────┘
              │
              │  writes to
              ▼
┌────────────────────────────┐
│ <data_dir>/thumbnails/     │
│   <file_id>.jpg            │
└────────────────────────────┘
              ▲
              │  reads + streams
┌─────────────┴──────────────┐
│ GET /files/{id}/thumbnail  │
└────────────────────────────┘
              ▲
              │  Image.network(url)
┌─────────────┴──────────────┐
│  Desktop _PosterMosaic     │
└────────────────────────────┘
```

**Key principle:** the **scan path** doesn't touch FFmpeg.  Adding a pending row is one INSERT — negligible cost.  All real work happens in the background worker, which is decoupled by the queue.

---

## 4 · Data Model

### 4.1 New table — `media_thumbnails`

```sql
CREATE TABLE media_thumbnails (
    file_id        TEXT PRIMARY KEY REFERENCES media_files(id) ON DELETE CASCADE,
    status         TEXT NOT NULL CHECK (status IN ('pending', 'generating', 'ready', 'failed', 'skipped')),
    priority       INTEGER NOT NULL DEFAULT 0,
    generated_at   TIMESTAMP NULL,
    attempts       INTEGER NOT NULL DEFAULT 0,
    error_message  TEXT NULL,
    created_at     TIMESTAMP NOT NULL,
    updated_at     TIMESTAMP NOT NULL
);

CREATE INDEX idx_thumbs_pending
    ON media_thumbnails(priority DESC, created_at ASC)
    WHERE status = 'pending';
```

- **`priority`** column: 0 = default FIFO; 10 = boosted (operator just opened this file's library — `/files?library_id=X` endpoint stamps `priority=10` on pending rows in that library so they jump to the front of the worker queue).  No decay; once boosted, the row stays at 10 until the worker processes it.  Stable across server restarts (column is durable).

- **Why a separate table, not columns on `media_files`?** Three reasons:
  1. Avoids `media_files` schema churn — that table is hot, already 18+ columns, and frequently queried.
  2. Lets the worker `UPDATE media_thumbnails` without touching `media_files.updated_at` (which would mess with TMDB enrichment ordering).
  3. ON DELETE CASCADE means file removal automatically cleans the thumbnail row (still need to delete the JPEG file separately — see §8 edge case 5).

- **Status state machine:**
  ```
  pending ──▶ generating ──▶ ready
                │
                ├──▶ failed   (transient — can be retried by backfill)
                └──▶ skipped  (permanent — no thumb possible, e.g. audio w/o embedded art)
  ```

- **`attempts` counter** — exponential backoff hook for future retry policy (capped at 3 in v1; after that, mark `failed` and stop retrying until manual operator action).

- **Partial index on `status='pending'` ordered by `created_at`** — the worker's hot query is `SELECT file_id FROM media_thumbnails WHERE status='pending' ORDER BY created_at LIMIT 1`.  Partial index keeps it O(log K) where K = pending count, not O(log N) where N = total files.

### 4.2 No changes to `media_files`

The file row stays clean.  The aggregation layer joins `media_files LEFT JOIN media_thumbnails` when building `cover_urls`.

---

## 5 · Migrations

### 5.1 `037_media_thumbnails.sql`

Sequenced after 036 (`stream_sessions_fk_set_null` — already shipped).

```sql
-- Plan 27: per-file thumbnail extraction tracking.
-- Status-tracked queue consumed by services/thumbnail_worker.py.

CREATE TABLE media_thumbnails (
    file_id        TEXT PRIMARY KEY REFERENCES media_files(id) ON DELETE CASCADE,
    status         TEXT NOT NULL CHECK (status IN ('pending', 'generating', 'ready', 'failed', 'skipped')),
    priority       INTEGER NOT NULL DEFAULT 0,
    generated_at   TIMESTAMP NULL,
    attempts       INTEGER NOT NULL DEFAULT 0,
    error_message  TEXT NULL,
    created_at     TIMESTAMP NOT NULL,
    updated_at     TIMESTAMP NOT NULL
);

CREATE INDEX idx_thumbs_pending
    ON media_thumbnails(priority DESC, created_at ASC)
    WHERE status = 'pending';

-- Backfill: every existing media_files row gets a pending thumb so the
-- worker can chew through them after deployment.  No-op for empty installs.
INSERT INTO media_thumbnails (file_id, status, priority, created_at, updated_at)
SELECT id, 'pending', 0, datetime('now'), datetime('now')
  FROM media_files
 WHERE id NOT IN (SELECT file_id FROM media_thumbnails);
```

### 5.2 `038_user_settings_thumbnail_width.sql`

```sql
-- Plan 27 M4: operator-configurable thumbnail width.
-- Range 160-640; default 320 matches the original hardcoded value.
-- Settings router enforces the range; this column has no CHECK to avoid
-- breakage if the range is widened in a future plan.
ALTER TABLE user_settings ADD COLUMN thumbnail_width INTEGER NOT NULL DEFAULT 320;
```

---

## 6 · Server Components

### 6.1 `services/thumbnail_service.py` (new, ~250 LOC)

Pure extraction functions — no DB access, no state.  Owns the FFmpeg argv shapes + the PyMuPDF call.

```python
async def extract_thumbnail(
    file_path: Path,
    output_path: Path,
    *,
    kind: str,                   # 'video' | 'image' | 'audio' | 'pdf'
    width: int = 320,            # operator-configurable; passed in by the worker
    duration_sec: float | None = None,
    hdr_format: str | None = None,  # 'HDR10' / 'HLG' / 'DV' / None — drives tonemap chain
) -> ThumbnailResult:
    """Return a ThumbnailResult(success: bool, skipped: bool, error: str | None).

    `skipped` distinguishes "no thumbnail possible" (e.g. audio without
    embedded art) from "tried and failed" (e.g. FFmpeg crashed).  The
    worker writes 'skipped' rather than 'failed' to short-circuit retry.
    """
```

Internal helpers:

| Helper | Engine | Argv / call shape |
|---|---|---|
| `_extract_video(path, out, dur, width, hdr)` | FFmpeg | `ffmpeg -y -ss <T> -i <path> -vframes 1 -vf "<vf>" -q:v 5 <out>` where `T = min(10, dur/3)` and `<vf>` = SDR chain `scale=<W>:-2:flags=lanczos,format=yuv420p` OR HDR chain `zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p,scale=<W>:-2:flags=lanczos` when `hdr_format` is set |
| `_extract_image(path, out, width)` | FFmpeg | `ffmpeg -y -i <path> -vf "scale=<W>:-2:flags=lanczos" -q:v 5 <out>` |
| `_extract_audio(path, out, width)` | FFmpeg | `ffmpeg -y -i <path> -an -vcodec copy <out>` (no resize — embedded art is already small).  Fails fast on missing APIC stream → translated to `skipped`. |
| `_extract_pdf(path, out, width)` | **PyMuPDF** | `doc = fitz.open(path); page = doc[0]; zoom = width / page.rect.width; pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom)); pix.save(out)` — wrapped in `asyncio.to_thread()` since PyMuPDF is synchronous |

**HDR tonemap chain** (reused from plan 17's stream-side tonemap):
- Input: PQ / HLG video at BT.2020 colour space
- `zscale=t=linear:npl=100` → linearise PQ/HLG
- `format=gbrpf32le` → 32-bit float for tonemap math
- `zscale=p=bt709` → primaries conversion to Rec.709
- `tonemap=tonemap=hable:desat=0` → Hable tonemap operator (matches stream-side)
- `zscale=t=bt709:m=bt709:r=tv` → SDR transfer + matrix
- `format=yuv420p` → final pixel format for JPEG
- `scale=<W>:-2:flags=lanczos` → resize to target width

**Subprocess timeout:** 30 s per FFmpeg call (longer than `_persist_probe`'s effective ffprobe timeout but bounded — won't hang a worker slot indefinitely).  PyMuPDF has no native timeout — wrapped in `asyncio.wait_for(asyncio.to_thread(...), timeout=15)`.  15 s is generous for any non-pathological PDF first page.

**Kind dispatch:** read from `media_files.extension` mapped through a static table:
- `.mp4 .mkv .mov .avi .webm .wmv .flv .m4v .ts` → `'video'`
- `.jpg .jpeg .png .webp .heic .heif .gif .bmp .tiff` → `'image'`
- `.mp3 .m4a .flac .ogg .opus .wav .aac` → `'audio'`
- `.pdf` → `'pdf'`
- Everything else → `'skipped'` (other docs — Word / Excel / text)

### 6.1.1 New dependency — `PyMuPDF`

Added to `apps/server/pyproject.toml` as `pymupdf ^1.24.0` (or latest at implementation time — check pypi first per CLAUDE.md prohibition #12).

**Justification:** PDF thumbnail generation requires rendering the first page to a pixmap; FFmpeg cannot decode PDFs.  Alternatives evaluated:
- **`pdf2image` + `poppler` system binary** — rejected: would require bundling poppler in the Windows installer + per-OS detection on Mac/Linux runtime.
- **`pdfplumber` / `pypdf`** — text-only, can't render to image.
- **`Wand` (ImageMagick wrapper)** — rejected: ImageMagick is another system binary dep.

**License:** PyMuPDF is dual-licensed (AGPL-3.0 / commercial).  AGPL is compatible with Fluxora's self-hosted distribution model (operators self-host; AGPL's source-distribution requirement is met by Fluxora being open-source).  Confirmed before merge.

**Footprint:** ~30 MB installed wheel (includes mupdf bindings).  Acceptable.

### 6.2 `services/thumbnail_worker.py` (new, ~300 LOC)

In-process async worker that owns the queue lifecycle, priority handling, and failure-notification aggregation.

```python
class ThumbnailWorker:
    def __init__(
        self,
        db_path: Path,
        thumbnails_dir: Path,
        *,
        concurrency: int = 2,
        poll_interval_sec: float = 2.0,
        max_attempts: int = 3,
        failure_notification_threshold: int = 5,
    ):
        ...

    async def start(self) -> None:
        """Spawn N worker coroutines + a ticker that monitors generate_thumbnails setting + a sweeper coroutine for orphan JPEGs."""

    async def stop(self) -> None:
        """Cancel coroutines, wait for in-flight to finish or 5 s, whichever first."""

    async def enqueue(self, db, file_id: str, *, priority: int = 0) -> None:
        """INSERT OR IGNORE one pending row.  Called from library_service.scan_library."""

    async def boost_library(self, db, library_id: str) -> int:
        """Stamp priority=10 on all pending rows for files in library_id.  Returns rows updated.
        Called from routers/files.py when the operator opens a library."""

    async def regenerate_library(self, db, library_id: str) -> int:
        """Reset every thumbnail row for files in library_id to pending + attempts=0.
        Deletes the cached JPEG file from disk so the worker re-generates.
        Called from POST /library/{id}/regenerate-thumbnails."""

    async def _worker_loop(self, slot_id: int) -> None:
        # while not cancelled:
        #   1. Check setting; if disabled, sleep poll_interval and continue.
        #   2. Atomic claim: UPDATE media_thumbnails
        #        SET status='generating', updated_at=...
        #        WHERE file_id = (
        #          SELECT file_id FROM media_thumbnails
        #           WHERE status='pending' AND attempts < max_attempts
        #           ORDER BY priority DESC, created_at ASC
        #           LIMIT 1
        #        ) RETURNING file_id, ...
        #   3. If no row claimed, sleep poll_interval, continue.
        #   4. JOIN media_files for path/extension/duration_sec/hdr_format; dispatch to extractor.
        #   5. Update row to 'ready' (with generated_at) / 'failed' (with attempts++ + error_message) / 'skipped'.
        #   6. If status=='failed' and attempts >= max_attempts: maybe emit aggregated notification (see _maybe_emit_failure_notification).
        #   7. Loop.

    async def _maybe_emit_failure_notification(self, db, library_id: str) -> None:
        # Count permanent failures for this library (attempts >= max_attempts) since last notification.
        # If count >= failure_notification_threshold AND no open notification exists for this library:
        #   notification_service.create(
        #     type='warning', category='thumbnail',
        #     title=f'Thumbnail generation failed for {count} files',
        #     message=f"Some files in library '{lib_name}' couldn't be thumbnailed. Check the server logs and verify FFmpeg is healthy.",
        #     related_kind='library', related_id=library_id,
        #   )
        # Dedup: skip if same (category, related_id, dismissed_at IS NULL) row exists.
```

**Atomic claim** — SQLite supports `UPDATE ... RETURNING` since 3.35.  Wraps the SELECT-then-UPDATE pattern in a single statement so two workers can't grab the same row.  Order is `priority DESC, created_at ASC` so boosted rows are picked first (operator-just-opened library jumps the queue), then FIFO within each priority band.

**Failure notification aggregation:** rather than one notification per failed file (which would spam the bell), the worker batches.  After a file's `attempts` hits the cap, the worker checks the per-library failure count since the last `thumbnail` notification for that library.  If the count crosses the threshold (default 5), one summary notification is written; otherwise silent.  De-dup: same `(category='thumbnail', related_id=library_id, dismissed_at IS NULL)` check that other producers use.  When the operator dismisses, future failures start a fresh count.

**Lifecycle:** started by `main.py`'s `lifespan` after `init_db()` finishes; `stop()` called on shutdown.

### 6.3 `library_service.scan_library` — enqueue hook

Single line addition inside the existing scan loop, right after the INSERT into `media_files`:

```python
await thumbnail_worker.enqueue(db, file_id)
```

`enqueue` is `INSERT OR IGNORE` — re-scanning an already-thumbed file is a no-op.  No FFmpeg, no path resolution, no IO beyond a single DB write.  **Scan path stays O(1) per file** for thumbnail work.

### 6.3.1 `routers/files.py` `GET /files?library_id=X` — priority boost hook

When the operator opens a library on the desktop, the client hits `GET /files?library_id=<id>` to load the files screen.  This is the natural "operator is looking at this library now" signal — server boosts pending thumbnails for that library so they jump the queue:

```python
# Inside the existing GET /files handler, after the file rows are fetched
if library_id and thumbnail_worker is not None:
    try:
        boosted = await thumbnail_worker.boost_library(db, library_id)
        if boosted:
            logger.debug("Boosted %d pending thumbnails for library=%s", boosted, library_id)
    except Exception:
        # Best-effort: priority boost failure should never break the files
        # listing.  Swallow + log; worker still processes at default priority.
        logger.warning("Failed to boost thumbnail priority", exc_info=True)
```

`boost_library` is idempotent (UPDATE WHERE priority=0 → 10, so re-opens don't keep stacking).  Cost is one indexed UPDATE; negligible.

### 6.4 `services/library_service._library_aggregates` — `cover_urls` enrichment + URL versioning

Today:
```python
SELECT poster_url FROM media_files
 WHERE library_id = ? AND poster_url IS NOT NULL AND poster_url != ''
 ORDER BY updated_at DESC LIMIT 4
```

New behaviour: union with thumbnail URLs to fill the 4 slots.  TMDB still preferred (real art > extracted frame).  Each thumbnail URL carries a `?v=<generated_at_unix>` cache-buster so regeneration invalidates client caches automatically.

```python
# Step 1: get up to 4 TMDB posters
tmdb_urls = [...]  # existing query

# Step 2: if < 4, top up with thumbnail URLs
if len(tmdb_urls) < 4:
    needed = 4 - len(tmdb_urls)
    async with db.execute(
        """
        SELECT mf.id AS file_id,
               CAST(strftime('%s', t.generated_at) AS INTEGER) AS gen_unix
          FROM media_files mf
          JOIN media_thumbnails t ON t.file_id = mf.id
         WHERE mf.library_id = ?
           AND t.status = 'ready'
           AND (mf.poster_url IS NULL OR mf.poster_url = '')
         ORDER BY t.generated_at DESC
         LIMIT ?
        """,
        (library_id, needed),
    ) as cur:
        thumb_rows = await cur.fetchall()
    thumb_urls = [
        f"/api/v1/files/{r['file_id']}/thumbnail?v={r['gen_unix']}"
        for r in thumb_rows
    ]
    cover_urls = tmdb_urls + thumb_urls
else:
    cover_urls = tmdb_urls
```

**The `/api/v1/...` prefix is server-relative** — the client already prepends its own base URL through `ApiClient`, so this Just Works without changing the client.

**Exclude files that already have TMDB poster_url** — the JOIN filters them out so we don't show duplicate art (TMDB poster + extracted frame from the same file).

**Cache-buster (`?v=<gen_unix>`):** the endpoint **ignores** this query param (it's only there to invalidate `cached_network_image` / browser caches when a thumbnail is regenerated).  When the operator hits "Regenerate thumbnails", `generated_at` shifts → `gen_unix` changes → URL changes → the next `cover_urls` fetch returns a URL the client treats as fresh.  No client-side cache logic needed.

### 6.5 `routers/files.py` — `GET /{file_id}/thumbnail` endpoint

```python
@router.get("/{file_id}/thumbnail")
async def get_thumbnail(
    file_id: str,
    v: str | None = None,  # cache-buster from cover_urls; intentionally unused
    db: aiosqlite.Connection = Depends(get_db),
    _: object = Depends(validate_token_or_local),
):
    """Serve the cached JPEG. 404 when not yet generated.

    The `v` query param is accepted but ignored — it exists only to make
    the URL unique per generation so client image caches invalidate when
    a thumbnail is regenerated (see _library_aggregates §6.4).
    """
    async with db.execute(
        "SELECT status FROM media_thumbnails WHERE file_id = ?",
        (file_id,),
    ) as cur:
        row = await cur.fetchone()
    if row is None or row["status"] != "ready":
        raise HTTPException(status_code=404, detail="thumbnail not ready")

    path = get_data_dir() / "thumbnails" / f"{file_id}.jpg"
    if not path.exists():
        # Row says ready but file is gone — log and treat as 404.
        # The worker can re-queue on next backfill pass.
        logger.warning("Thumbnail row=ready but file missing: %s", path)
        raise HTTPException(status_code=404, detail="thumbnail file missing")

    return FileResponse(
        path,
        media_type="image/jpeg",
        headers={"Cache-Control": "public, max-age=86400"},  # 1 day
    )
```

Auth: same `validate_token_or_local` as `GET /files/{file_id}` — bearer token (mobile) or localhost (desktop control panel).

**No on-demand generation in the endpoint** — explicitly per owner direction.  404 → client gradient fallback.

### 6.6 `routers/library.py` — `POST /{library_id}/regenerate-thumbnails` endpoint

New endpoint that drives the desktop "Regenerate thumbnails" action.

```python
@router.post("/{library_id}/regenerate-thumbnails")
async def regenerate_thumbnails(
    library_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _: object = Depends(validate_token_or_local),
):
    """Reset every thumbnail row for files in library_id to pending.
    Deletes cached JPEGs on disk so the worker re-generates them with
    current settings (width, HDR tonemap, etc).
    Returns the count of files queued for re-generation.
    """
    # Verify library exists
    async with db.execute(
        "SELECT name FROM libraries WHERE id = ?", (library_id,)
    ) as cur:
        lib_row = await cur.fetchone()
    if lib_row is None:
        raise HTTPException(status_code=404, detail="library not found")

    count = await thumbnail_worker.regenerate_library(db, library_id)
    return {"queued": count}
```

`regenerate_library` (in `ThumbnailWorker`):
1. Fetches all `media_files.id` rows for this library.
2. `UPDATE media_thumbnails SET status='pending', attempts=0, error_message=NULL, generated_at=NULL, updated_at=now WHERE file_id IN (...)`.
3. Deletes the corresponding `<data_dir>/thumbnails/<file_id>.jpg` files from disk (best-effort; missing-file errors swallowed + logged).
4. Records `library.thumbnails_regenerated` activity event.
5. Returns the count.

### 6.7 `services/settings_service.py` — `thumbnail_width` field

New configurable field in `user_settings`:

```python
# In get_settings / update_settings:
thumbnail_width: int  # range enforced by router 160-640, default 320
```

Settings router validation:
```python
if thumbnail_width is not None and not (160 <= thumbnail_width <= 640):
    raise HTTPException(
        status_code=422,
        detail="thumbnail_width must be between 160 and 640",
    )
```

Worker reads the current value at the start of each `_worker_loop` claim cycle, passes it through to the extractor.  Width change mid-flight only affects new generations — already-generated thumbs keep their original width until regenerated.  The operator-triggered regeneration flow (§6.6) is the path for "I changed the width, please re-render."

---

## 7 · Client Components

Three small additions to the desktop control panel.  Mobile is untouched (it already consumes `cover_urls` and the new mixed-source URLs flow through unchanged).

### 7.1 Desktop — "Regenerate thumbnails" affordance on library detail panel

A new `_ActionTile` in the `_LibraryDetailPanel` Actions section (between "Rescan TMDB" and "View Library Files"):

```dart
_ActionTile(
  icon: Icons.image_outlined,
  title: 'Regenerate thumbnails',
  sub: 'Re-extract video frames + cover art for this library',
  onTap: onRegenerateThumbnails,
),
```

Wired through `LibraryCubit.regenerateThumbnails(libraryId)` → new repository method → `POST /api/v1/library/{id}/regenerate-thumbnails`.  Returns count; toast surfaces `"Queued N files for thumbnail regeneration"`.  Disabled while in flight to prevent double-clicks.

### 7.2 Desktop — Settings → Advanced → Thumbnail width slider

Existing Settings → Advanced tab gains one new row using the existing `FluxSlider` primitive:

```dart
_SettingBlock(
  title: 'Thumbnail width',
  subtitle: 'Width of generated per-file thumbnails (160-640 px). Smaller = faster + less disk; larger = sharper. Existing thumbs are unchanged — use Regenerate thumbnails on a library to re-render at the new size.',
  child: FluxSlider(
    value: settings.thumbnailWidth.toDouble(),
    min: 160,
    max: 640,
    divisions: 24,            // 20-px steps
    label: '${settings.thumbnailWidth} px',
    onChanged: (v) => onChange(v.round()),
  ),
),
```

Plumbing through `SettingsCubit.saveSettings(thumbnailWidth: ...)` → `PATCH /settings`.

### 7.3 Mobile — no code change

Mobile's `Library.coverUrls: List<String>` already accepts arbitrary URLs; `_PosterMosaic`-equivalent on mobile already renders them via `cached_network_image`.  Server-relative paths are resolved by `ApiClient.localBaseUrl` / `remoteBaseUrl`.  **Zero mobile code changes** — the new mixed-source `cover_urls` flow Just Works.

---

## 8 · Edge Cases

| # | Case | Behaviour |
|---|---|---|
| 1 | File moved/renamed between scan + worker pick-up | Worker re-resolves path from `media_files.path` at processing time.  If `Path(path).exists()` is False, marks `failed` with `error_message='path not found'`.  Next scan will UPDATE the path; a re-queue helper (`requeue_failed_for_file_id`) can be wired into the scan path's UPDATE branch (M2 stretch). |
| 2 | File deleted from disk | Same as #1 — worker hits `FileNotFoundError`, marks `failed`.  When the row is later removed from `media_files` (by `library_service.scan_library`'s purge of missing files), `ON DELETE CASCADE` drops the `media_thumbnails` row too.  Disk JPEG is orphaned — cleaned up by the §8.5 sweeper. |
| 3 | FFmpeg hangs on corrupt file | 30 s `asyncio.wait_for` on the subprocess.  Timeout → SIGKILL → mark `failed`.  Other worker slots unaffected. |
| 4 | Server restart mid-generation | `status='generating'` rows are stranded.  Startup task resets them to `pending` (with `attempts` increment) so they get retried.  Pattern matches `backfill_missing_durations`. |
| 5 | Thumbnail JPEG orphaned (DB row gone, file remains) | Periodic sweeper (every 6 h) walks `<data_dir>/thumbnails/` and deletes JPEGs whose `file_id` is not in `media_thumbnails`.  Bounded to 100 files per pass to avoid IO storms. |
| 6 | `generate_thumbnails` setting toggled off | Worker checks setting per tick; sleeps `poll_interval` while disabled.  In-flight generations finish normally.  When toggled back on, pending queue resumes from where it left off. |
| 7 | HDR video → washed-out thumbnail | `_extract_video` reads `media_files.hdr_format` and switches to the HDR→SDR tonemap chain (Hable operator at npl=100) when set.  Same chain plan 17 uses on the stream path.  Test fixture: tonemap a synthetic PQ-encoded `lavfi` source and assert the output isn't clipped to black/grey. |
| 8 | Audio file with no embedded art (most FLAC/OGG ripped from CD) | FFmpeg `-vcodec copy` returns non-zero exit + stderr "Output file does not contain any stream".  Helper recognises this signature and returns `skipped=True`.  Row goes to `skipped` — no retry. |
| 9 | Very short video (< 30 s) | `T = min(10, dur/3)` clamps to ~ 10 s for typical content, falls to 1.5 s for a 4.5 s file.  Worst case (clip < 3 s): `T = 1 s` minimum (clamp).  Almost no real video file is < 3 s. |
| 10 | Concurrent scans for the same library | `INSERT OR IGNORE` on `media_thumbnails` makes duplicate enqueues idempotent.  No race. |
| 11 | Disk full while writing JPEG | FFmpeg fails with non-zero exit.  Worker marks `failed`, logs.  Operator-visible via the failure-aggregation notification (§6.2) once the per-library threshold is reached. |
| 12 | Many libraries, each with many files | Worker is global; priority boost (§6.3.1) lets the just-opened library jump to the front of the queue.  Without boost, FIFO inside the priority=0 band. |
| 13 | Permission error reading source file | FFmpeg fails with EACCES.  Worker marks `failed`, logs.  No retry until next scan (which would re-INSERT via `INSERT OR IGNORE` — but since the row already exists, status stays `failed`).  Operator regeneration (§6.6) is the manual fix once permissions are corrected. |
| 14 | Worker crash during one file | Asyncio task gets cancelled or raises; the `try/finally` ensures the row is left in a recoverable state (`failed` with the exception in `error_message`).  Other slots keep working. |
| 15 | Subprocess inherits FD limits | Spawned via `asyncio.create_subprocess_exec` with `stdin=DEVNULL`, `stdout=DEVNULL`, `stderr=PIPE` (capped at 8 KB).  Closed on exit.  No FD leak. |
| 16 | Settings PATCH to disable mid-scan | Already covered by #6 — worker re-reads setting per claim. |
| 17 | Backfill on existing install (migration runs) | Migration's INSERT seeds every existing file as `pending`.  First server start after deploy = worker chews through entire library.  Bounded by concurrency (2 slots) × ~1 s/file = ~30 min for 3 600 files. |
| 18 | PyMuPDF raises on encrypted PDF | `fitz.open()` raises `fitz.FileDataError` (or sets `doc.is_encrypted = True`).  Helper checks `is_encrypted` before `get_pixmap`; if encrypted, returns `skipped=True` (no password handling in v1).  Row goes to `skipped` — no retry. |
| 19 | PyMuPDF raises on corrupt PDF | Caught in the `try/except` around `fitz.open`/`get_pixmap`; treated as `failed` with the exception in `error_message`. |
| 20 | Multi-page PDF with empty first page (just a blank cover sheet) | v1: accept it.  The first-page convention matches most user expectations (book covers, document headers).  Multi-page heuristic is v1.1. |
| 21 | Settings PATCH changes `thumbnail_width` while worker is in-flight | Worker re-reads width per claim (start of each iteration), so the next-claimed file uses the new width.  In-flight generation finishes at the old width.  Existing thumbs at the old width are unchanged — the operator clicks "Regenerate thumbnails" (§6.6) to rebuild at the new size. |
| 22 | Failure notification threshold not reached | If a library has 3 permanent failures (below the default threshold of 5), no notification fires.  Failures still recorded in `media_thumbnails.error_message`.  Operator can inspect via the DB if curious.  Settings UI doesn't expose per-row error today (v1.1 surface). |
| 23 | Operator dismisses failure notification, more files fail later | The dismiss flips `dismissed_at`.  The next failure that crosses the threshold writes a new notification (the dedup query filters by `dismissed_at IS NULL`).  Operator gets one summary per cycle. |
| 24 | Operator triggers Regenerate while worker is processing the same library | `regenerate_library` sets status=`pending` even on rows that are currently `generating`.  The in-flight slot's `UPDATE WHERE status='generating'` succeeds (it claimed the row earlier), writes `ready`, but the row goes back to `pending` on the next regenerate sweep.  Net effect: one wasted extraction, then a clean rebuild.  Acceptable. |
| 25 | URL cache-buster (`?v=`) drifts between client cache + server JPEG | Client cache key includes `?v=` (Flutter's `cached_network_image` keys on the full URL).  When `generated_at` shifts → URL changes → cache miss → fetches fresh.  No stale-art window. |
| 26 | Priority boost on a library with all-ready thumbs | `UPDATE WHERE status='pending' AND priority=0` matches zero rows.  Idempotent no-op.  Logger debug shows `boosted=0`. |
| 27 | PyMuPDF wheel doesn't ship for the operator's Python version / OS | At least Python 3.10–3.13 + Windows/Mac/Linux are covered by PyMuPDF wheels.  CI verifies install on the project's supported Python floor.  If a fringe platform fails, the import is guarded behind a try/except — `kind=pdf` falls through to `skipped` with `error_message='pymupdf not available'`, no startup crash. |

---

## 9 · Milestones

Six milestones, **~8–10 h end-to-end.** Order is deliberate: schema before code, extractors before worker, worker before endpoint, settings before UI, UI before doc sweep.

### M1 — Schema + extraction service (~90 min)

- Migration `037_media_thumbnails.sql` (table + partial index + backfill INSERT).
- New pip dep: `pymupdf ^1.24.x` in `apps/server/pyproject.toml` (latest version verified at implementation time per CLAUDE.md prohibition #12).
- `services/thumbnail_service.py` with `extract_thumbnail()` dispatcher + 4 helpers (`_extract_video` w/ HDR tonemap branch, `_extract_image`, `_extract_audio`, `_extract_pdf`) + `ThumbnailResult` dataclass.
- Unit tests:
  - `lavfi testsrc` SDR → green path
  - `lavfi testsrc` + synthetic PQ flag → HDR tonemap path (assert non-clipped output)
  - `lavfi anullsrc` audio → `skipped`
  - Image fixture (small PNG) → resize success
  - Encrypted PDF fixture → `skipped`
  - Corrupt PDF fixture → `failed`
  - Width parameter respected (160 / 320 / 640)

**Acceptance:** `pytest tests/test_thumbnail_service.py` green (all 7 cases).  Migration applies cleanly to a fresh DB and to a populated DB (verified by manually counting `media_thumbnails` rows = `media_files` rows post-migration).

### M2 — Worker + scan-path enqueue + priority + failure notifications (~120 min)

- `services/thumbnail_worker.py` with `ThumbnailWorker` class:
  - Atomic claim via `UPDATE ... RETURNING` ordered by `priority DESC, created_at ASC`.
  - `enqueue(db, file_id, priority=0)` (called from scan path).
  - `boost_library(db, library_id) -> int` (priority bump).
  - `regenerate_library(db, library_id) -> int` (reset + disk JPEG delete).
  - Failure-notification aggregation via `_maybe_emit_failure_notification` + `notification_service.create`.
  - Orphan-JPEG sweeper coroutine (every 6 h).
- `main.py` lifespan: instantiate `ThumbnailWorker` + `await start()` on startup, `await stop()` on shutdown.
- `library_service.scan_library` and `_persist_probe`'s sibling INSERT path: call `await thumbnail_worker.enqueue(db, file_id)`.
- `routers/files.py` `GET /files?library_id=X`: call `boost_library` for the requested library (best-effort, swallows errors).
- Startup task: reset `status='generating'` rows to `pending` (in-place idempotent).
- Unit tests: 10 cases:
  - Claim atomicity (2 workers, 1 row)
  - Priority ordering (boosted rows picked first)
  - Setting toggle pauses worker
  - Retry after restart (orphaned `generating` rows reset)
  - Skip threshold (audio without APIC, encrypted PDF)
  - Kind dispatch (video / image / audio / pdf / other-skipped)
  - Failure threshold notification emitted on 5th permanent failure
  - Notification de-dup (won't fire twice for same library while undismissed)
  - `boost_library` is idempotent on already-boosted rows
  - `regenerate_library` deletes JPEGs + resets rows

**Acceptance:** with a 10-file test library, scan returns in < 200 ms (within scan-perf budget) and worker generates all 10 thumbnails inside 60 s.  Failure-threshold notification fires when 5 files in one library fail.

### M3 — Endpoint + cover_urls integration + URL versioning + regen endpoint (~60 min)

- `routers/files.py`: new `GET /{file_id}/thumbnail?v=<unix>` route (v query param ignored).
- `routers/library.py`: new `POST /{library_id}/regenerate-thumbnails` route.
- `library_service._library_aggregates`: union TMDB posters + thumbnail URLs (with `?v=<gen_unix>` suffix) to fill 4 slots.
- Tests: 8 cases:
  - Endpoint returns 200 + JPEG bytes when ready
  - Endpoint 404 when status != ready
  - Endpoint 404 when DB says ready but file missing (log path)
  - `cover_urls` aggregation: all-TMDB, all-thumbs, mixed (3 cases)
  - `?v=` query param accepted and ignored
  - `POST /regenerate-thumbnails` resets rows + deletes JPEGs + records activity event
  - `POST /regenerate-thumbnails` 404 on unknown library

**Acceptance:** desktop library card visibly shows a real video frame for a freshly-scanned Movies library that has zero TMDB enrichment.  HDR source produces an SDR thumbnail (not washed out).

### M4 — `thumbnail_width` settings field (~45 min)

- Migration `038_user_settings_thumbnail_width.sql` (`ALTER TABLE user_settings ADD COLUMN thumbnail_width INTEGER NOT NULL DEFAULT 320`).
- `services/settings_service.py`: extend `get_settings` / `update_settings` for `thumbnail_width`.
- `models/settings.py`: add field to `Settings` + `UpdateSettings`.
- `routers/settings.py`: range validation 160–640 (422 on out-of-range).
- Worker reads `thumbnail_width` per claim cycle, passes through to extractor.
- Unit tests: 3 cases:
  - GET /settings includes `thumbnail_width=320` (default after migration)
  - PATCH /settings persists `thumbnail_width=480`
  - PATCH /settings 422 on out-of-range (`thumbnail_width=2000`)

**Acceptance:** server suite +3, settings round-trip green.

### M5 — Desktop regenerate UI + Settings → Advanced slider (~75 min)

- `LibraryRepository.regenerateThumbnails(libraryId)` → `POST /api/v1/library/{id}/regenerate-thumbnails`.
- `LibraryCubit.regenerateThumbnails(libraryId)` method.
- `_LibraryDetailPanel`: new `_ActionTile(icon: image_outlined, title: 'Regenerate thumbnails', sub: 'Re-extract video frames + cover art for this library', onTap: ...)`.
- SnackBar feedback: success `"Queued $N files for thumbnail regeneration"`, failure surfaces the API exception message.
- Settings → Advanced tab: new `_SettingBlock` with `FluxSlider` for `thumbnail_width` (160–640 in 20 px steps).
- `SettingsCubit.saveSettings(thumbnailWidth: ...)` plumbing.
- Tests: 3 desktop cubit cases — `regenerateThumbnails` happy path / API failure / state refresh after success.

**Acceptance:** clicking "Regenerate thumbnails" on a library detail panel triggers the workflow and the cards visibly re-render with fresh art within ~30 s.  Adjusting the slider in Settings → Advanced persists and is read by the worker on the next generation.

### M6 — Sweeper + docs + AGENT_LOG (~45 min)

- Verify orphan-JPEG sweeper runs on schedule (manual test: drop a stray `<file_id>.jpg` into thumbnails dir, wait for the tick, confirm deleted).
- Update `docs/04_api/01_api_contracts.md` — document `GET /files/{id}/thumbnail` + `POST /library/{id}/regenerate-thumbnails`.
- Update `docs/03_data/02_database_schema.md` — `media_thumbnails` table + `user_settings.thumbnail_width` column.
- Update `docs/00_overview/current_status.md` — plan 27 entry.
- Update `docs/05_infrastructure/02_url_inventory.md` — both new endpoints.
- Update `docs/08_frontend/01_frontend_architecture.md` — note the `cover_urls` source change + new Library detail action + new Settings → Advanced slider.
- Update `CLAUDE.md` lookup table (one row).
- AGENT_LOG entry per `docs/12_guidelines/04_agent_log_format.md`.

**Acceptance:** all docs in sync, AGENT_LOG entry appended, no broken cross-refs.

---

## 10 · Out of Scope

Owner re-scoped 2026-05-16 to pull nine previously-deferred items into v1.  Only one remains deferred:

- **On-demand generation in the endpoint** — explicitly forbidden by owner direction.  Background-only worker path is the sole generation route.  Endpoint returns 404 when not yet ready; client falls back to the gradient mosaic.  Reasoning: keeps the endpoint hot-path simple (zero FFmpeg risk) + first cold view doesn't stall on a ~1 s extraction × 4 missing thumbs.

Other items that remain **explicitly not in scope** (and not on a v1.1 roadmap either — flagged here for clarity):

- **Multi-page PDF page picker** — first page only.  No "show page 3 instead" UI.
- **Encrypted PDF unlock** — encrypted PDFs are `skipped`.  No password-prompt UI.
- **Per-file thumbnail tiles on the Files screen** — desktop Library detail panel uses generated thumbs (via `cover_urls`); the per-file rows in Files screen don't yet show thumbnails.  Adding a thumbnail column to the Files screen is a v1.1 UI polish, not gated on plan 27.
- **Mobile UI for "Regenerate thumbnails"** — only desktop control panel exposes regeneration.  Mobile clients consume `cover_urls` but don't trigger regeneration.
- **Per-file thumbnail timestamps** (e.g. "regenerate this one file") — only library-level regeneration in v1.
- **Per-file error inspection UI** — `media_thumbnails.error_message` is populated but not surfaced in the desktop UI.  Operator can query the DB directly if curious.
- **Thumbnail quality configurability** (JPEG `-q:v` value) — fixed at 5 (high-quality JPEG).  Only width is operator-configurable.

---

## 11 · Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| FFmpeg hangs on a malformed file, blocks a worker slot | Medium | 30 s timeout + SIGKILL on subprocess; max_attempts caps retry; other slots unaffected |
| Backfill INSERT on migration takes too long for libraries with 10 000+ files | Low | Single `INSERT ... SELECT` is < 1 s for 10 K rows in SQLite; verified locally before merge |
| Worker silently dies on uncaught exception | Medium | Top-level `try/except` wraps the loop body; logs error and continues; unit test covers crash recovery |
| Settings PATCH to disable while a generation is in flight | Low | In-flight finishes normally (no kill); subsequent claims short-circuit on setting check |
| Disk space exhausted by thumbnails | Low | Up-to-640 px JPEG ≈ 50 KB each at the max width; 10 K files = 500 MB at max width; orphan sweeper prevents unbounded growth |
| `UPDATE ... RETURNING` not supported on operator's SQLite | Very Low | Requires SQLite 3.35 (Mar 2021); Python 3.11+ ships 3.40+; verified at project floor of Python 3.11 |
| Race between scan path enqueue and worker claim on the same file_id | Low | `INSERT OR IGNORE` is atomic; if worker has already started, second enqueue no-ops |
| Endpoint returns 404 right after generation completes (cache lag) | Low | DB UPDATE is committed before the JPEG file is closed; SQLite WAL means readers see committed writes immediately |
| PyMuPDF wheel install fails on operator's platform | Low | PyMuPDF ships wheels for Win / Mac (x86_64 + arm64) / Linux (manylinux) across Python 3.10–3.13.  Import guarded behind try/except — PDF generation falls through to `skipped` on import failure, no startup crash. |
| PyMuPDF AGPL license blocks distribution | Very Low | Fluxora is open-source self-hosted (operators run on their own hardware); AGPL is compatible.  Confirmed before merge. |
| HDR tonemap chain produces incorrect colour | Medium | Same chain as plan 17 streams which is operator-verified.  Unit test asserts non-clipped output histogram. |
| Priority boost flood-fills the queue when an operator rapidly clicks through libraries | Low | `boost_library` is idempotent (`UPDATE WHERE priority=0`); already-boosted rows stay at 10.  Worst case: all pending rows hit priority=10 → degenerates to FIFO inside that band.  Same behaviour as no-boost. |
| Failure-notification spam | Low | De-dup by `(category='thumbnail', related_id=library_id, dismissed_at IS NULL)` matches the existing notification-producer pattern.  One open notification per library at any time. |
| `thumbnail_width` change strands old-width thumbs at different sizes | Low | Operator regenerates via the new UI action.  Mixed-size mosaic isn't visually broken (each tile is independently scaled by `Image.network`'s `BoxFit.cover`).  Acceptable while transition is in flight. |
| Regenerate API endpoint floods worker | Low | Worker concurrency cap (default 2) bounds throughput; queue grows linearly with library size but processes at fixed rate.  10 K-file library regen takes ~ 1.5 hours at 2 slots × ~1 s — long but bounded; operator-controlled action. |

---

## 12 · References

- `apps/server/services/library_service.py:_library_aggregates` — cover_urls aggregation today
- `apps/server/services/library_service.py:_persist_probe` — scan-time probe pattern (similar shape, useful precedent)
- `apps/server/services/library_service.py:backfill_missing_durations` — startup-backfill pattern this plan mirrors
- `apps/desktop/lib/features/library/presentation/screens/library_screen.dart:_PosterMosaic` — consumer of `cover_urls`
- `apps/desktop/lib/features/library/presentation/screens/library_screen.dart:_GradientMosaicFallback` — the placeholder this plan reduces dependence on
- `docs/10_planning/26_desktop_cp_ia_redesign.md` — sibling plan that landed in the same cycle; format conventions

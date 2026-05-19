# 09 — Library Scan & Thumbnail Pipeline

> What happens when the operator adds a library or hits "Rescan". Walks the filesystem → probes media → enriches with TMDB → enqueues thumbnails.

---

## Library scan — top level

```mermaid
sequenceDiagram
  autonumber
  actor Op as Operator (Desktop CP)
  participant R as routers/library.py
  participant LS as library_service
  participant Lock as per-library asyncio lock
  participant FS as Filesystem walk
  participant FP as ffprobe subprocess
  participant DB as SQLite
  participant TW as thumbnail_worker
  participant TM as tmdb_service
  participant N as notification_service

  Op->>R: POST /api/v1/library/{id}/scan
  R->>LS: scan_library(id)
  LS->>Lock: acquire (one scan per library at a time)
  LS->>DB: read libraries.root_paths
  loop each root path
    LS->>FS: os.walk(root, followlinks=False)
    loop each supported file
      LS->>DB: INSERT OR IGNORE media_files (by path UNIQUE)
      alt newly inserted OR mtime newer than updated_at
        LS->>FP: ffprobe → width/height/codec/hdr_format/duration/audio_tracks
        FP-->>LS: probe JSON
        LS->>DB: UPDATE media_files SET width, height, codec_name, hdr_format, duration_sec, audio_tracks, updated_at
        LS->>TW: enqueue thumbnail (INSERT OR IGNORE media_thumbnails, priority=5)
        opt video w/ probable TMDB title AND tmdb_enabled
          LS->>TM: search(title, year)
          TM-->>LS: best match
          LS->>DB: UPDATE media_files SET tmdb_id, title, overview, poster_url
        end
      end
    end
  end
  LS->>DB: UPDATE libraries.last_scanned = now
  LS-->>R: stats {added, updated, skipped}
  R->>N: broadcast_event('library_changed')
  N-.->WS["/ws/notifications subscribers"]
  R-->>Op: 200 ScanResult
  Lock-->>LS: release
```

---

## Subtree scan (plan 28 Phase C)

```mermaid
sequenceDiagram
  autonumber
  participant Op as Operator (right-click folder)
  participant R as routers/library.py
  participant BS as browse_service.resolve_subtree_for_scan
  participant LS as library_service.scan_library
  participant Lock as per-library lock

  Op->>R: POST /api/v1/library/{id}/scan-subtree?path=<rel>
  R->>BS: resolve path under library roots
  alt path escapes root
    BS-->>R: 403
    R-->>Op: 403
  end
  BS-->>R: absolute subtree path
  R->>LS: scan_library(id, subtree_abs=path)
  LS->>Lock: acquire (same lock as full scan)
  Note over LS: walk only subtree, otherwise identical to full scan
  LS-->>R: ScanResult
  R-->>Op: 200
```

The subtree path is routed under the **same per-library asyncio lock** as full scans — you can't full-scan and subtree-scan the same library concurrently.

---

## Thumbnail worker

```mermaid
graph TB
  classDef worker fill:#7c3aed,stroke:#fff,color:#fff
  classDef extractor fill:#a78bfa,stroke:#000,color:#000
  classDef store fill:#1f2937,stroke:#7c3aed,color:#fff

  Boot[App start<br/>crash-recovery:<br/>UPDATE generating → pending]:::worker
  Boot --> Loop

  Loop[Worker loop<br/>CONCURRENCY=4]:::worker --> Claim["UPDATE media_thumbnails<br/>SET status=generating<br/>RETURNING file_id<br/>ORDER BY priority DESC, created_at ASC"]:::worker
  Claim --> Kind{File kind?}
  Kind -- video --> FFv["FFmpeg -ss N -frames:v 1<br/>+ optional HDR→SDR Hable<br/>+ lanczos→bilinear<br/>(hwaccel auto, sw-fallback retry)"]:::extractor
  Kind -- image --> FFi[FFmpeg image scale]:::extractor
  Kind -- audio --> FFa["FFmpeg -vcodec copy<br/>(APIC embedded art only)"]:::extractor
  Kind -- pdf --> PDF[PyMuPDF first page render]:::extractor

  FFv --> Out[(thumbnails/<file_id>.jpg<br/>q:v 8, configurable width)]:::store
  FFi --> Out
  FFa --> Out
  PDF --> Out

  Out --> Done["UPDATE status=ready<br/>generated_at=now"]:::worker
  Kind -- audio w/o art --> Skip["UPDATE status=ready<br/>(no file written)"]:::worker
  FFv -. fail .-> Retry
  FFi -. fail .-> Retry
  FFa -. fail .-> Retry
  PDF -. fail .-> Retry
  Retry["UPDATE status=failed<br/>attempts++<br/>error_message"]:::worker --> Agg{≥5 failures<br/>per library?}
  Agg -- yes --> Notif["notifications.category='thumbnail'<br/>dedup against open"]:::worker
```

### Worker priorities

| Priority | When |
|---|---|
| 10 | Operator opened the library — boost pending rows for that library |
| 10 | New single-file index (plan 28 Phase C) |
| 10 | Regenerate-single-thumbnail (plan 28 Phase C) |
| 5 | Default — scan enqueued |

---

## Endpoint surface

```mermaid
graph LR
  classDef get fill:#16a34a,stroke:#000,color:#fff
  classDef post fill:#7c3aed,stroke:#fff,color:#fff
  classDef del fill:#ef4444,stroke:#000,color:#fff

  GET1["GET /api/v1/files/{id}/thumbnail?v=&lt;unix&gt;<br/>1-day Cache-Control<br/>404 if not ready"]:::get

  POST1[POST /api/v1/library/{id}/scan<br/>full scan]:::post
  POST2[POST /api/v1/library/{id}/scan-subtree?path=]:::post
  POST3[POST /api/v1/library/{id}/index-file?path=]:::post
  POST4[POST /api/v1/library/{id}/regenerate-thumbnails<br/>resets all rows]:::post
  POST5[POST /api/v1/files/{id}/regenerate-thumbnail<br/>resets one row]:::post

  GET2[GET /api/v1/library/{id}/browse?path=]:::get
  GET3[GET /api/v1/library/{id}/folder-size?path=]:::get
```

`?v=<unix>` is the cache-buster — set to `media_thumbnails.generated_at` so a regenerate invalidates Flutter's `cached_network_image` + browser caches automatically.

---

## Orphan-JPEG sweep + crash recovery

```mermaid
flowchart LR
  classDef boot fill:#7c3aed,stroke:#fff,color:#fff
  classDef sweep fill:#a78bfa,stroke:#000,color:#000

  Boot["App startup"]:::boot --> Recover["UPDATE media_thumbnails<br/>SET status='pending'<br/>WHERE status='generating'<br/>(resume after crash)"]:::boot
  Sweep["Every 6 hours"]:::sweep --> Find["Find JPEGs in thumbnails/<br/>with no matching media_files row"]:::sweep
  Find --> Delete["DELETE up to 100/pass<br/>(bounded)"]:::sweep
```

---

## Browse endpoint (plan 28)

```mermaid
sequenceDiagram
  autonumber
  participant C as Client (Desktop folder browser)
  participant R as routers/library.py
  participant BS as browse_service
  participant FS as Filesystem
  participant DB as SQLite

  C->>R: GET /api/v1/library/{id}/browse?path=<rel>
  R->>BS: resolve_path_under_root(library_id, rel)
  alt path escapes root
    BS-->>R: 403
  end
  BS-->>R: absolute path
  R->>FS: listdir + stat (hidden filter)
  R->>DB: JOIN media_files + media_thumbnails<br/>+ EXISTS(stream_sessions) per entry
  DB-->>R: per-entry index status + media payload
  R-->>C: BrowseListResponse {entries, mtime_unix, media payloads}
```

The browse endpoint does NOT enqueue new thumbnails — only `scan` / `scan-subtree` / `index-file` insert into `media_thumbnails`. Hidden files are returned but flagged so the desktop can choose to filter them.

---

## Stale-thumbnail detection

```mermaid
flowchart TD
  Open([Operator opens library / folder]) --> Q1{For each entry…}
  Q1 --> Q2{source mtime ><br/>thumbnail generated_at?}
  Q2 -- yes --> Reset["UPDATE media_thumbnails<br/>SET status='pending'<br/>priority=5"]
  Q2 -- no --> Skip[Leave alone]
  Reset --> Report["thumbnail_status='stale'<br/>in browse response"]
```

Source-modified files are auto-re-queued for thumbnail regen. The browse response reports `thumbnail_status='stale'` so the client can show a refresh hint.

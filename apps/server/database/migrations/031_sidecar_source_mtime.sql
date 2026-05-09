-- Plan 19 §M6 — sidecar source-mtime tracking
-- (docs/10_planning/19_library_transcode_followups.md).
--
-- When a sidecar is produced, the worker stamps the source file's
-- mtime here.  Library scans compare the source's current mtime
-- against this value: if the source has been overwritten since
-- transcode (e.g. operator replaced a YouTube-AV1 capture with the
-- BluRay rip at the same path), `transcoded_path` is cleared so the
-- next play uses the fresh source.  The on-disk sidecar is left
-- alone — operator's call whether to delete it via the History tab.

ALTER TABLE media_files ADD COLUMN transcoded_source_mtime INTEGER;

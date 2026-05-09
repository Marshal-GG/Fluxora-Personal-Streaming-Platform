-- Plan 19 §M2 — transcode storage location chooser
-- (docs/10_planning/19_library_transcode_followups.md).
--
-- Two columns govern where pre-transcoded H.264 sidecars land:
--
--   * `transcode_storage_mode` — `dedicated` (default) nests sidecars
--     under a single operator-configurable cache root, mirroring the
--     source library's directory tree.  `inline` keeps them next to
--     each source under a hidden `.fluxora-transcodes/` subfolder so
--     existing backup tooling follows the source naturally.  Both modes
--     always nest (loose side-by-side was dropped after the plan-18
--     real-device test).
--   * `transcode_cache_root` — operator-configurable absolute path used
--     by `dedicated` mode.  NULL / empty falls back to a server-data-
--     directory sibling (`<data-dir>/transcodes/`), never C: drive.
--     Validated at PATCH time (must be absolute, writable, and outside
--     every library root so a rescan can't loop on its own output).

ALTER TABLE user_settings ADD COLUMN
    transcode_storage_mode TEXT NOT NULL DEFAULT 'dedicated'
    CHECK(transcode_storage_mode IN ('dedicated', 'inline'));
ALTER TABLE user_settings ADD COLUMN
    transcode_cache_root TEXT;

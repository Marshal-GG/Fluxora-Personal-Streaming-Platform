-- Per-library TMDB-enrichment opt-out.
--
-- Operators with non-media libraries (personal screenshots, game
-- captures, document archives) don't want TMDB matching their
-- filenames to movies and stamping bogus poster_url / title /
-- overview onto the rows.  Toggle defaults ON so existing libraries
-- keep their current behaviour; flipping to OFF disables both future
-- enrichment passes (`_enrich_with_tmdb` / "Rescan TMDB" button) and
-- read-side visibility of any TMDB columns already on disk
-- (poster_url, tmdb_id, title, overview).
--
-- "Hide but keep" semantics: rows retain their TMDB data so flipping
-- the toggle back ON instantly restores the cards' poster mosaic
-- + the folder browser's TMDB art without re-fetching from TMDB.
-- The columns are masked out by the read-path services
-- (`_library_aggregates`, `_attach_index_status`) when the library's
-- tmdb_enabled is 0.

ALTER TABLE libraries ADD COLUMN tmdb_enabled INTEGER NOT NULL DEFAULT 1;

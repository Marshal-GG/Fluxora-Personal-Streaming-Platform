-- Plan 27 M4 — operator-configurable thumbnail width.
--
-- Worker reads this value at the start of each claim cycle and passes
-- it through to services.thumbnail_service.extract_thumbnail.  Range
-- is enforced by the settings router (160-640); this column has no
-- CHECK to avoid breaking the schema if the range is widened in a
-- future plan.
--
-- Default 320 matches the original hardcoded value plumbed through
-- M1's extractor.  Existing rendered thumbs at the previous width are
-- unchanged on schema add — operator triggers regeneration via the M5
-- "Regenerate thumbnails" affordance to re-render at the new size.

ALTER TABLE user_settings ADD COLUMN thumbnail_width INTEGER NOT NULL DEFAULT 320;

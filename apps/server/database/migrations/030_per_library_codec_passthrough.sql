-- Plan 19 §M8 — per-library AV1 / VP9 codec passthrough overrides
-- (docs/10_planning/19_library_transcode_followups.md).
--
-- Tri-state per codec on each library: NULL inherits the global
-- `streaming_mode` setting; 0 forces transcoding for sources of that
-- codec in this library; 1 forces stream-copy.  Honoured by
-- `ffmpeg_service.start_stream` via `_resolve_codec_passthrough`.
--
-- Use case: an operator running `client-decode` globally (most devices
-- modern enough to hardware-decode AV1) but with one library of pre-
-- 2021 captures targeted at older device pools — flip `av1_stream_copy
-- _override = 0` on that library to force transcoding regardless of
-- the global toggle.

ALTER TABLE libraries ADD COLUMN av1_stream_copy_override INTEGER;
ALTER TABLE libraries ADD COLUMN vp9_stream_copy_override INTEGER;

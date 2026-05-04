-- Migration 020: Add encoder priority chain to user_settings.
--
-- Slice C of the GPU UX plan — operator can configure a fallback chain
-- like `["h264_nvenc", "h264_qsv", "libx264"]` so when the first encoder
-- hits its concurrent-session cap (NVENC = 3 on consumer cards), the
-- session_router transparently falls through to the next entry.
--
-- Stored as a JSON-encoded list rather than a child table — the chain
-- is small (typically 1-4 entries), single-tenant, and never queried
-- relationally.  NULL means "use the default chain"
-- (`[transcoding_encoder, "libx264"]`) — back-compat for installs that
-- predate Slice C.

ALTER TABLE user_settings
    ADD COLUMN transcoding_chain TEXT DEFAULT NULL;

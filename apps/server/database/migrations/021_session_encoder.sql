-- Migration 021: Record which encoder each stream session actually used.
--
-- The session_router (Slice C) may not pick the first encoder in the
-- chain — when NVENC is at its 3-session cap, the next session falls
-- through to QSV / libx264 / etc.  Recording the actual encoder per
-- session lets the desktop's active-sessions table show which engine is
-- driving each stream and supports historical "why did N+1 fall back?"
-- diagnostics across server restarts (the in-memory ring buffer in
-- session_router only covers the current process lifetime).
--
-- NULL on existing rows is fine — the column is read-only metadata for
-- new sessions only.

ALTER TABLE stream_sessions
    ADD COLUMN encoder_used TEXT DEFAULT NULL;

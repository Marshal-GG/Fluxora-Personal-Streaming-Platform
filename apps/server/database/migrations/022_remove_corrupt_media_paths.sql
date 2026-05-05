-- Migration 022: Delete media_files rows with corrupt paths.
--
-- A bug in the upload flow (since fixed in services/library_service.py)
-- treated `libraries.root_paths` as a JSON string instead of a parsed
-- list, so `root_paths[0]` returned the literal `[` character.  The
-- resulting upload paths looked like `[\<filename>` on Windows.  FFmpeg
-- then rejected them with `Error opening input: No such file or
-- directory`, surfacing as a "Transcode failed" notification to the
-- user with no actionable diagnostic.
--
-- The current code rejects malformed paths at INSERT time
-- (_is_valid_absolute_media_path + the upload-flow guard added in this
-- batch), but pre-existing rows from the buggy era still produce
-- transcode errors when the user picks them.  Drop them so the user
-- only sees the rows that point at real files.
--
-- `stream_sessions.file_id` has a FOREIGN KEY to media_files(id), so
-- the dependent (already-ended) sessions for the corrupt rows must go
-- first or the DELETE on media_files trips the FK and aborts the
-- entire startup.  Sessions are activity history; deleting the
-- entries that point at unreadable files loses no in-flight state.
--
-- Two patterns are removed:
--   1. Paths starting with `[\` or `[/` — the exact corruption signature.
--   2. Paths with no Windows drive letter, no leading `/`, and no UNC
--      prefix — i.e. not absolute.  Belt-and-braces against any other
--      source of relative paths sneaking into the table.

-- Step 1 — orphan stream_sessions for the about-to-be-deleted rows.
DELETE FROM stream_sessions
 WHERE file_id IN (
       SELECT id FROM media_files
        WHERE path LIKE '[\%'
           OR path LIKE '[/%'
       );

DELETE FROM stream_sessions
 WHERE file_id IN (
       SELECT id FROM media_files
        WHERE path NOT LIKE '_:\%'
          AND path NOT LIKE '_:/%'
          AND path NOT LIKE '/%'
          AND path NOT LIKE '\\\\%'
       );

-- Step 2 — the corrupt media_files rows themselves.
DELETE FROM media_files
 WHERE path LIKE '[\%'
    OR path LIKE '[/%';

DELETE FROM media_files
 WHERE path NOT LIKE '_:\%'      -- Windows drive: `C:\...`, `D:\...`
   AND path NOT LIKE '_:/%'      -- Windows drive with forward slashes
   AND path NOT LIKE '/%'        -- POSIX absolute
   AND path NOT LIKE '\\\\%';    -- Windows UNC path: `\\server\share\...`

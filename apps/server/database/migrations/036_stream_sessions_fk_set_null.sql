-- 002_sessions originally declared:
--   file_id   TEXT NOT NULL REFERENCES media_files(id),
--   client_id TEXT NOT NULL REFERENCES clients(id),
-- with no ON DELETE clause.  SQLite's default is NO ACTION, which
-- means deleting a media_file or client that has session history
-- *fails outright* with a FOREIGN KEY constraint error rather than
-- cascading or nulling the FK.  Today no operator has hit this
-- because nothing yet deletes media_files directly, but the library-
-- delete path and any future file-purge tool will trip it.
--
-- Fix: drop NOT NULL on both columns and add ON DELETE SET NULL so
-- a removed file or client preserves the session history (bytes
-- transferred, connection_type — the analytics value of these rows
-- is in the aggregate, not in the FK target).  The 021_session_encoder
-- column `encoder_used` is preserved.
--
-- SQLite cannot ALTER FK constraints in place, so this rebuilds the
-- table: copy → drop → rename, FK pragma disabled across the rebuild
-- per the SQLite recommended pattern.

PRAGMA foreign_keys=OFF;

BEGIN TRANSACTION;

CREATE TABLE stream_sessions_new (
    id                TEXT    PRIMARY KEY,
    file_id           TEXT    REFERENCES media_files(id) ON DELETE SET NULL,
    client_id         TEXT    REFERENCES clients(id)     ON DELETE SET NULL,
    started_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at          TIMESTAMP,
    connection_type   TEXT    NOT NULL CHECK(connection_type IN ('lan','webrtc_p2p','turn_relay')),
    bytes_transferred INTEGER NOT NULL DEFAULT 0,
    progress_sec      REAL    NOT NULL DEFAULT 0,
    encoder_used      TEXT    DEFAULT NULL
);

INSERT INTO stream_sessions_new (
    id, file_id, client_id, started_at, ended_at,
    connection_type, bytes_transferred, progress_sec, encoder_used
)
SELECT
    id, file_id, client_id, started_at, ended_at,
    connection_type, bytes_transferred, progress_sec, encoder_used
FROM stream_sessions;

DROP TABLE stream_sessions;
ALTER TABLE stream_sessions_new RENAME TO stream_sessions;

CREATE INDEX IF NOT EXISTS idx_stream_sessions_client_id ON stream_sessions(client_id);
CREATE INDEX IF NOT EXISTS idx_stream_sessions_file_id   ON stream_sessions(file_id);
CREATE INDEX IF NOT EXISTS idx_stream_sessions_ended_at  ON stream_sessions(ended_at);

COMMIT;

PRAGMA foreign_keys=ON;

-- One-off data cleanup: notifications.related_id / related_kind have
-- no FK (deliberate — audit log shape), so rows referring to deleted
-- stream_sessions and other dead targets accumulate over time.  Null
-- the dangling pointer on the existing rows so the UI's "open target"
-- affordance stops trying to navigate to ghosts; the notification row
-- itself stays visible for history.
UPDATE notifications
   SET related_kind = NULL, related_id = NULL
 WHERE related_kind = 'session'
   AND related_id IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM stream_sessions s WHERE s.id = related_id
   );

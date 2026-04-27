-- Stream sessions
CREATE TABLE IF NOT EXISTS stream_sessions (
    id                TEXT    PRIMARY KEY,
    file_id           TEXT    NOT NULL REFERENCES media_files(id),
    client_id         TEXT    NOT NULL REFERENCES clients(id),
    started_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at          TIMESTAMP,
    connection_type   TEXT    NOT NULL CHECK(connection_type IN ('lan','webrtc_p2p','turn_relay')),
    bytes_transferred INTEGER NOT NULL DEFAULT 0,
    progress_sec      REAL    NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_stream_sessions_client_id ON stream_sessions(client_id);
CREATE INDEX IF NOT EXISTS idx_stream_sessions_file_id   ON stream_sessions(file_id);
CREATE INDEX IF NOT EXISTS idx_stream_sessions_ended_at  ON stream_sessions(ended_at);

-- Append-only event log feeding the desktop Activity screen + Dashboard
-- "Recent activity" widget. Distinct from `notifications`: notifications are
-- user-actionable alerts; activity is the audit trail of everything the
-- server did. Producer services call `activity_service.record()` which
-- inserts a row here.
--
-- `payload` is an optional JSON blob for richer per-type detail (e.g.
-- stream connection_type, file size, scan file-count). UIs typically just
-- render `summary`; payload is for power-user views.

CREATE TABLE IF NOT EXISTS activity_events (
    id          TEXT PRIMARY KEY,            -- UUID
    type        TEXT NOT NULL,               -- e.g. stream.start, client.pair, file.upload
    actor_kind  TEXT,                        -- 'client' | 'system' | 'operator' | NULL
    actor_id    TEXT,                        -- e.g. client_id; NULL for system/operator events
    target_kind TEXT,                        -- 'session' | 'client' | 'file' | 'library' | NULL
    target_id   TEXT,                        -- entity id of the target
    summary     TEXT NOT NULL,               -- short human-readable line for the UI
    payload     TEXT,                        -- optional JSON for detail
    created_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_activity_created
    ON activity_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_activity_type_created
    ON activity_events(type, created_at DESC);

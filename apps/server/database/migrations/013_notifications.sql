-- In-app notifications surfaced by the desktop sidebar bell.
-- A notification is read when the user clicks it (read_at set). It is
-- dismissed when the user explicitly removes it (dismissed_at set).
-- Dismissed notifications stay in the table for audit; UI lists filter
-- them out via the partial-index ordering.

CREATE TABLE IF NOT EXISTS notifications (
    id           TEXT PRIMARY KEY,            -- UUID
    type         TEXT NOT NULL                -- info | warning | error | success
                 CHECK(type IN ('info','warning','error','success')),
    category     TEXT NOT NULL                -- system | client | license | transcode | storage
                 CHECK(category IN ('system','client','license','transcode','storage')),
    title        TEXT NOT NULL,
    message      TEXT NOT NULL,
    related_kind TEXT,                        -- e.g. 'client', 'order', 'session'
    related_id   TEXT,                        -- entity id
    created_at   TEXT NOT NULL,
    read_at      TEXT,                        -- NULL = unread
    dismissed_at TEXT                         -- NULL = visible
);

-- Optimised for the common UI queries:
--   WHERE dismissed_at IS NULL ORDER BY created_at DESC LIMIT 50
--   WHERE dismissed_at IS NULL AND read_at IS NULL  (unread count + list)
CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON notifications(read_at, dismissed_at, created_at DESC);

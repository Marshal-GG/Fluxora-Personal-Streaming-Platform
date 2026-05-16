-- Plan 27 M2 — widen the notifications.category CHECK constraint to
-- accept 'thumbnail' so the thumbnail worker can emit aggregated
-- failure notifications.
--
-- SQLite can't ALTER a CHECK constraint in place, so this rebuilds the
-- table via the standard rename + recreate + copy pattern.  Indexes
-- and existing rows are preserved.

ALTER TABLE notifications RENAME TO _notifications_old_037;

CREATE TABLE notifications (
    id           TEXT PRIMARY KEY,
    type         TEXT NOT NULL
                 CHECK(type IN ('info','warning','error','success')),
    category     TEXT NOT NULL
                 CHECK(category IN (
                     'system','client','license','transcode','storage','thumbnail'
                 )),
    title        TEXT NOT NULL,
    message      TEXT NOT NULL,
    related_kind TEXT,
    related_id   TEXT,
    created_at   TEXT NOT NULL,
    read_at      TEXT,
    dismissed_at TEXT
);

INSERT INTO notifications
    (id, type, category, title, message, related_kind, related_id,
     created_at, read_at, dismissed_at)
SELECT id, type, category, title, message, related_kind, related_id,
       created_at, read_at, dismissed_at
  FROM _notifications_old_037;

DROP TABLE _notifications_old_037;

CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON notifications(read_at, dismissed_at, created_at DESC);

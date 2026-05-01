-- Client groups: a way to bundle clients together and apply shared
-- restrictions (allowed libraries, bandwidth cap, time window, max rating).
-- A client can belong to multiple groups; the stream-gate combines the
-- restrictions across every group the client is in.

CREATE TABLE IF NOT EXISTS groups (
    id          TEXT PRIMARY KEY,            -- UUID
    name        TEXT NOT NULL,
    description TEXT,
    status      TEXT NOT NULL DEFAULT 'active'
                CHECK(status IN ('active','inactive')),
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS group_members (
    group_id  TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    added_at  TEXT NOT NULL,
    PRIMARY KEY (group_id, client_id)
);

CREATE TABLE IF NOT EXISTS group_restrictions (
    group_id           TEXT PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
    allowed_libraries  TEXT,        -- JSON array of library ids; NULL = all
    bandwidth_cap_mbps INTEGER,     -- NULL = unlimited
    time_window        TEXT,        -- JSON {start_h, end_h, days:[0..6]}; NULL = always
    max_rating         TEXT         -- e.g. "PG-13"; NULL = none
);

CREATE INDEX IF NOT EXISTS idx_group_members_client ON group_members(client_id);

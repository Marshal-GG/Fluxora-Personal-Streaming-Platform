-- Groups v2 — content-spaces redesign.  Plan in
-- `docs/10_planning/13_groups_v2_content_spaces.md`.
--
-- Flips the v1 Groups model from subtractive (groups REMOVE access from a
-- default-everything baseline) to additive (groups GRANT access from a
-- default-nothing baseline).  Adds:
--   * mandatory Public group every paired client auto-joins
--   * optional PIN-gate on groups with grant ledger + brute-force ledger
--   * group icons + colors for visual identity
--   * per-group concurrent stream cap (replaces v1's advisory-only field)
--   * per-member time_window override for "older kid stays up later" cases
--
-- Migration is idempotent — every ALTER + CREATE is guarded.  Fresh installs
-- and upgrades from v1 both land on the same shape.

-- ── 1.  New columns on groups ─────────────────────────────────────────────
-- SQLite ALTER TABLE ADD COLUMN doesn't support IF NOT EXISTS, but the
-- migration runner records this file's hash in `_migrations` so it never
-- runs twice.  Adding unconditionally is safe.

ALTER TABLE groups ADD COLUMN is_public INTEGER NOT NULL DEFAULT 0;
ALTER TABLE groups ADD COLUMN icon TEXT;
ALTER TABLE groups ADD COLUMN color TEXT;
ALTER TABLE groups ADD COLUMN requires_pin INTEGER NOT NULL DEFAULT 0;
ALTER TABLE groups ADD COLUMN pin_hash TEXT;
ALTER TABLE groups ADD COLUMN pin_mode TEXT NOT NULL DEFAULT 'session'
    CHECK(pin_mode IN ('session', 'per-entry'));
ALTER TABLE groups ADD COLUMN max_concurrent_streams INTEGER;

-- Exactly one row may be the public group.  Partial UNIQUE index enforces
-- the singleton at the schema level so a renegade INSERT can't double it up.
CREATE UNIQUE INDEX IF NOT EXISTS idx_groups_public
    ON groups(is_public) WHERE is_public = 1;

-- ── 2.  Per-member overrides ──────────────────────────────────────────────
-- NULL = use the group's `time_window`.  Non-null overrides per member.
-- Schema mirrors `group_restrictions.time_window` (JSON) for parser
-- compatibility — same shape, same _in_window logic.

ALTER TABLE group_members ADD COLUMN time_window_override TEXT;

-- ── 3.  PIN grant ledger ──────────────────────────────────────────────────
-- A client unlocking a PIN-gated group inserts a row.  Visibility resolution
-- checks `expires_at > now` to decide whether the gated group's libraries
-- are currently visible.  Pruned by the housekeeping task in main.py.

CREATE TABLE IF NOT EXISTS group_pin_grants (
    client_id   TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    group_id    TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    granted_at  TEXT NOT NULL,
    expires_at  TEXT NOT NULL,
    PRIMARY KEY (client_id, group_id)
);
CREATE INDEX IF NOT EXISTS idx_group_pin_grants_expiry
    ON group_pin_grants(expires_at);

-- ── 4.  PIN attempt ledger (brute-force protection) ───────────────────────
-- Every enter attempt (success or failure) lands here.  Rate limiter reads
-- recent rows for the (client, group) tuple.  Rows older than 24 h are
-- pruned by the housekeeping task.

CREATE TABLE IF NOT EXISTS group_pin_attempts (
    client_id    TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    group_id     TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    attempted_at TEXT NOT NULL,
    success      INTEGER NOT NULL CHECK(success IN (0, 1))
);
CREATE INDEX IF NOT EXISTS idx_group_pin_attempts_lookup
    ON group_pin_attempts(client_id, group_id, attempted_at DESC);

-- ── 5.  Manufacture the Public group on upgrade / fresh install ───────────
-- The Public group is mandatory.  v2's visibility resolution treats every
-- paired client as a member of Public; without this row, the desktop CP
-- can't render the group list and clients see nothing.
--
-- Design choice: we use the literal id 'public' (not a UUID) so the row is
-- discoverable by every other migration / startup hook.  The CHECK on
-- `groups.id` is a TEXT PRIMARY KEY — any value works; 'public' is the
-- documented convention.

INSERT OR IGNORE INTO groups
    (id, name, description, status, created_at, updated_at,
     is_public, icon, color)
VALUES
    ('public',
     'Public',
     'Default group every paired client joins automatically. '
     || 'Add libraries here to share them with everyone.',
     'active',
     CURRENT_TIMESTAMP,
     CURRENT_TIMESTAMP,
     1,
     'public',
     '#94A3B8');

-- group_restrictions.allowed_libraries semantic flips here:
--   v1: "client can ONLY stream from these libraries"      (subtractive)
--   v2: "this group EXPOSES these libraries to its members" (additive)
-- The JSON value is identical in both models — only interpretation changes.
-- Public's allowed_libraries is back-filled with EVERY existing library so
-- existing v1 deployments don't lose visibility on the upgrade (paired
-- clients in the v1 model could see anything via the no-restrictions
-- baseline; in v2 they need Public to grant the libraries explicitly).

INSERT OR IGNORE INTO group_restrictions
    (group_id, allowed_libraries, bandwidth_cap_mbps,
     time_window, max_rating)
SELECT
    'public',
    -- NULLIF handles two semantics in one expression:
    --   * libraries non-empty → store JSON array of every library id
    --     (Public exposes everything on upgrade, preserving v1 visibility).
    --   * libraries empty (fresh install) → store NULL.  Both v1 and v2
    --     interpret NULL identically: "no allowed_libraries restriction
    --     contributed by this group" — fresh install, paired client in
    --     only Public sees nothing until operator adds libraries.  Critical
    --     to write NULL here rather than '[]' because v1's intersect
    --     logic reads '[]' as "block everything", which would 403 every
    --     stream-start for clients only in Public.
    NULLIF(json_group_array(id), '[]'),
    NULL,
    NULL,
    NULL
FROM libraries;

-- ── 6.  Auto-add every existing approved client to Public ─────────────────
-- Without this back-fill, paired clients who relied on the v1 "no group =
-- full access" default would lose visibility entirely.  Adding them to
-- Public restores the previous baseline.

INSERT OR IGNORE INTO group_members
    (group_id, client_id, added_at)
SELECT
    'public',
    id,
    CURRENT_TIMESTAMP
FROM clients
WHERE status = 'approved';

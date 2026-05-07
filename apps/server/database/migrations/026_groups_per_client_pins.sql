-- Groups v2 — hybrid PIN model (per-client enrollment).  Plan in
-- `docs/10_planning/13_groups_v2_content_spaces.md` §M8.
--
-- Adds a per-group toggle that switches the PIN-gate from a single
-- household-shared secret to per-member device enrollment.  The shipped
-- M4 (migration 025) shared-PIN behavior remains the default; existing
-- gated groups stay shared-mode until the operator flips them.
--
-- Compromise blast radius: shared-PIN leak forces a household rotation;
-- per-client leak affects exactly one device.  Operator picks the
-- trade-off per group at create / edit time.
--
-- Migration is idempotent — guarded ALTER + CREATE.  Fresh installs and
-- upgrades from M4 both land on the same shape with `pin_model='shared'`
-- as the default.

-- ── 1.  Mode toggle on groups ─────────────────────────────────────────────
-- 'shared'     — `groups.pin_hash` is the household PIN (M4 behavior).
-- 'per-client' — `groups.pin_hash` is unused; each member's PIN lives
--                in `group_member_pins` keyed by (group_id, client_id).

ALTER TABLE groups ADD COLUMN pin_model TEXT NOT NULL DEFAULT 'shared'
    CHECK(pin_model IN ('shared', 'per-client'));

-- ── 2.  Per-member PIN ledger ─────────────────────────────────────────────
-- One row per (group, member device).  The member device chooses its own
-- PIN on first access; operator never sees the plaintext.  Recovery path
-- is `DELETE FROM group_member_pins WHERE group_id=? AND client_id=?` —
-- cleared row forces re-enrollment on the next access.

CREATE TABLE IF NOT EXISTS group_member_pins (
    group_id    TEXT NOT NULL REFERENCES groups(id)  ON DELETE CASCADE,
    client_id   TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    pin_hash    TEXT NOT NULL,
    enrolled_at TEXT NOT NULL,
    PRIMARY KEY (group_id, client_id)
);

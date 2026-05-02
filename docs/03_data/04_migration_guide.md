# Database Migration Guide

> **Category:** Data
> **Status:** Active
> **Last Updated:** 2026-05-01

How to add, test, and ship SQLite schema changes safely. Read first if you're touching `apps/server/database/`.

The current schema is documented in [`02_database_schema.md`](./02_database_schema.md); the migration runner lives in `apps/server/database/db.py`.

---

## The two rules that matter

1. **Migrations are append-only.** Never edit a migration that has been merged. If a previous migration was wrong, write a *new* migration that compensates for it.
2. **Migrations must be idempotent or use `IF NOT EXISTS`.** A failed startup that retries a migration must not corrupt state.

If you remember nothing else from this doc, remember those two.

---

## File layout

```
apps/server/database/
├── db.py                   # connection pool + migration runner
└── migrations/
    ├── 001_initial.sql
    ├── 002_sessions.sql
    ├── 003_client_status.sql
    ├── 004_tmdb_metadata.sql
    ├── 005_resume_progress.sql
    ├── 006_settings_license.sql
    ├── 007_align_tier_limits.sql
    ├── 008_polar_orders.sql
    ├── 009_order_customer_email.sql
    └── 010_transcoding_settings.sql
```

Files are picked up alphabetically by `_run_migrations()`. The `_migrations` table tracks which have already been applied — re-running the server only executes new files.

---

## Naming

Format: `NNN_short_snake_case_description.sql`

- `NNN` is zero-padded — currently three digits is enough through to migration 999.
- Description is action-oriented and gerund-free. `004_tmdb_metadata.sql` ✓, `004_adding_tmdb_metadata.sql` ✗, `004_tmdb.sql` ✗ (too vague).
- One concern per file. If a migration adds three unrelated columns, split it.

---

## Writing a new migration

### Adding a column to an existing table

```sql
-- 011_add_user_settings_telemetry.sql
ALTER TABLE user_settings
  ADD COLUMN telemetry_opt_in INTEGER NOT NULL DEFAULT 0;
```

Notes:
- SQLite's `ALTER TABLE ADD COLUMN` is fast (metadata only).
- New columns **must have a default** if `NOT NULL`, otherwise existing rows fail the constraint.
- For booleans: SQLite has no real `BOOLEAN` — use `INTEGER NOT NULL DEFAULT 0/1` and let Python coerce.

### Adding a new table

```sql
-- 012_add_audit_log.sql
CREATE TABLE IF NOT EXISTS audit_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    actor       TEXT NOT NULL,
    action      TEXT NOT NULL,
    target      TEXT,
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_log_occurred_at
  ON audit_log (occurred_at);
```

Always use `IF NOT EXISTS` on `CREATE TABLE` and `CREATE INDEX` so a partially-applied migration can re-run.

### Backfilling data

```sql
-- 013_backfill_default_server_name.sql
UPDATE user_settings
   SET server_name = 'Fluxora Server'
 WHERE server_name = '';
```

For large tables, split the UPDATE into batches in code rather than one big SQL statement that holds the write lock for minutes.

### Foreign keys

SQLite enforces FKs only when `PRAGMA foreign_keys=ON` is set per connection — `db.py` does this on every connection. If you add an FK constraint, make sure existing data won't violate it; if it might, write a backfill or cleanup *before* adding the constraint.

### Things SQLite cannot do directly

SQLite does not support:
- `ALTER TABLE ... DROP COLUMN` (only since 3.35; supported in our target — but think hard before dropping)
- `ALTER TABLE ... RENAME COLUMN` (since 3.25 — supported but cascades poorly to indexes/views)
- `ALTER TABLE ... ALTER COLUMN TYPE`

If you need any of those, the canonical pattern is:

```sql
-- 014_rename_user_settings_field.sql
BEGIN TRANSACTION;

CREATE TABLE user_settings_new (
    -- new schema goes here
);

INSERT INTO user_settings_new SELECT ... FROM user_settings;

DROP TABLE user_settings;
ALTER TABLE user_settings_new RENAME TO user_settings;

-- recreate indexes you dropped along with the old table

COMMIT;
```

This is heavy. Prefer adding the new column and deprecating the old one over time if you can.

---

## What if a previous migration was wrong?

You don't edit the old file. You write a new migration that fixes it.

Example: `migration 007_align_tier_limits.sql` corrected `max_concurrent_streams` because earlier migrations had set it wrong. The earlier migrations stayed unchanged on disk; 007 just patched the data forward.

If the wrong migration has *not yet been merged* — i.e. it's only in your branch — you can edit it freely. Once it's on `main`, it's frozen.

---

## Testing a new migration locally

### 1. Apply against a copy of your dev DB

```bash
cd apps/server
cp ~/.fluxora/fluxora.db /tmp/before.db
sqlite3 /tmp/before.db < database/migrations/011_add_user_settings_telemetry.sql
sqlite3 /tmp/before.db ".schema user_settings"   # confirm column added
```

### 2. Run the full migration runner from scratch

```bash
rm /tmp/test.db
FLUXORA_DB_PATH=/tmp/test.db python -c "
import asyncio
from database.db import init_db
from pathlib import Path
asyncio.run(init_db(Path('/tmp/test.db')))
"
sqlite3 /tmp/test.db "SELECT filename FROM _migrations;"
```

You should see all migration filenames listed in order, including the new one. If the runner stops early, the migration has a SQL error.

### 3. Add a test for the new schema

For tables: add an INSERT/SELECT round-trip in `tests/test_*` that exercises the new columns.

For settings/data changes: assert the row count or expected values in a fresh DB after `init_db` runs.

`apps/server/tests/conftest.py` already creates a fresh DB per test — just write a test that uses it.

### 4. Run the existing test suite

```bash
python -m pytest -q
```

The full server test suite (149 tests as of 2026-05-01) must still pass. If a previously-passing test breaks, your migration changed something the rest of the code relied on.

---

## Rollback?

There is no automated rollback. The migration runner is forward-only.

If a deployed migration is broken, the recovery sequence is:

1. **Don't roll back the DB** unless absolutely necessary — partial-state DBs are worse than wrong DBs.
2. Write a **compensating migration** that fixes whatever the broken one did.
3. Ship that compensating migration in a hotfix release.
4. Restore from backup ([`docs/05_infrastructure/05_backup_and_recovery.md`](../05_infrastructure/05_backup_and_recovery.md)) only if data corruption is severe.

This is why **idempotency matters** — if a migration partially applied, re-running it on the next startup must not double-apply changes.

---

## Updating the schema doc

After your migration merges, update [`docs/03_data/02_database_schema.md`](./02_database_schema.md):

1. Add a row to the "Applied Migrations" table.
2. Update the relevant `CREATE TABLE` block in the schema reference if columns/indexes changed.
3. Update the "Last Updated" frontmatter line.


---

## Quick checklist

Before opening a PR with a migration:

- [ ] Filename matches `NNN_snake_case.sql` and increments from the latest existing
- [ ] All `CREATE` statements use `IF NOT EXISTS`
- [ ] Any `NOT NULL` column has a `DEFAULT` if it's added to an existing table
- [ ] Tested against a fresh DB (steps 1–2 above)
- [ ] Tests added/updated for new schema
- [ ] `pytest` is green
- [ ] `02_database_schema.md` updated in the same PR
- [ ] No edit to any pre-existing migration file

# Database Migration Guide

> **Category:** Data
> **Status:** Active
> **Last Updated:** 2026-05-09 (current migration range 001-026; 025 + 026 added the Groups v2 content-spaces redesign + M8 hybrid PIN ledger.  Migration 025 is the most semantically-loaded migration shipped to date — it flips the meaning of `group_restrictions.allowed_libraries` from subtractive to additive without changing the wire format; landed pre-launch under the [`docs/04_api/02_versioning_policy.md`](../04_api/02_versioning_policy.md) "Pre-v1-launch breaking changes" exception.  Pattern note: `NULLIF(json_group_array(id), '[]')` to handle the empty-list case where v1 read `'[]'` as "block everything" — see [`gotchas.md`](../12_guidelines/03_gotchas.md).)

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
    ├── 010_transcoding_settings.sql
    ├── 011_groups.sql
    ├── 012_profile_fields.sql
    ├── 013_notifications.sql
    ├── 014_activity_events.sql
    ├── 015_extended_settings.sql
    ├── 016_media_quality_episodes_client_email.sql
    ├── 017_hwaccel_device.sql
    ├── 018_sanitize_encoder.sql
    ├── 019_sanitize_license_key.sql
    ├── 020_encoder_chain.sql
    ├── 021_session_encoder.sql
    ├── 022_remove_corrupt_media_paths.sql
    ├── 023_clients_last_ip.sql
    ├── 024_benchmark_history.sql
    ├── 025_groups_v2_content_spaces.sql
    ├── 026_groups_per_client_pins.sql
    ├── 027_transcode_jobs.sql
    └── 028_streaming_mode.sql
```

Files are picked up alphabetically by `_run_migrations()` (in `db.py`). The `_migrations` table tracks which have already been applied by filename — re-running the server only executes new files. Each migration is wrapped in `executescript()`, which executes the entire file inside a single implicit transaction; on the next startup the new filename is appended to `_migrations` after a successful `executescript` + commit.

`init_db()` also sets `PRAGMA journal_mode=WAL` and `PRAGMA foreign_keys=ON` on the open connection before running any migrations, so FK constraints are enforced for every migration that adds or follows them.

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

## Patterns introduced post-014

The early migrations (001–014) only ever added tables, columns, or indexes. From 015 onward several heavier patterns shipped — call these out so future agents recognise them.

### Sanitisation migrations (018, 019)

When a Pydantic `Literal` or validator is tightened on a column that already has free-form data in the wild, a stale row will 422 the next `PATCH` that touches the model. The fix is a one-shot `UPDATE` that resets out-of-set values to a safe default *or* `NULL`.

* `018_sanitize_encoder.sql` resets `transcoding_encoder` rows that aren't in the current 10-encoder registry to `libx264`.
* `019_sanitize_license_key.sql` nulls out license keys that don't match the current 5-segment `FLUXORA-…` shape, using pure SQL (`length - length(replace(…, '-', ''))`) since SQLite has no regex.

Always idempotent — a re-run finds no offending rows after the first pass.

### Data cleanup with FK ordering (022)

`022_remove_corrupt_media_paths.sql` deletes `media_files` rows whose `path` was corrupted by a prior buggy upload flow. Because `stream_sessions.file_id REFERENCES media_files(id)`, the dependent (already-ended) session rows must be deleted *before* the parent — otherwise the migration aborts the entire startup. Pattern: orphan the children first, then the parents, both `DELETE FROM` statements driven by the same `WHERE` predicate.

### Semantic flip without a wire-format change (025)

`025_groups_v2_content_spaces.sql` flipped `group_restrictions.allowed_libraries` from subtractive ("only these") to additive ("expose these"). The JSON value on disk is identical in both models — only the interpreter changed. This is the kind of migration most likely to silently break existing data because nothing in the schema looks different. Mitigations used in 025:

* **Empty-list normalisation:** `NULLIF(json_group_array(id), '[]')` — v1 read `'[]'` as "block everything"; v2 must store `NULL` for "no contribution from this group" so a fresh-install Public group with zero libraries doesn't 403 every stream-start. The legacy reading is documented in `docs/12_guidelines/03_gotchas.md`.
* **Singleton row manufacture:** `INSERT OR IGNORE INTO groups (id, …) VALUES ('public', …)` materialises the new mandatory Public group on both fresh installs and upgrades.
* **Member back-fill:** `INSERT OR IGNORE INTO group_members SELECT 'public', id, … FROM clients WHERE status='approved'` keeps every previously-paired client visible to themselves post-upgrade.
* **Singleton enforcement:** `CREATE UNIQUE INDEX … ON groups(is_public) WHERE is_public = 1` (a partial UNIQUE index) prevents a future bug from inserting a second Public row.

When a migration changes interpretation rather than shape, document the flip in [`docs/10_planning/02_decisions.md`](../10_planning/02_decisions.md) — ADR-018 covers this one — and write a `gotchas.md` entry so the next agent can find the trap by symptom.

### JSON blobs in TEXT columns (020, 024)

Two recent migrations chose to store structured data as a JSON blob in a `TEXT` column rather than splitting into a child table:

* `020_encoder_chain.sql` — `transcoding_chain TEXT DEFAULT NULL` holds a 1–4 element JSON array of encoder names; the chain is single-tenant, tiny, and never queried relationally.
* `024_benchmark_history.sql` — `benchmark_runs.results_json TEXT NOT NULL` holds the per-encoder benchmark result array; the operator only ever reads runs whole.

Use this pattern when:
1. You always read the blob alongside its parent row (no per-element queries needed).
2. The cardinality is bounded and small (a handful of entries, never thousands).
3. Order matters and you don't want a relational split + ORDER BY.

Do *not* use it when you'll later need to filter, join, or aggregate by the blob's contents — split into a child table from day one.

### Idempotent ALTER TABLE

SQLite's `ALTER TABLE ADD COLUMN` does not support `IF NOT EXISTS`. The migration runner's `_migrations` table records the filename of every successfully-applied script, so the script is never re-run on the same DB and the unconditional `ALTER` is safe. Migrations 025 and 026 add this contract explicitly in their headers — copy that pattern when you add columns to existing tables.

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

The full server test suite (734 tests as of 2026-05-09) must still pass. If a previously-passing test breaks, your migration changed something the rest of the code relied on.

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

Do this in the same PR as the migration. CI doesn't enforce it, but the doc-update protocol in CLAUDE.md does.

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

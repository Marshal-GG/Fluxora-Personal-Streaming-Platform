import logging
from pathlib import Path

import aiosqlite

logger = logging.getLogger(__name__)

_MIGRATIONS_DIR = Path(__file__).parent / "migrations"

_db: aiosqlite.Connection | None = None


async def init_db(db_path: Path) -> None:
    """Open the connection, enable WAL mode, and apply pending migrations."""
    global _db

    db_path.parent.mkdir(parents=True, exist_ok=True)

    _db = await aiosqlite.connect(db_path)
    _db.row_factory = aiosqlite.Row

    await _db.execute("PRAGMA journal_mode=WAL")
    await _db.execute("PRAGMA foreign_keys=ON")
    await _db.commit()

    await _run_migrations(_db)
    logger.info("Database ready at %s", db_path)


async def close_db() -> None:
    global _db
    if _db is not None:
        await _db.close()
        _db = None
        logger.info("Database connection closed")


async def get_db() -> aiosqlite.Connection:
    """Return the active connection. Raises if init_db() was not called."""
    if _db is None:
        raise RuntimeError("Database not initialised — call init_db() first")
    return _db


async def _run_migrations(db: aiosqlite.Connection) -> None:
    await db.execute(
        """
        CREATE TABLE IF NOT EXISTS _migrations (
            filename TEXT PRIMARY KEY,
            applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    await db.commit()

    applied: set[str] = set()
    async with db.execute("SELECT filename FROM _migrations") as cur:
        async for row in cur:
            applied.add(row["filename"])

    migration_files = sorted(_MIGRATIONS_DIR.glob("*.sql"))
    for path in migration_files:
        if path.name in applied:
            continue
        sql = path.read_text(encoding="utf-8")
        await db.executescript(sql)
        await db.execute("INSERT INTO _migrations (filename) VALUES (?)", (path.name,))
        await db.commit()
        logger.info("Applied migration: %s", path.name)

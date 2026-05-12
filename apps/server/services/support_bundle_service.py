"""Support-bundle generator for operator-side field debugging.

A support bundle is a single gzipped tar archive that captures the
state needed to triage a user-reported issue without back-and-forth.
The operator clicks a button on the desktop Help screen, the server
generates the archive, the desktop saves it via the OS file picker,
the operator attaches it to a GitHub issue / email.

Contents are deliberately conservative: anything that could leak a
credential is either omitted or replaced with a sentinel string. Bundle
contents are not encrypted at rest in the archive — the redaction step
is the privacy boundary.

Authorisation lives at the router seam (`require_local_caller`); this
service trusts its caller to be the operator and never exposes a
build path callable from the public tunnel.
"""

from __future__ import annotations

import gzip
import io
import json
import logging
import platform
import sys
import tarfile
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import aiosqlite

from config import settings
from services import system_stats_service, transcoding_service

logger = logging.getLogger(__name__)


_REDACTED = "***REDACTED***"

# Field names in `user_settings` whose values are credentials / contact.
# Their presence (non-null) is preserved as the sentinel string so an
# operator reading the bundle can tell "this was set" without seeing the
# value. Null values stay null so "this was never configured" is also
# distinguishable.
_REDACT_FIELDS = frozenset(
    {
        "tmdb_api_key",
        "license_key",
        "email",
    }
)


def _redact_value(field: str, value: Any) -> Any:
    if field in _REDACT_FIELDS and value is not None:
        return _REDACTED
    return value


def _bundle_filename(generated_at: datetime) -> str:
    stamp = generated_at.strftime("%Y%m%d_%H%M%S")
    return f"fluxora-support-{stamp}.tar.gz"


def _add_text_member(
    tar: tarfile.TarFile, name: str, content: str, mtime: float
) -> None:
    """Write `content` as a UTF-8 text file inside the archive."""
    data = content.encode("utf-8")
    info = tarfile.TarInfo(name=name)
    info.size = len(data)
    info.mtime = int(mtime)
    info.mode = 0o644
    tar.addfile(info, io.BytesIO(data))


async def _collect_metadata() -> dict[str, Any]:
    """Identity + environment fingerprint for the bundle."""
    return {
        "generated_at": datetime.now(UTC).isoformat(),
        "server_version": "0.1.0",
        "python_version": sys.version.split(" ", maxsplit=1)[0],
        "platform": platform.platform(),
        "platform_machine": platform.machine(),
        "data_dir": str(Path(settings.fluxora_log_path).parent),
    }


async def _collect_settings(db: aiosqlite.Connection) -> dict[str, Any]:
    """Dump user_settings row (singleton id=1) with secret fields redacted."""
    db.row_factory = aiosqlite.Row
    async with db.execute("SELECT * FROM user_settings WHERE id = 1") as cur:
        row = await cur.fetchone()
    if row is None:
        return {}
    return {key: _redact_value(key, row[key]) for key in row.keys()}


async def _collect_schema(db: aiosqlite.Connection) -> str:
    """SQLite DDL for every table / index — never the row data."""
    db.row_factory = aiosqlite.Row
    async with db.execute(
        "SELECT sql FROM sqlite_master "
        " WHERE sql IS NOT NULL "
        "   AND name NOT LIKE 'sqlite_%' "
        " ORDER BY type DESC, name"
    ) as cur:
        rows = await cur.fetchall()
    return "\n\n".join(f"{row['sql']};" for row in rows if row["sql"])


def _collect_log_files() -> list[tuple[str, bytes]]:
    """Read the active log + any rotated siblings into memory.

    `RotatingFileHandler` keeps `<name>`, `<name>.1`, `<name>.2`, ...
    Returns at most 5 files (current + 4 rotated) to bound memory.
    Each file is read raw — no truncation; the rotation already caps
    individual files at ~10 MB.
    """
    base = Path(settings.fluxora_log_path)
    out: list[tuple[str, bytes]] = []
    if base.exists():
        out.append((base.name, base.read_bytes()))
    for i in range(1, 5):
        rotated = base.with_name(f"{base.name}.{i}")
        if rotated.exists():
            out.append((rotated.name, rotated.read_bytes()))
    return out


async def _collect_encoders() -> dict[str, Any]:
    """Snapshot of encoder probe + advisor state."""
    try:
        results = transcoding_service.get_test_results()
    except Exception:
        logger.warning("Failed to read encoder test results", exc_info=True)
        results = {}
    return {
        "tested": {
            enc: {
                "passed": result.passed,
                "error": result.error,
                "tested_at": result.tested_at.isoformat() if result.tested_at else None,
                "suggestion": result.suggestion,
            }
            for enc, result in results.items()
        },
    }


async def generate_support_bundle(db: aiosqlite.Connection) -> tuple[str, bytes]:
    """Build the bundle in memory and return `(filename, gzipped_tar_bytes)`.

    Caller handles delivery (router returns it as a `Response`). On any
    sub-collector failure the bundle still ships — we'd rather give the
    operator a partial bundle with a noted gap than fail the whole
    download path.
    """
    generated_at = datetime.now(UTC)
    mtime = generated_at.timestamp()

    metadata = await _collect_metadata()

    try:
        stats = await system_stats_service.system_stats.collect(db)
    except Exception as exc:
        logger.warning("system_stats collect failed: %r", exc)
        stats = {"_collect_error": repr(exc)}

    try:
        settings_blob = await _collect_settings(db)
    except Exception as exc:
        logger.warning("settings collect failed: %r", exc)
        settings_blob = {"_collect_error": repr(exc)}

    try:
        schema = await _collect_schema(db)
    except Exception as exc:
        logger.warning("schema collect failed: %r", exc)
        schema = f"-- collect failed: {exc!r}"

    try:
        encoders = await _collect_encoders()
    except Exception as exc:
        logger.warning("encoders collect failed: %r", exc)
        encoders = {"_collect_error": repr(exc)}

    try:
        log_files = _collect_log_files()
    except Exception as exc:
        logger.warning("log file read failed: %r", exc)
        log_files = []

    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb", mtime=int(mtime)) as gz:
        with tarfile.open(fileobj=gz, mode="w") as tar:
            _add_text_member(
                tar, "metadata.json", json.dumps(metadata, indent=2), mtime
            )
            _add_text_member(
                tar,
                "system/stats.json",
                json.dumps(stats, indent=2, default=str),
                mtime,
            )
            _add_text_member(
                tar,
                "system/encoders.json",
                json.dumps(encoders, indent=2, default=str),
                mtime,
            )
            _add_text_member(
                tar,
                "settings/redacted.json",
                json.dumps(settings_blob, indent=2, default=str),
                mtime,
            )
            _add_text_member(tar, "database/schema.sql", schema, mtime)

            for name, data in log_files:
                info = tarfile.TarInfo(name=f"logs/{name}")
                info.size = len(data)
                info.mtime = int(mtime)
                info.mode = 0o644
                tar.addfile(info, io.BytesIO(data))

    payload = buf.getvalue()
    logger.info(
        "Support bundle generated: %d bytes, %d log files",
        len(payload),
        len(log_files),
    )
    return _bundle_filename(generated_at), payload

"""Structured log reading + WS pub/sub for the desktop Logs screen.

The file handler in main.py writes JSON-lines to the rotating log file
(`fluxora.log`, `fluxora.log.1`, ...). This service reads those files and
exposes them as filterable structured records.

Schema mapping (python-json-logger field → API field):
- asctime   → ts        (ISO-formatted; logger emits "2026-05-01 12:34:56,789")
- levelname → level     (INFO|WARNING|ERROR|... → info|warn|error|...)
- name      → source    (e.g. "fluxora.stream", "uvicorn.access")
- message   → message

For the WS live tail we attach a custom logging.Handler at startup
that broadcasts each emitted record to subscribed asyncio queues.
Subscribe pattern matches notification_service.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from collections.abc import Iterator
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


# ── pub/sub for live tail ──────────────────────────────────────────────────

_subscribers: set[asyncio.Queue[dict[str, Any]]] = set()
_QUEUE_MAX = 200


def subscribe() -> asyncio.Queue[dict[str, Any]]:
    q: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=_QUEUE_MAX)
    _subscribers.add(q)
    return q


def unsubscribe(q: asyncio.Queue[dict[str, Any]]) -> None:
    _subscribers.discard(q)


def broadcast(payload: dict[str, Any]) -> None:
    for q in list(_subscribers):
        try:
            q.put_nowait(payload)
        except asyncio.QueueFull:
            # Live-tail consumers can drop frames silently; if you missed
            # something it's still in the file.
            pass


class BroadcastHandler(logging.Handler):
    """Logging handler that fans every record out to WS subscribers.

    Installed once at app startup. Producer-side errors (e.g. event-loop
    not running yet) are swallowed — log emission must never fail the
    underlying flow.
    """

    def emit(self, record: logging.LogRecord) -> None:
        try:
            ts = (
                datetime.fromtimestamp(record.created, tz=UTC)
                .isoformat()
                .replace("+00:00", "Z")
            )
            payload = {
                "ts": ts,
                "level": _normalize_level(record.levelname),
                "source": record.name,
                "message": record.getMessage(),
            }
            broadcast({"type": "log", "data": payload})
        except Exception:
            pass


# ── schema helpers ─────────────────────────────────────────────────────────


_LEVEL_MAP = {
    "DEBUG": "debug",
    "INFO": "info",
    "WARNING": "warn",
    "WARN": "warn",
    "ERROR": "error",
    "CRITICAL": "error",
}


def _normalize_level(raw: str) -> str:
    return _LEVEL_MAP.get(raw.upper(), raw.lower())


# python-json-logger emits "2026-05-01 12:34:56,789" — convert to ISO-ish
_TS_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})[,.](\d+)$")


def _to_iso(ts: str) -> str:
    """Best-effort ISO-format conversion. If the input doesn't match the
    expected logger format, return it unchanged.
    """
    m = _TS_RE.match(ts)
    if not m:
        return ts
    y, mo, d, h, mi, s, ms = m.groups()
    return f"{y}-{mo}-{d}T{h}:{mi}:{s}.{ms}Z"


def parse_line(line: str) -> dict[str, Any] | None:
    """Parse one JSON-line into the API schema, or return None if junk."""
    line = line.strip()
    if not line:
        return None
    try:
        obj = json.loads(line)
    except (ValueError, TypeError):
        return None
    if not isinstance(obj, dict):
        return None
    raw_ts = obj.get("asctime") or ""
    return {
        "ts": _to_iso(raw_ts) if raw_ts else "",
        "level": _normalize_level(obj.get("levelname", "INFO")),
        "source": obj.get("name", ""),
        "message": obj.get("message", ""),
    }


# ── file iteration ─────────────────────────────────────────────────────────


def _iter_log_files(base: Path) -> Iterator[Path]:
    """Yield rotating-log files in oldest → newest order.

    RotatingFileHandler keeps `<name>`, `<name>.1`, `<name>.2`, ...
    The lowest-numbered file is the most recent; `<name>` (no suffix) is
    the live one. We yield oldest → newest so a chronological pass reads
    in the right order.
    """
    backups: list[tuple[int, Path]] = []
    for p in base.parent.glob(f"{base.name}*"):
        if p.name == base.name:
            continue
        suffix = p.name[len(base.name) + 1 :]  # strip "<name>." prefix
        try:
            backups.append((int(suffix), p))
        except ValueError:
            continue
    backups.sort(key=lambda t: -t[0])  # higher index = older
    for _, p in backups:
        yield p
    if base.exists():
        yield base


def _read_records(base: Path, max_lines: int) -> list[dict[str, Any]]:
    """Most-recent-last ordering. Cap at `max_lines` to bound memory."""
    records: list[dict[str, Any]] = []
    for path in _iter_log_files(base):
        try:
            with path.open(encoding="utf-8", errors="replace") as f:
                for raw in f:
                    rec = parse_line(raw)
                    if rec is not None:
                        records.append(rec)
        except OSError as exc:
            logger.warning("Failed to read log file %s: %s", path, exc)
            continue
    # Cap from the most-recent end
    if len(records) > max_lines:
        records = records[-max_lines:]
    return records


# ── public API ─────────────────────────────────────────────────────────────


_HARD_CAP = 5000


def list_logs(
    log_path: Path,
    *,
    levels: list[str] | None = None,
    source: str | None = None,
    since: str | None = None,
    until: str | None = None,
    q: str | None = None,
    limit: int = 200,
    cursor: int = 0,
) -> dict[str, Any]:
    """Filter + paginate the structured log records.

    Cursor is an integer offset into the most-recent-first filtered list.
    The next page is `cursor + limit`. Returns `next_cursor=null` when
    there are no more rows.
    """
    all_records = _read_records(log_path, _HARD_CAP)

    # Most recent first for the API
    all_records.reverse()

    level_set = {lvl.lower() for lvl in (levels or [])}

    def matches(rec: dict[str, Any]) -> bool:
        if level_set and rec["level"] not in level_set:
            return False
        if source and not rec["source"].startswith(source):
            return False
        if since and rec["ts"] and rec["ts"] < since:
            return False
        if until and rec["ts"] and rec["ts"] >= until:
            return False
        if q and q.lower() not in rec["message"].lower():
            return False
        return True

    filtered = [r for r in all_records if matches(r)]

    start = max(0, cursor)
    end = start + limit
    page = filtered[start:end]
    next_cursor = end if end < len(filtered) else None

    return {"items": page, "next_cursor": next_cursor}

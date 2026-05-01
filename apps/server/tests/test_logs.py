"""Tests for /api/v1/logs and log_service parsing."""

from __future__ import annotations

import asyncio
import json
import logging
from pathlib import Path

import pytest
from httpx import ASGITransport, AsyncClient

from main import app
from services import log_service

# ── service-level: parsing & filtering ────────────────────────────────────


def _write_log_lines(path: Path, lines: list[dict]) -> None:
    """Write JSON-lines (one record per line) like python-json-logger emits."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for rec in lines:
            f.write(json.dumps(rec) + "\n")


def test_parse_line_ok():
    line = json.dumps(
        {
            "asctime": "2026-05-01 12:34:56,789",
            "levelname": "INFO",
            "name": "fluxora.stream",
            "message": "Stream started",
        }
    )
    rec = log_service.parse_line(line)
    assert rec is not None
    assert rec["ts"] == "2026-05-01T12:34:56.789Z"
    assert rec["level"] == "info"
    assert rec["source"] == "fluxora.stream"
    assert rec["message"] == "Stream started"


def test_parse_line_warning_normalises_to_warn():
    line = json.dumps(
        {
            "asctime": "2026-05-01 12:34:56,789",
            "levelname": "WARNING",
            "name": "x",
            "message": "y",
        }
    )
    rec = log_service.parse_line(line)
    assert rec is not None
    assert rec["level"] == "warn"


def test_parse_line_garbage_returns_none():
    assert log_service.parse_line("not json") is None
    assert log_service.parse_line("") is None
    assert log_service.parse_line(json.dumps([1, 2, 3])) is None  # not a dict


def test_list_logs_filters_by_level(tmp_path):
    log_path = tmp_path / "fluxora.log"
    _write_log_lines(
        log_path,
        [
            {
                "asctime": "2026-05-01 12:34:56,001",
                "levelname": "INFO",
                "name": "x",
                "message": "a",
            },
            {
                "asctime": "2026-05-01 12:34:56,002",
                "levelname": "ERROR",
                "name": "x",
                "message": "boom",
            },
            {
                "asctime": "2026-05-01 12:34:56,003",
                "levelname": "WARNING",
                "name": "x",
                "message": "warn",
            },
        ],
    )
    out = log_service.list_logs(log_path, levels=["error", "warn"])
    assert len(out["items"]) == 2
    assert {it["level"] for it in out["items"]} == {"error", "warn"}


def test_list_logs_source_prefix(tmp_path):
    log_path = tmp_path / "fluxora.log"
    _write_log_lines(
        log_path,
        [
            {
                "asctime": "2026-05-01 12:00:00,001",
                "levelname": "INFO",
                "name": "fluxora.stream",
                "message": "a",
            },
            {
                "asctime": "2026-05-01 12:00:00,002",
                "levelname": "INFO",
                "name": "fluxora.auth",
                "message": "b",
            },
            {
                "asctime": "2026-05-01 12:00:00,003",
                "levelname": "INFO",
                "name": "uvicorn.access",
                "message": "c",
            },
        ],
    )
    out = log_service.list_logs(log_path, source="fluxora.")
    sources = {it["source"] for it in out["items"]}
    assert sources == {"fluxora.stream", "fluxora.auth"}


def test_list_logs_q_filter_case_insensitive(tmp_path):
    log_path = tmp_path / "fluxora.log"
    _write_log_lines(
        log_path,
        [
            {
                "asctime": "2026-05-01 12:00:00,001",
                "levelname": "INFO",
                "name": "x",
                "message": "Stream started OK",
            },
            {
                "asctime": "2026-05-01 12:00:00,002",
                "levelname": "INFO",
                "name": "x",
                "message": "FFmpeg busy",
            },
        ],
    )
    out = log_service.list_logs(log_path, q="stream")
    assert len(out["items"]) == 1
    assert "Stream" in out["items"][0]["message"]


def test_list_logs_pagination(tmp_path):
    log_path = tmp_path / "fluxora.log"
    _write_log_lines(
        log_path,
        [
            {
                "asctime": f"2026-05-01 12:00:00,{i:03d}",
                "levelname": "INFO",
                "name": "x",
                "message": f"event-{i}",
            }
            for i in range(5)
        ],
    )
    page1 = log_service.list_logs(log_path, limit=2, cursor=0)
    page2 = log_service.list_logs(log_path, limit=2, cursor=page1["next_cursor"])
    page3 = log_service.list_logs(log_path, limit=2, cursor=page2["next_cursor"])

    assert len(page1["items"]) == 2
    assert len(page2["items"]) == 2
    assert len(page3["items"]) == 1
    # Most-recent first → first page is event-4, event-3
    assert page1["items"][0]["message"] == "event-4"
    assert page3["next_cursor"] is None


def test_list_logs_skips_garbage_lines(tmp_path):
    log_path = tmp_path / "fluxora.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8") as f:
        f.write(
            json.dumps(
                {
                    "asctime": "2026-05-01 12:00:00,001",
                    "levelname": "INFO",
                    "name": "x",
                    "message": "ok",
                }
            )
            + "\n"
        )
        f.write("garbage line\n")
        f.write("\n")
        f.write(
            json.dumps(
                {
                    "asctime": "2026-05-01 12:00:00,002",
                    "levelname": "INFO",
                    "name": "x",
                    "message": "ok2",
                }
            )
            + "\n"
        )
    out = log_service.list_logs(log_path)
    assert len(out["items"]) == 2


def test_list_logs_reads_rotated_files(tmp_path):
    """`fluxora.log.1` (older) + `fluxora.log` (newer) → both included,
    newest-first ordering preserved."""
    base = tmp_path / "fluxora.log"
    older = tmp_path / "fluxora.log.1"
    _write_log_lines(
        older,
        [
            {
                "asctime": "2026-05-01 11:00:00,000",
                "levelname": "INFO",
                "name": "x",
                "message": "old",
            }
        ],
    )
    _write_log_lines(
        base,
        [
            {
                "asctime": "2026-05-01 12:00:00,000",
                "levelname": "INFO",
                "name": "x",
                "message": "new",
            }
        ],
    )
    out = log_service.list_logs(base)
    assert [it["message"] for it in out["items"]] == ["new", "old"]


# ── pub/sub ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_subscribe_broadcast_unsubscribe():
    q = log_service.subscribe()
    try:
        log_service.broadcast({"type": "log", "data": {"message": "hi"}})
        frame = await asyncio.wait_for(q.get(), timeout=1.0)
        assert frame["data"]["message"] == "hi"
    finally:
        log_service.unsubscribe(q)
    log_service.broadcast({"type": "log", "data": {"message": "post"}})
    assert q.empty()


@pytest.mark.asyncio
async def test_broadcast_handler_emits_frames():
    """A logging.LogRecord routed through the handler reaches subscribers."""
    handler = log_service.BroadcastHandler()
    handler.setLevel(logging.INFO)
    test_logger = logging.getLogger("fluxora.test_broadcast")
    test_logger.setLevel(logging.INFO)
    test_logger.addHandler(handler)
    q = log_service.subscribe()
    try:
        test_logger.info("hello world")
        frame = await asyncio.wait_for(q.get(), timeout=1.0)
        assert frame["type"] == "log"
        assert frame["data"]["message"] == "hello world"
        assert frame["data"]["level"] == "info"
        assert frame["data"]["source"] == "fluxora.test_broadcast"
    finally:
        log_service.unsubscribe(q)
        test_logger.removeHandler(handler)


# ── REST endpoint ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_endpoint_returns_records(client: AsyncClient, tmp_path, monkeypatch):
    log_path = tmp_path / "fluxora.log"
    _write_log_lines(
        log_path,
        [
            {
                "asctime": "2026-05-01 12:34:56,000",
                "levelname": "INFO",
                "name": "fluxora.x",
                "message": "first",
            },
            {
                "asctime": "2026-05-01 12:34:57,000",
                "levelname": "ERROR",
                "name": "fluxora.x",
                "message": "second",
            },
        ],
    )
    monkeypatch.setattr("routers.logs.settings.fluxora_log_path", str(log_path))
    resp = await client.get("/api/v1/logs?level=error")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["items"]) == 1
    assert body["items"][0]["message"] == "second"


@pytest.mark.asyncio
async def test_endpoint_limit_and_cursor(client: AsyncClient, tmp_path, monkeypatch):
    log_path = tmp_path / "fluxora.log"
    _write_log_lines(
        log_path,
        [
            {
                "asctime": f"2026-05-01 12:00:00,{i:03d}",
                "levelname": "INFO",
                "name": "x",
                "message": f"e-{i}",
            }
            for i in range(5)
        ],
    )
    monkeypatch.setattr("routers.logs.settings.fluxora_log_path", str(log_path))
    resp = await client.get("/api/v1/logs?limit=2")
    body = resp.json()
    assert len(body["items"]) == 2
    assert body["next_cursor"] == 2
    resp2 = await client.get(f"/api/v1/logs?limit=2&cursor={body['next_cursor']}")
    body2 = resp2.json()
    assert len(body2["items"]) == 2
    assert body2["next_cursor"] == 4


@pytest.mark.asyncio
async def test_endpoint_requires_localhost(test_db):
    async with AsyncClient(
        transport=ASGITransport(app=app, client=("203.0.113.7", 50000)),
        base_url="http://test",
    ) as remote:
        resp = await remote.get(
            "/api/v1/logs",
            headers={"CF-Connecting-IP": "203.0.113.7"},
        )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_endpoint_limit_validation(client: AsyncClient):
    resp = await client.get("/api/v1/logs?limit=2000")
    assert resp.status_code == 422
    resp = await client.get("/api/v1/logs?limit=0")
    assert resp.status_code == 422

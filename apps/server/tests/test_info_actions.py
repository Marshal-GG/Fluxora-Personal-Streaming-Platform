"""Tests for POST /api/v1/info/restart and /api/v1/info/stop."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

from fastapi import HTTPException, status

from main import app
from routers.deps import require_local_caller


def _reject_localhost():
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="This endpoint is only accessible from localhost",
    )


async def _restart(client):
    return await client.post("/api/v1/info/restart")


async def _stop(client):
    return await client.post("/api/v1/info/stop")


async def test_restart_localhost_returns_202(client, test_db):
    app.dependency_overrides[require_local_caller] = lambda: None
    try:
        with patch(
            "routers.info._trigger_shutdown", new_callable=AsyncMock
        ) as mock_shutdown:
            resp = await _restart(client)
            assert resp.status_code == 202
            assert resp.json() == {"status": "restart_requested"}
            # The endpoint schedules the task; give the loop one tick.
            import asyncio

            await asyncio.sleep(0)
            mock_shutdown.assert_called_once()
            assert mock_shutdown.call_args.kwargs == {"restart": True}
    finally:
        app.dependency_overrides.pop(require_local_caller, None)


async def test_stop_localhost_returns_202(client, test_db):
    app.dependency_overrides[require_local_caller] = lambda: None
    try:
        with patch(
            "routers.info._trigger_shutdown", new_callable=AsyncMock
        ) as mock_shutdown:
            resp = await _stop(client)
            assert resp.status_code == 202
            assert resp.json() == {"status": "shutdown_requested"}
            import asyncio

            await asyncio.sleep(0)
            mock_shutdown.assert_called_once()
            assert mock_shutdown.call_args.kwargs == {"restart": False}
    finally:
        app.dependency_overrides.pop(require_local_caller, None)


async def test_restart_non_localhost_forbidden(client, test_db):
    """When require_local_caller rejects (non-localhost), 403 is returned and
    the shutdown task is never scheduled."""
    app.dependency_overrides[require_local_caller] = _reject_localhost
    try:
        with patch(
            "routers.info._trigger_shutdown", new_callable=AsyncMock
        ) as mock_shutdown:
            resp = await _restart(client)
            assert resp.status_code == 403
            mock_shutdown.assert_not_called()
    finally:
        app.dependency_overrides.pop(require_local_caller, None)


async def test_stop_non_localhost_forbidden(client, test_db):
    app.dependency_overrides[require_local_caller] = _reject_localhost
    try:
        with patch(
            "routers.info._trigger_shutdown", new_callable=AsyncMock
        ) as mock_shutdown:
            resp = await _stop(client)
            assert resp.status_code == 403
            mock_shutdown.assert_not_called()
    finally:
        app.dependency_overrides.pop(require_local_caller, None)

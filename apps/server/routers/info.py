import asyncio
import logging
import os
import signal

import aiosqlite
from fastapi import APIRouter, Depends, status

from config import settings
from database.db import get_db
from models.settings import ServerInfoResponse, SystemStatsResponse
from routers.deps import require_local_caller
from services.system_stats_service import system_stats

logger = logging.getLogger(__name__)

router = APIRouter()

SERVER_VERSION = "0.1.0"

# Delay before sending SIGINT so the HTTP response is flushed first.
_SHUTDOWN_DELAY_SEC = 0.3


async def _trigger_shutdown(*, restart: bool) -> None:
    """Wait briefly so the response is sent, then signal the process.

    Restart vs stop differs only in the log line — actual auto-restart
    requires a process supervisor (systemd, NSSM, Windows Service) to
    relaunch on exit. Both code paths exit cleanly via SIGINT so uvicorn's
    shutdown handler can run the lifespan teardown.
    """
    await asyncio.sleep(_SHUTDOWN_DELAY_SEC)
    action = "restart" if restart else "shutdown"
    logger.warning("Server %s requested via API — exiting", action)
    os.kill(os.getpid(), signal.SIGINT)


@router.get("/healthz", include_in_schema=False)
async def healthz() -> dict[str, bool]:
    """Lightweight liveness probe.

    No DB hit, no auth, constant body. Used by Cloudflare Tunnel ingress
    health checks and by clients deciding whether the public URL is
    reachable. Anything heavier belongs in /info or /info/stats.
    """
    return {"ok": True}


@router.get("/info", response_model=ServerInfoResponse)
async def get_info(db: aiosqlite.Connection = Depends(get_db)) -> ServerInfoResponse:
    remote_url = settings.fluxora_public_url or None

    async with db.execute(
        "SELECT server_name, subscription_tier FROM user_settings WHERE id = 1"
    ) as cur:
        row = await cur.fetchone()

    if row is None:
        return ServerInfoResponse(
            server_name="Fluxora Server",
            version=SERVER_VERSION,
            tier="free",
            remote_url=remote_url,
        )

    return ServerInfoResponse(
        server_name=row["server_name"],
        version=SERVER_VERSION,
        tier=row["subscription_tier"],
        remote_url=remote_url,
    )


@router.get("/info/stats", response_model=SystemStatsResponse)
async def get_stats(
    db: aiosqlite.Connection = Depends(get_db),
) -> SystemStatsResponse:
    """Live server stats — sidebar System Status, status bar, sparklines.

    First call returns 0.0 for both `network_*_mbps` because no baseline
    delta exists yet; subsequent calls return the rate since the previous
    call.
    """
    payload = await system_stats.collect(db)
    return SystemStatsResponse(**payload)


@router.post("/info/restart", status_code=status.HTTP_202_ACCEPTED)
async def restart_server(
    _: None = Depends(require_local_caller),
) -> dict[str, str]:
    """Schedule a graceful server restart. Localhost-only.

    Returns immediately; the actual SIGINT is sent ~300ms later so the
    response can flush. Auto-relaunch requires a process supervisor.
    """
    asyncio.create_task(_trigger_shutdown(restart=True))
    return {"status": "restart_requested"}


@router.post("/info/stop", status_code=status.HTTP_202_ACCEPTED)
async def stop_server(
    _: None = Depends(require_local_caller),
) -> dict[str, str]:
    """Schedule a graceful server shutdown. Localhost-only."""
    asyncio.create_task(_trigger_shutdown(restart=False))
    return {"status": "shutdown_requested"}

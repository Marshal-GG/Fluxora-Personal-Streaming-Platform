import logging
from pathlib import Path

import aiosqlite
from fastapi import APIRouter, Depends

from database.db import get_db
from models.settings import ServerInfoResponse

logger = logging.getLogger(__name__)

router = APIRouter()

SERVER_VERSION = "0.1.0"


@router.get("/info", response_model=ServerInfoResponse)
async def get_info(db: aiosqlite.Connection = Depends(get_db)) -> ServerInfoResponse:
    async with db.execute(
        "SELECT server_name, subscription_tier FROM user_settings WHERE id = 1"
    ) as cur:
        row = await cur.fetchone()

    if row is None:
        return ServerInfoResponse(
            server_name="Fluxora Server",
            version=SERVER_VERSION,
            tier="free",
        )

    return ServerInfoResponse(
        server_name=row["server_name"],
        version=SERVER_VERSION,
        tier=row["subscription_tier"],
    )


@router.get("/info/logs")
async def get_logs() -> dict[str, str]:
    from config import settings

    log_path = Path(settings.fluxora_log_path)
    if not log_path.exists():
        return {"logs": ""}

    # Read last 1000 lines
    try:
        with open(log_path, encoding="utf-8") as f:
            lines = f.readlines()
            last_lines = lines[-1000:]
            return {"logs": "".join(last_lines)}
    except Exception as e:
        logger.error("Failed to read logs: %s", e)
        return {"logs": f"Error reading logs: {e}"}

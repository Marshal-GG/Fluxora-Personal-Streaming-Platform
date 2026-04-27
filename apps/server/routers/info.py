import logging

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

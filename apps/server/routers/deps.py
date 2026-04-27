import logging

import aiosqlite
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import settings
from database.db import get_db
from services.auth_service import get_trusted_client_by_token

logger = logging.getLogger(__name__)

_bearer = HTTPBearer()


async def validate_token(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: aiosqlite.Connection = Depends(get_db),
) -> aiosqlite.Row:
    client = await get_trusted_client_by_token(
        db, credentials.credentials, settings.token_hmac_key
    )
    if client is None:
        logger.warning("Invalid or revoked token presented")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or revoked token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return client

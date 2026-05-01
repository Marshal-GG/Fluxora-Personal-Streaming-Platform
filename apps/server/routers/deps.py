import logging

import aiosqlite
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import settings
from database.db import get_db
from services.auth_service import get_trusted_client_by_token

logger = logging.getLogger(__name__)

bearer = HTTPBearer(auto_error=False)

LOOPBACK = frozenset({"127.0.0.1", "::1", "localhost"})


async def require_local_caller(request: Request) -> None:
    """Allow only requests originating from the local machine.

    Tunneled requests appear local at the FastAPI layer because cloudflared
    forwards via 127.0.0.1, so we additionally reject anything carrying
    `CF-Connecting-IP` — that header is only set on requests that traversed
    the public Cloudflare edge.
    """
    if request.headers.get("CF-Connecting-IP"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is not accessible over the public tunnel",
        )
    host = request.client.host if request.client else "127.0.0.1"
    if host not in LOOPBACK:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is only accessible from localhost",
        )


async def validate_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: aiosqlite.Connection = Depends(get_db),
) -> aiosqlite.Row:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    client = await get_trusted_client_by_token(
        db, credentials.credentials, settings.token_hmac_key
    )
    if client is None:
        logger.info("Authentication failed: Invalid or revoked token presented")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or revoked token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return client


async def validate_token_or_local(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: aiosqlite.Connection = Depends(get_db),
) -> aiosqlite.Row | None:
    """Allow request if it originates from localhost OR has a valid token.

    Tunneled requests carry `CF-Connecting-IP`. Even though they appear local
    at the FastAPI layer (cloudflared forwards via loopback), they're not the
    desktop control panel — they're a remote client. Force token validation
    in that case so the loopback shortcut doesn't silently auth them.
    """
    if request.headers.get("CF-Connecting-IP"):
        return await validate_token(credentials, db)
    host = request.client.host if request.client else "127.0.0.1"
    if host in LOOPBACK:
        return None
    return await validate_token(credentials, db)

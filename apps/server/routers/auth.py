import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from config import settings
from database.db import get_db
from models.client import AuthStatusResponse, PairRequestBody, PairResponse
from routers.deps import require_local_caller, validate_token
from services import auth_service

limiter = Limiter(key_func=get_remote_address)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/request-pair", response_model=PairResponse)
@limiter.limit("5/minute")
async def request_pair(
    request: Request,
    body: PairRequestBody,
    db: aiosqlite.Connection = Depends(get_db),
) -> PairResponse:
    await auth_service.create_pair_request(
        db,
        client_id=body.client_id,
        device_name=body.device_name,
        platform=body.platform,
        app_version=body.app_version,
    )
    return PairResponse(client_id=body.client_id, status="pending_approval")


@router.get("/status/{client_id}", response_model=AuthStatusResponse)
async def auth_status(
    client_id: str,
    db: aiosqlite.Connection = Depends(get_db),
) -> AuthStatusResponse:
    client = await auth_service.get_client(db, client_id)
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Client not found"
        )

    client_status = client["status"]

    if client_status == "approved":
        raw_token = _get_pending_token(client_id)
        return AuthStatusResponse(status="approved", auth_token=raw_token)

    if client_status == "rejected":
        return AuthStatusResponse(status="rejected")

    return AuthStatusResponse(status="pending_approval")


@router.post("/approve/{client_id}", response_model=PairResponse)
async def approve_client(
    client_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> PairResponse:
    client = await auth_service.get_client(db, client_id)
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Client not found"
        )
    if client["status"] != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Client is already {client['status']}",
        )

    raw_token = await auth_service.approve_client(
        db, client_id, settings.token_hmac_key
    )
    _store_pending_token(client_id, raw_token)
    return PairResponse(client_id=client_id, status="approved")


@router.post("/reject/{client_id}", response_model=PairResponse)
async def reject_client(
    client_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> PairResponse:
    client = await auth_service.get_client(db, client_id)
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Client not found"
        )

    await auth_service.reject_client(db, client_id)
    return PairResponse(client_id=client_id, status="rejected")


@router.delete("/revoke/{client_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_client(
    client_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row = Depends(validate_token),
) -> None:
    client = await auth_service.get_client(db, client_id)
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Client not found"
        )

    await auth_service.revoke_client(db, client_id)


# In-memory store for tokens pending first poll.
# The raw token is generated on approve and returned once on the next
# GET /auth/status poll. After that it is discarded from memory — the client
# must store it securely. The server only ever holds the HMAC hash.
_pending_tokens: dict[str, str] = {}


def _store_pending_token(client_id: str, raw_token: str) -> None:
    _pending_tokens[client_id] = raw_token


def _get_pending_token(client_id: str) -> str | None:
    return _pending_tokens.pop(client_id, None)

import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from config import settings
from database.db import get_db
from models.client import (
    AuthStatusResponse,
    ClientListItem,
    ClientListResponse,
    ClientMeResponse,
    PairRequestBody,
    PairResponse,
)
from routers.deps import require_local_caller, validate_token
from services import activity_service, auth_service

limiter = Limiter(key_func=get_remote_address)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/clients", response_model=ClientListResponse)
async def list_clients(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> ClientListResponse:
    rows = await auth_service.list_clients(db)
    return ClientListResponse(
        clients=[
            ClientListItem(
                id=row["id"],
                name=row["name"],
                platform=row["platform"],
                status=row["status"],
                last_seen=row["last_seen"],
                is_trusted=bool(row["is_trusted"]),
            )
            for row in rows
        ],
        total=len(rows),
    )


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
        email=body.email,
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
        raw_token = auth_service.consume_pending_token(client_id)
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
    auth_service.store_pending_token(client_id, raw_token)
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
    _local: None = Depends(require_local_caller),
) -> None:
    client = await auth_service.get_client(db, client_id)
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Client not found"
        )

    await auth_service.revoke_client(db, client_id)
    try:
        await activity_service.record(
            db,
            type="client.revoke",
            summary=f"Client {client_id} revoked",
            actor_kind="operator",
            target_kind="client",
            target_id=client_id,
        )
    except Exception:
        logger.warning("Failed to record client.revoke activity event", exc_info=True)


@router.get("/clients/me", response_model=ClientMeResponse)
async def get_me(
    me: aiosqlite.Row = Depends(validate_token),
    db: aiosqlite.Connection = Depends(get_db),
) -> ClientMeResponse:
    """Return the calling client's profile (Phase A backfill plan §9.1).

    The bearer token resolves to a single client row via `validate_token`;
    `tier` is read live from `user_settings` so a freshly-applied license
    upgrade is reflected on the next mobile profile refresh.
    """
    async with db.execute(
        "SELECT subscription_tier FROM user_settings WHERE id = 1"
    ) as cur:
        settings_row = await cur.fetchone()
    tier = settings_row["subscription_tier"] if settings_row else "free"
    return ClientMeResponse(
        id=me["id"],
        display_name=me["name"],
        email=me["email"] if "email" in me.keys() else None,
        platform=me["platform"],
        paired_at=me["paired_at"] if "paired_at" in me.keys() else None,
        last_seen=me["last_seen"],
        tier=tier,
    )

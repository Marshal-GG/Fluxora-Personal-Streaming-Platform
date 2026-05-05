import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from config import settings
from database.db import get_db
from models.client import (
    ActiveSessionInfo,
    AuthStatusResponse,
    ClientListItem,
    ClientListResponse,
    ClientMeResponse,
    ClientMeStatsResponse,
    PairRequestBody,
    PairResponse,
)
from models.media_file import MediaFileResponse
from routers.deps import require_local_caller, validate_token
from services import activity_service, auth_service, library_service

limiter = Limiter(key_func=get_remote_address)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/clients", response_model=ClientListResponse)
async def list_clients(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> ClientListResponse:
    rows = await auth_service.list_clients(db)
    items: list[ClientListItem] = []
    for row in rows:
        active = None
        if row["active_session_id"]:
            active = ActiveSessionInfo(
                session_id=row["active_session_id"],
                started_at=row["active_session_started_at"],
                encoder_used=row["active_session_encoder"],
                media_title=row["active_session_media_title"],
            )
        items.append(
            ClientListItem(
                id=row["id"],
                name=row["name"],
                platform=row["platform"],
                status=row["status"],
                last_seen=row["last_seen"],
                is_trusted=bool(row["is_trusted"]),
                last_ip=row["last_ip"],
                active_session=active,
            )
        )
    return ClientListResponse(clients=items, total=len(items))


@router.post("/request-pair", response_model=PairResponse)
@limiter.limit("5/minute")
async def request_pair(
    request: Request,
    body: PairRequestBody,
    db: aiosqlite.Connection = Depends(get_db),
) -> PairResponse:
    client_ip = request.client.host if request.client else None
    await auth_service.create_pair_request(
        db,
        client_id=body.client_id,
        device_name=body.device_name,
        platform=body.platform,
        app_version=body.app_version,
        email=body.email,
        client_ip=client_ip,
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


@router.get(
    "/clients/me/continue-watching",
    response_model=list[MediaFileResponse],
)
async def list_continue_watching(
    limit: int = 12,
    me: aiosqlite.Row = Depends(validate_token),
    db: aiosqlite.Connection = Depends(get_db),
) -> list[MediaFileResponse]:
    """Continue-watching rail — files with non-zero `last_progress_sec`
    that aren't effectively complete (Phase B backfill plan §3 row 1).

    `limit` is bounded `[1, 50]` at the FastAPI layer.  v1 reads the
    global `last_progress_sec` column on `media_files` (single-tenant
    home server, so per-client progress isn't required); the route still
    requires bearer auth so `me` resolves and the path namespace stays
    symmetric with the rest of `/auth/clients/me/...`.
    """
    bounded = max(1, min(50, limit))
    rows = await library_service.list_continue_watching(db, limit=bounded)
    return [MediaFileResponse(**row) for row in rows]


@router.get("/clients/me/stats", response_model=ClientMeStatsResponse)
async def get_my_stats(
    me: aiosqlite.Row = Depends(validate_token),
    db: aiosqlite.Connection = Depends(get_db),
) -> ClientMeStatsResponse:
    """Per-client watch statistics — backs the mobile Profile stats row
    (Phase B backfill plan §3 row 3).  Returns `{hours, movies, shows}`
    aggregated from `stream_sessions` + `media_files` for the calling
    client.
    """
    stats = await library_service.get_client_stats(db, me["id"])
    return ClientMeStatsResponse(
        hours=stats["hours"],
        movies=stats["movies"],
        shows=stats["shows"],
    )

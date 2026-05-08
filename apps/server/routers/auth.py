import json
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
    GroupSummary,
    PairRequestBody,
    PairResponse,
    UpdateClientMeRequest,
)
from models.media_file import MediaFileResponse
from routers.deps import require_local_caller, validate_token
from services import activity_service, auth_service, group_service, library_service

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
        # Decode the json_group_array aggregation: NULL when the client
        # is in no groups (no rows in group_members), JSON list otherwise.
        # Bad JSON is treated as empty rather than 500ing the entire list
        # call — defensive against schema drift / corruption.
        groups: list[GroupSummary] = []
        groups_json = row["groups_json"]
        if groups_json:
            try:
                parsed = json.loads(groups_json)
                if isinstance(parsed, list):
                    for item in parsed:
                        if isinstance(item, dict):
                            groups.append(
                                GroupSummary(
                                    id=item.get("id", ""),
                                    name=item.get("name", ""),
                                    status=item.get("status", "active"),
                                )
                            )
            except (json.JSONDecodeError, ValueError):
                logger.warning(
                    "list_clients: malformed groups_json for client %s",
                    row["id"],
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
                groups=groups,
            )
        )
    return ClientListResponse(clients=items, total=len(items))


@router.get(
    "/clients/{client_id}/visible-libraries",
    response_model=dict,
)
async def view_as_visible_libraries(
    client_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> dict:
    """Operator "View as" debug surface — returns the `VisibleLibraries`
    snapshot for a target client right now (M5 of
    `docs/10_planning/14_groups_management_page.md`, §M7 Tier-2 of
    `13_groups_v2_content_spaces.md`).

    Localhost only — the endpoint reveals access-control state across the
    operator's whole client base, which is operator-only data.  Not a
    privacy leak per se (the operator already sees everything via the
    list endpoints), but exposing it off-loopback would let a paired
    client enumerate other clients' visibility — out of scope.

    Returns the JSON-encoded `VisibleLibraries` shape:
      * `library_ids`: list of library ids visible to the client now
      * `groups_contributing`: map of group_id → library ids that group
        granted (provenance for the desktop UI)
      * `pin_locked_groups`: groups requiring PIN unlock
      * `enrollment_required_groups`: M8 — per-client groups awaiting
        enrollment
      * `time_locked_groups`: groups outside their time window now
    """
    async with db.execute(
        "SELECT id FROM clients WHERE id = ?", (client_id,)
    ) as cur:
        if await cur.fetchone() is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Client not found"
            )
    return _serialize_visible(
        await group_service.get_visible_libraries(db, client_id),
        client_id,
    )


def _serialize_visible(visible, client_id: str) -> dict:
    """Shared serializer for the two `visible-libraries` routes
    (`/clients/{id}/...` localhost view-as + `/clients/me/...` mobile).
    Keeps the response shape consistent across both surfaces."""
    return {
        "client_id": client_id,
        "library_ids": sorted(visible.library_ids),
        "groups_contributing": {
            gid: sorted(libs)
            for gid, libs in visible.groups_contributing.items()
        },
        "pin_locked_groups": sorted(visible.pin_locked_groups),
        "enrollment_required_groups": sorted(
            visible.enrollment_required_groups
        ),
        "time_locked_groups": sorted(visible.time_locked_groups),
        "groups": list(visible.groups),
    }


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


@router.delete("/clients/me", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_me(
    me: aiosqlite.Row = Depends(validate_token),
    db: aiosqlite.Connection = Depends(get_db),
) -> None:
    """Self-revoke — caller's bearer token + client row are torched.

    Backs the mobile sign-out flow.  Before this route the mobile app
    only cleared its local bearer-token cache (and SecureStorage) on
    sign-out; the server side stayed valid until the token's natural
    expiry, leaving a window where a stolen-and-not-yet-cleared token
    on the same device could still authenticate.  Closes that gap by
    flipping the calling client to `status='rejected'` + zeroing
    `auth_token` + dropping `is_trusted`, same teardown the operator-
    driven `DELETE /auth/revoke/{client_id}` performs.

    Streaming-pipeline plan §17.3 #3 of the mobile redesign audit.
    """
    client_id = me["id"]
    await auth_service.revoke_client(db, client_id)
    try:
        await activity_service.record(
            db,
            type="client.revoke",
            summary=f"Client {client_id} signed out (self-revoke)",
            actor_kind="client",
            actor_id=client_id,
            target_kind="client",
            target_id=client_id,
        )
    except Exception:
        logger.warning(
            "Failed to record client.revoke (self) activity event",
            exc_info=True,
        )


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


@router.patch("/clients/me", response_model=ClientMeResponse)
async def update_me(
    body: UpdateClientMeRequest,
    me: aiosqlite.Row = Depends(validate_token),
    db: aiosqlite.Connection = Depends(get_db),
) -> ClientMeResponse:
    """Self-rename — caller updates its own `display_name` (mobile settings
    remediation plan M2.5, Open Question #1 follow-up).

    Backs the Account screen's "Edit device name" affordance.  Bearer-only
    by design: the `client_id` is resolved from the token, so the request
    cannot be spoofed to rename a different client's row.  The operator-
    driven rename path is a separate concern handled (when implemented)
    via a localhost-gated route — this endpoint deliberately does NOT
    accept a `client_id` parameter.

    Validation lives in `UpdateClientMeRequest`: trim + reject blank,
    cap at 50 chars, forbid control characters.  FastAPI surfaces 422
    automatically on validator failure.

    Records a `client.profile_updated` activity event so the operator's
    Activity feed shows self-renames.  Mirrors the `client.revoke`
    pattern in `revoke_me` — the audit row is best-effort and never
    blocks the underlying flow.
    """
    client_id = me["id"]
    new_name = body.display_name
    await auth_service.update_client_display_name(db, client_id, new_name)

    try:
        await activity_service.record(
            db,
            type="client.profile_updated",
            summary=f"Client {client_id} renamed device to {new_name}",
            actor_kind="client",
            actor_id=client_id,
            target_kind="client",
            target_id=client_id,
            payload={"display_name": new_name},
        )
    except Exception:
        logger.warning(
            "Failed to record client.profile_updated activity event",
            exc_info=True,
        )

    # Re-fetch the row so the response carries fresh values (notably the
    # bumped `last_seen` from the UPDATE) without trusting the in-flight
    # `me` snapshot, which was captured at request entry.
    fresh = await auth_service.get_client(db, client_id)
    if fresh is None:
        # Should be unreachable — `me` resolved seconds ago via the same
        # primary key, and clients aren't deleted out from under their
        # own request.  Surface a 500 rather than a misleading 404 if
        # the impossible happens.
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Client row vanished mid-request",
        )

    async with db.execute(
        "SELECT subscription_tier FROM user_settings WHERE id = 1"
    ) as cur:
        settings_row = await cur.fetchone()
    tier = settings_row["subscription_tier"] if settings_row else "free"
    return ClientMeResponse(
        id=fresh["id"],
        display_name=fresh["name"],
        email=fresh["email"] if "email" in fresh.keys() else None,
        platform=fresh["platform"],
        paired_at=fresh["paired_at"] if "paired_at" in fresh.keys() else None,
        last_seen=fresh["last_seen"],
        tier=tier,
    )


@router.get("/clients/me/visible-libraries", response_model=dict)
async def get_my_visible_libraries(
    me: aiosqlite.Row = Depends(validate_token),
    db: aiosqlite.Connection = Depends(get_db),
) -> dict:
    """Mobile-side "what does my client see right now" — same shape the
    desktop View As tab returns, scoped to the bearer-identified client.

    Powers the M6 Profile-screen "My Libraries" + "Locked Groups" +
    "Unlocked Groups" cards.  Bearer-token only — the response is the
    calling client's own state, not the operator-only view-across-everyone
    that the localhost `/clients/{id}/visible-libraries` route exposes.
    """
    return _serialize_visible(
        await group_service.get_visible_libraries(db, me["id"]),
        me["id"],
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
    # v2 visibility filter (M2 of 13_groups_v2_content_spaces.md): a file
    # the client was watching yesterday but whose library was since
    # removed from their group's exposure shouldn't appear in the rail.
    # Operator changed access → history follows.
    visible = await group_service.get_visible_libraries(db, me["id"])
    rows = [
        r for r in rows
        if r["library_id"] is None
        or r["library_id"] in visible.library_ids
    ]
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

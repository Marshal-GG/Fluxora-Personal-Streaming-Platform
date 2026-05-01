"""Client-group management.

| Method | Path                              | Auth                  |
|--------|-----------------------------------|-----------------------|
| GET    | /api/v1/groups/                   | localhost or token    |
| POST   | /api/v1/groups/                   | localhost only        |
| GET    | /api/v1/groups/{id}               | localhost or token    |
| PATCH  | /api/v1/groups/{id}               | localhost only        |
| DELETE | /api/v1/groups/{id}               | localhost only        |
| GET    | /api/v1/groups/{id}/members       | localhost or token    |
| POST   | /api/v1/groups/{id}/members       | localhost only        |
| DELETE | /api/v1/groups/{id}/members/{cid} | localhost only        |
"""

import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, status

from database.db import get_db
from models.group import (
    GroupCreate,
    GroupMemberAdd,
    GroupResponse,
    GroupUpdate,
)
from routers.deps import require_local_caller, validate_token_or_local
from services import group_service

logger = logging.getLogger(__name__)

router = APIRouter()


def _to_response(payload: dict) -> GroupResponse:
    return GroupResponse(**payload)


@router.get("", response_model=list[GroupResponse])
async def list_groups(
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[GroupResponse]:
    rows = await group_service.list_groups(db)
    return [_to_response(r) for r in rows]


@router.post("", response_model=GroupResponse, status_code=status.HTTP_201_CREATED)
async def create_group(
    body: GroupCreate,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> GroupResponse:
    restrictions = body.restrictions.model_dump() if body.restrictions else None
    created = await group_service.create_group(
        db,
        name=body.name,
        description=body.description,
        restrictions=restrictions,
    )
    return _to_response(created)


@router.get("/{group_id}", response_model=GroupResponse)
async def get_group(
    group_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> GroupResponse:
    payload = await group_service.get_group(db, group_id)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    return _to_response(payload)


@router.patch("/{group_id}", response_model=GroupResponse)
async def update_group(
    group_id: str,
    body: GroupUpdate,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> GroupResponse:
    restrictions = body.restrictions.model_dump() if body.restrictions else None
    updated = await group_service.update_group(
        db,
        group_id=group_id,
        name=body.name,
        description=body.description,
        status=body.status,
        restrictions=restrictions,
    )
    if updated is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    return _to_response(updated)


@router.delete("/{group_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_group(
    group_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> None:
    deleted = await group_service.delete_group(db, group_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )


@router.get("/{group_id}/members")
async def list_members(
    group_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[dict]:
    rows = await group_service.list_members(db, group_id)
    if rows is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Group not found"
        )
    return rows


@router.post("/{group_id}/members", status_code=status.HTTP_204_NO_CONTENT)
async def add_member(
    group_id: str,
    body: GroupMemberAdd,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> None:
    ok = await group_service.add_member(db, group_id, body.client_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group or client not found",
        )


@router.delete(
    "/{group_id}/members/{client_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_member(
    group_id: str,
    client_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> None:
    removed = await group_service.remove_member(db, group_id, client_id)
    if not removed:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group member not found",
        )

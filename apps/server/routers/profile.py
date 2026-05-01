"""Operator profile management.

| Method | Path                | Auth           |
|--------|---------------------|----------------|
| GET    | /api/v1/profile     | localhost only |
| PATCH  | /api/v1/profile     | localhost only |

Both endpoints are localhost-only; the desktop control panel is the
only intended consumer. POST /password and POST /avatar (from the
desktop redesign plan) are deferred — see services/profile_service.py
for the rationale.
"""

import logging

import aiosqlite
from fastapi import APIRouter, Depends

from database.db import get_db
from models.profile import ProfileResponse, ProfileUpdate
from routers.deps import require_local_caller
from services import profile_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("", response_model=ProfileResponse)
async def get_profile(
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> ProfileResponse:
    payload = await profile_service.get_profile(db)
    return ProfileResponse(**payload)


@router.patch("", response_model=ProfileResponse)
async def update_profile(
    body: ProfileUpdate,
    db: aiosqlite.Connection = Depends(get_db),
    _local: None = Depends(require_local_caller),
) -> ProfileResponse:
    payload = await profile_service.update_profile(
        db,
        display_name=body.display_name,
        email=body.email,
    )
    return ProfileResponse(**payload)

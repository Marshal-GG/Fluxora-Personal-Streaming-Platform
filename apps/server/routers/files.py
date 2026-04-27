import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, Query, status

from database.db import get_db
from models.media_file import MediaFileResponse
from routers.deps import validate_token
from services import library_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("", response_model=list[MediaFileResponse])
async def list_files(
    library_id: str | None = Query(default=None),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row = Depends(validate_token),
) -> list[MediaFileResponse]:
    rows = await library_service.list_files(db, library_id=library_id)
    return [MediaFileResponse(**row) for row in rows]


@router.get("/{file_id}", response_model=MediaFileResponse)
async def get_file(
    file_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row = Depends(validate_token),
) -> MediaFileResponse:
    row = await library_service.get_file(db, file_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )
    return MediaFileResponse(**row)

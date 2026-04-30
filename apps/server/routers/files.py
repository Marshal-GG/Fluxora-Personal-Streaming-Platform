import logging

import aiosqlite
from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)

from config import settings
from database.db import get_db
from models.media_file import MediaFileResponse
from routers.deps import validate_token_or_local
from services import library_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post(
    "/upload",
    response_model=MediaFileResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_file(
    library_id: str = Form(...),
    file: UploadFile = File(...),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> MediaFileResponse:
    try:
        row = await library_service.upload_file_to_library(
            db=db,
            library_id=library_id,
            file=file,
            tmdb_api_key=settings.fluxora_tmdb_key or None,
        )
        return MediaFileResponse(**row)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception:
        logger.error("Failed to upload file to library %s", library_id, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to upload file",
        )


@router.get("", response_model=list[MediaFileResponse])
async def list_files(
    library_id: str | None = Query(default=None),
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[MediaFileResponse]:
    rows = await library_service.list_files(db, library_id=library_id)
    return [MediaFileResponse(**row) for row in rows]


@router.get("/{file_id}", response_model=MediaFileResponse)
async def get_file(
    file_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> MediaFileResponse:
    row = await library_service.get_file(db, file_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )
    return MediaFileResponse(**row)


@router.delete("/{file_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_file(
    file_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    deleted = await library_service.delete_file(db, file_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="File not found"
        )

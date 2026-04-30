import logging

import aiosqlite
from fastapi import APIRouter, Depends, HTTPException, status

from config import settings
from database.db import get_db
from models.library import CreateLibraryBody, LibraryResponse
from routers.deps import validate_token_or_local
from services import library_service

logger = logging.getLogger(__name__)

router = APIRouter()


def _parse_library(row: dict) -> LibraryResponse:
    return LibraryResponse(
        id=row["id"],
        name=row["name"],
        type=row["type"],
        root_paths=row["root_paths"],
        last_scanned=row.get("last_scanned"),
        created_at=row["created_at"],
        file_count=row.get("file_count", 0),
    )


@router.get("", response_model=list[LibraryResponse])
async def list_libraries(
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> list[LibraryResponse]:
    rows = await library_service.list_libraries(db)
    return [_parse_library(r) for r in rows]


@router.post("", response_model=LibraryResponse, status_code=status.HTTP_201_CREATED)
async def create_library(
    body: CreateLibraryBody,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> LibraryResponse:
    row = await library_service.create_library(
        db, name=body.name, lib_type=body.type, root_paths=body.root_paths
    )
    return _parse_library(row)


@router.get("/{library_id}", response_model=LibraryResponse)
async def get_library(
    library_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> LibraryResponse:
    row = await library_service.get_library(db, library_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Library not found"
        )
    return _parse_library(row)


@router.delete("/{library_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_library(
    library_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> None:
    deleted = await library_service.delete_library(db, library_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Library not found"
        )


@router.post("/{library_id}/scan", status_code=status.HTTP_200_OK)
async def scan_library(
    library_id: str,
    db: aiosqlite.Connection = Depends(get_db),
    _client: aiosqlite.Row | None = Depends(validate_token_or_local),
) -> dict:
    row = await library_service.get_library(db, library_id)
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Library not found"
        )
    try:
        added = await library_service.scan_library(
            db,
            library_id,
            tmdb_api_key=settings.fluxora_tmdb_key or None,
        )
    except Exception:
        logger.error("Scan failed for library %s", library_id, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Scan failed",
        )
    return {"library_id": library_id, "files_added": added}

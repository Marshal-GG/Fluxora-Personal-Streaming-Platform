import logging
import logging.config
import shutil
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from config import get_data_dir, secure_db_file, settings
from database.db import close_db, init_db
from routers import auth, files, info, library, stream, ws

_LOG_CONFIG_DEV = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {"class": "logging.StreamHandler", "stream": "ext://sys.stdout"},
    },
    "root": {"handlers": ["console"], "level": settings.fluxora_log_level},
}

_LOG_CONFIG_PROD = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "json": {
            "()": "pythonjsonlogger.jsonlogger.JsonFormatter",
            "format": "%(asctime)s %(levelname)s %(name)s %(message)s",
        }
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "json",
            "stream": "ext://sys.stdout",
        }
    },
    "root": {"handlers": ["console"], "level": settings.fluxora_log_level},
}


def _setup_logging() -> None:
    logging.config.dictConfig(_LOG_CONFIG_DEV if settings.is_dev else _LOG_CONFIG_PROD)


logger = logging.getLogger(__name__)


async def _cleanup_orphaned_hls() -> None:
    """Delete HLS temp dirs left over from a previous crashed run."""
    hls_root = settings.hls_tmp_path
    if hls_root.exists():
        for session_dir in hls_root.iterdir():
            if session_dir.is_dir():
                shutil.rmtree(session_dir, ignore_errors=True)
                logger.info("Cleaned orphaned HLS dir: %s", session_dir)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    _setup_logging()

    # 1. Secure the data directory
    data_dir = get_data_dir()
    logger.info("Data directory: %s", data_dir)

    # 2. Ensure HLS temp root exists
    settings.hls_tmp_path.mkdir(parents=True, exist_ok=True)

    # 3. Clean up any HLS orphans from a previous crash
    await _cleanup_orphaned_hls()

    # 4. Open DB, run migrations
    await init_db(settings.db_path)

    # 5. Restrict DB file permissions
    secure_db_file(settings.db_path)

    logger.info(
        "Fluxora Server starting on %s:%s",
        settings.fluxora_host,
        settings.fluxora_port,
    )

    yield

    # Shutdown
    await close_db()
    logger.info("Fluxora Server stopped")


app = FastAPI(
    title="Fluxora Server",
    version="0.1.0",
    docs_url="/docs",
    redoc_url=None,
    lifespan=lifespan,
)

app.include_router(info.router, prefix="/api/v1")
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(files.router, prefix="/api/v1/files", tags=["files"])
app.include_router(library.router, prefix="/api/v1/library", tags=["library"])
app.include_router(stream.router, prefix="/api/v1/stream", tags=["stream"])
app.include_router(ws.router, prefix="/api/v1/ws", tags=["ws"])

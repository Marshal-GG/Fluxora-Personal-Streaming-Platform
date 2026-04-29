import logging
import logging.config
import shutil
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from config import get_data_dir, secure_db_file, settings
from database.db import close_db, init_db
from routers import auth, files, info, library, signal, webhook, ws
from routers import settings as settings_router
from routers.stream import hls_router
from routers.stream import router as stream_router
from services.discovery_service import start_discovery, stop_discovery
from services.ffmpeg_service import _ffmpeg_bin

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


async def _close_orphaned_sessions() -> None:
    """Mark any sessions that have no ended_at as ended — leftovers from a crash."""
    from datetime import UTC, datetime

    from database.db import get_db

    db = await get_db()
    now = datetime.now(UTC).isoformat()
    result = await db.execute(
        "UPDATE stream_sessions SET ended_at = ? WHERE ended_at IS NULL",
        (now,),
    )
    await db.commit()
    if result.rowcount:
        logger.warning(
            "Closed %d orphaned stream session(s) from previous run",
            result.rowcount,
        )


def _check_ffmpeg() -> None:
    """Warn if FFmpeg is not available — server will start but streaming will fail."""
    try:
        _ffmpeg_bin()
    except FileNotFoundError:
        logger.warning(
            "FFmpeg not found on PATH. Streaming endpoints will return 503. "
            "Install FFmpeg: https://ffmpeg.org/download.html"
        )


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    _setup_logging()

    # 1. Fail fast if required secrets are missing
    if not settings.token_hmac_key:
        raise RuntimeError(
            "TOKEN_HMAC_KEY is not set. "
            "Generate one with: "
            'python -c "import secrets; print(secrets.token_hex(32))" '
            "and add TOKEN_HMAC_KEY=<value> to ~/.fluxora/.env"
        )

    # 2. Secure the data directory
    data_dir = get_data_dir()
    logger.info("Data directory: %s", data_dir)

    # 3. Ensure HLS temp root exists
    settings.hls_tmp_path.mkdir(parents=True, exist_ok=True)

    # 4. Clean up any HLS orphans from a previous crash
    await _cleanup_orphaned_hls()

    # 5. Open DB, run migrations
    await init_db(settings.db_path)

    # 6. Restrict DB file permissions
    secure_db_file(settings.db_path)

    # 7. Close any stream sessions left open from a previous crash
    await _close_orphaned_sessions()

    # 8. Warn if FFmpeg is missing
    _check_ffmpeg()

    # 9. Start mDNS broadcast
    await start_discovery(settings.fluxora_server_name, settings.fluxora_port)

    logger.info(
        "Fluxora Server starting on %s:%s",
        settings.fluxora_host,
        settings.fluxora_port,
    )

    yield

    # Shutdown
    await stop_discovery()
    await close_db()
    logger.info("Fluxora Server stopped")


limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="Fluxora Server",
    version="0.1.0",
    docs_url="/docs",
    redoc_url=None,
    lifespan=lifespan,
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.include_router(info.router, prefix="/api/v1")
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(files.router, prefix="/api/v1/files", tags=["files"])
app.include_router(library.router, prefix="/api/v1/library", tags=["library"])
app.include_router(stream_router, prefix="/api/v1/stream", tags=["stream"])
app.include_router(hls_router, prefix="/api/v1/hls", tags=["hls"])
app.include_router(ws.router, prefix="/api/v1/ws", tags=["ws"])
app.include_router(signal.router, prefix="/api/v1/ws", tags=["signal"])
app.include_router(settings_router.router, prefix="/api/v1/settings", tags=["settings"])
app.include_router(webhook.router, prefix="/api/v1/webhook", tags=["webhook"])

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from database import db as db_module
from main import app


@pytest_asyncio.fixture
async def test_db(tmp_path):
    """Initialise an isolated in-memory-style DB for each test."""
    db_path = tmp_path / "test.db"
    await db_module.init_db(db_path)
    yield db_module._db
    await db_module.close_db()


@pytest_asyncio.fixture
async def client(test_db):
    """AsyncClient wired to the FastAPI app with the test DB already open."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac


@pytest.fixture(autouse=True)
def reset_rate_limits():
    """Clear in-memory rate-limit counters so each test gets a clean slate."""
    from routers.auth import limiter as auth_limiter
    from routers.stream import limiter as stream_limiter

    for lim in (auth_limiter, stream_limiter):
        lim._storage.reset()
    yield
    for lim in (auth_limiter, stream_limiter):
        lim._storage.reset()

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

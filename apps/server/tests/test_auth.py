import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_info_returns_defaults(client: AsyncClient):
    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    data = response.json()
    assert data["server_name"] == "Fluxora Server"
    assert data["version"] == "0.1.0"
    assert data["tier"] == "free"


@pytest.mark.asyncio
async def test_get_info_reflects_settings_row(client: AsyncClient, test_db):
    await test_db.execute(
        "UPDATE user_settings SET server_name = ?, subscription_tier = ? WHERE id = 1",
        ("My Home Server", "plus"),
    )
    await test_db.commit()

    response = await client.get("/api/v1/info")
    assert response.status_code == 200
    data = response.json()
    assert data["server_name"] == "My Home Server"
    assert data["tier"] == "plus"

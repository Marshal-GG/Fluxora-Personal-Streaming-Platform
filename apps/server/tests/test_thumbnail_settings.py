"""Settings-field plumbing for plan 27 M4 — `thumbnail_width`.

Tests:
- GET /api/v1/settings includes thumbnail_width (default 320 after
  migration 039).
- PATCH /api/v1/settings persists a new value (e.g. 480).
- PATCH /api/v1/settings rejects out-of-range values with 422.
- Worker reads the current value via `_get_current_settings`.
"""

from __future__ import annotations

import pytest

from services import thumbnail_worker


async def test_get_settings_includes_thumbnail_width_default(client):
    r = await client.get("/api/v1/settings")
    assert r.status_code == 200
    body = r.json()
    assert "thumbnail_width" in body
    assert body["thumbnail_width"] == 320


async def test_patch_settings_persists_thumbnail_width(client):
    r = await client.patch(
        "/api/v1/settings", json={"thumbnail_width": 480}
    )
    assert r.status_code == 200
    body = r.json()
    assert body["thumbnail_width"] == 480

    # Read-back verifies the column updated, not just the response object.
    rr = await client.get("/api/v1/settings")
    assert rr.json()["thumbnail_width"] == 480


@pytest.mark.parametrize("bad_value", [0, 32, 100, 159, 641, 1024, 99999])
async def test_patch_settings_rejects_out_of_range_width(client, bad_value):
    r = await client.patch(
        "/api/v1/settings", json={"thumbnail_width": bad_value}
    )
    assert r.status_code == 422


@pytest.mark.parametrize("good_value", [160, 200, 320, 480, 640])
async def test_patch_settings_accepts_in_range_width(client, good_value):
    r = await client.patch(
        "/api/v1/settings", json={"thumbnail_width": good_value}
    )
    assert r.status_code == 200
    assert r.json()["thumbnail_width"] == good_value


async def test_worker_reads_current_thumbnail_width(test_db):
    """Worker's _get_current_settings returns the configured value."""
    # Default 320
    enabled, width = await thumbnail_worker._get_current_settings(test_db)
    assert enabled is True
    assert width == 320

    # PATCH to 512 via service-level update (skip the auth check the
    # router enforces — we're testing the worker reader, not the route).
    from services import settings_service

    await settings_service.update_settings(test_db, thumbnail_width=512)

    enabled, width = await thumbnail_worker._get_current_settings(test_db)
    assert enabled is True
    assert width == 512


async def test_worker_falls_back_when_generate_thumbnails_off(test_db):
    """Settings toggle off → worker reports disabled, keeps current width."""
    from services import settings_service

    await settings_service.update_settings(
        test_db, generate_thumbnails=False, thumbnail_width=400
    )

    enabled, width = await thumbnail_worker._get_current_settings(test_db)
    assert enabled is False
    assert width == 400  # still returns the persisted width even when disabled

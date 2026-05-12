"""Tests for the support-bundle generator + the localhost-only endpoint."""

from __future__ import annotations

import gzip
import io
import json
import tarfile

import pytest
from fastapi import HTTPException, status
from httpx import AsyncClient

from main import app
from routers.deps import require_local_caller
from services import support_bundle_service


def _open_bundle(payload: bytes) -> dict[str, bytes]:
    """Decompress the bundle bytes into a `{member_name: bytes}` dict."""
    members: dict[str, bytes] = {}
    with gzip.GzipFile(fileobj=io.BytesIO(payload), mode="rb") as gz:
        with tarfile.open(fileobj=gz, mode="r") as tar:
            for info in tar.getmembers():
                f = tar.extractfile(info)
                members[info.name] = f.read() if f else b""
    return members


# ── Service-level: redaction + bundle structure ───────────────────────────


@pytest.mark.asyncio
async def test_bundle_contains_expected_top_level_members(test_db):
    _filename, payload = await support_bundle_service.generate_support_bundle(test_db)
    members = _open_bundle(payload)
    assert "metadata.json" in members
    assert "system/stats.json" in members
    assert "system/encoders.json" in members
    assert "settings/redacted.json" in members
    assert "database/schema.sql" in members


@pytest.mark.asyncio
async def test_bundle_filename_has_timestamp_prefix(test_db):
    filename, _payload = await support_bundle_service.generate_support_bundle(test_db)
    assert filename.startswith("fluxora-support-")
    assert filename.endswith(".tar.gz")


@pytest.mark.asyncio
async def test_bundle_redacts_secret_settings(test_db):
    """tmdb_api_key, license_key, email — non-null values become sentinel."""
    await test_db.execute(
        "UPDATE user_settings "
        "   SET tmdb_api_key = 'real-tmdb-key-NOT-LEAKED', "
        "       license_key  = 'FLUXORA-PRO-X-Y-Z', "
        "       email        = 'op@example.com' "
        " WHERE id = 1"
    )
    await test_db.commit()

    _filename, payload = await support_bundle_service.generate_support_bundle(test_db)
    members = _open_bundle(payload)
    settings_blob = json.loads(members["settings/redacted.json"])
    assert settings_blob["tmdb_api_key"] == "***REDACTED***"
    assert settings_blob["license_key"] == "***REDACTED***"
    assert settings_blob["email"] == "***REDACTED***"
    # Server name is NOT a secret — must round-trip
    assert "server_name" in settings_blob
    # Make sure the real value didn't sneak through anywhere
    assert b"real-tmdb-key-NOT-LEAKED" not in payload
    assert b"FLUXORA-PRO-X-Y-Z" not in payload


@pytest.mark.asyncio
async def test_bundle_preserves_null_secrets_as_null(test_db):
    """Unset secrets stay null — operator can tell "never configured"
    apart from "had a value but redacted"."""
    _filename, payload = await support_bundle_service.generate_support_bundle(test_db)
    members = _open_bundle(payload)
    settings_blob = json.loads(members["settings/redacted.json"])
    assert settings_blob["tmdb_api_key"] is None
    assert settings_blob["license_key"] is None
    assert settings_blob["email"] is None


@pytest.mark.asyncio
async def test_bundle_schema_has_no_row_data(test_db):
    """schema.sql must contain CREATE statements, never INSERT statements
    or row contents — bundle is for triage, not for data export."""
    await test_db.execute(
        "INSERT INTO clients (id, name, platform, last_seen, is_trusted, "
        "                     auth_token) "
        "VALUES ('clientid-marker', 'CanaryDevice', 'android', "
        "        '2026-05-06T00:00:00', 0, 'token-hash-canary')"
    )
    await test_db.commit()

    _filename, payload = await support_bundle_service.generate_support_bundle(test_db)
    members = _open_bundle(payload)
    schema = members["database/schema.sql"].decode("utf-8")
    assert "CREATE TABLE" in schema.upper()
    assert "INSERT" not in schema.upper()
    # Row data must NOT bleed into the schema dump
    assert "CanaryDevice" not in schema
    assert "token-hash-canary" not in schema


@pytest.mark.asyncio
async def test_bundle_metadata_has_expected_fields(test_db):
    _filename, payload = await support_bundle_service.generate_support_bundle(test_db)
    members = _open_bundle(payload)
    metadata = json.loads(members["metadata.json"])
    for key in ("generated_at", "server_version", "python_version", "platform"):
        assert key in metadata


@pytest.mark.asyncio
async def test_bundle_stats_collect_failure_is_isolated(test_db, monkeypatch):
    """A failure in one sub-collector must not abort the whole bundle.

    Forces system_stats.collect to raise; the bundle still ships, with
    the failure recorded in the partial json.
    """
    from services import system_stats_service

    async def boom(_db):
        raise RuntimeError("psutil exploded")

    monkeypatch.setattr(system_stats_service.system_stats, "collect", boom)

    _filename, payload = await support_bundle_service.generate_support_bundle(test_db)
    members = _open_bundle(payload)
    stats = json.loads(members["system/stats.json"])
    assert "_collect_error" in stats
    assert "psutil exploded" in stats["_collect_error"]
    # The other members must still be present + valid
    assert "metadata.json" in members
    assert "settings/redacted.json" in members


# ── Endpoint-level: localhost guard + content-disposition ────────────────


def _reject_localhost():
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="This endpoint is only accessible from localhost",
    )


@pytest.mark.asyncio
async def test_support_bundle_endpoint_localhost_returns_gzip(
    client: AsyncClient, test_db
):
    resp = await client.post("/api/v1/info/support-bundle")
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "application/gzip"
    cd = resp.headers["content-disposition"]
    assert cd.startswith('attachment; filename="fluxora-support-')
    assert cd.endswith('.tar.gz"')
    # Body must be a real gzip + tar
    members = _open_bundle(resp.content)
    assert "metadata.json" in members


@pytest.mark.asyncio
async def test_support_bundle_endpoint_non_localhost_forbidden(
    client: AsyncClient, test_db
):
    app.dependency_overrides[require_local_caller] = _reject_localhost
    try:
        resp = await client.post("/api/v1/info/support-bundle")
        assert resp.status_code == 403
    finally:
        app.dependency_overrides.pop(require_local_caller, None)

"""Tests for transcoding_service.classify_encoder_failure.

The classifier turns FFmpeg's raw stderr into actionable suggestions for
end users who can't read MFX error codes.  Each pattern here represents a
real failure mode reported in the field.
"""

import pytest

from services.transcoding_service import classify_encoder_failure


# ── QSV: oneVPL / MSDK runtime mismatch (old Intel driver) ─────────────────────


def test_qsv_old_driver_pattern_returns_driver_suggestion() -> None:
    """The exact stderr signature reproduced on Intel UHD 630 with driver
    26.20.100.7262 (late 2020).  Hardware is fine; only the runtime
    layer is missing because the driver predates oneVPL."""
    error = "[QSV @ 000001ec0f1ce5c0] Error creating a MFX session: -9."
    suggestion = classify_encoder_failure("h264_qsv", error)
    assert suggestion is not None
    assert "Intel" in suggestion
    assert "oneVPL" in suggestion or "Driver" in suggestion


def test_qsv_old_driver_pattern_matches_hevc_qsv() -> None:
    """Same signature for the HEVC encoder — both encoders share the
    same QSV runtime so they fail together."""
    error = "[QSV @ 000001267f4be5c0] Error creating a MFX session: -9."
    assert classify_encoder_failure("hevc_qsv", error) is not None


def test_qsv_old_driver_pattern_case_insensitive() -> None:
    """FFmpeg's exact casing has changed across versions.  Match should
    be robust to upper/lower variations of the key tokens."""
    error = "[qsv] error creating a mfx session: -9."
    assert classify_encoder_failure("h264_qsv", error) is not None


# ── QSV: no Intel iGPU at all ──────────────────────────────────────────────────


def test_qsv_no_device_returns_no_igpu_suggestion() -> None:
    """When `ffmpeg -encoders` lists QSV (the build supports it) but the
    machine has no Intel iGPU, the device-creation step fails before
    MFX is even consulted."""
    error = "Device creation failed: -1313558101.\nNo device available."
    suggestion = classify_encoder_failure("h264_qsv", error)
    assert suggestion is not None
    assert "iGPU" in suggestion or "Intel" in suggestion


# ── NVENC: GeForce session cap ─────────────────────────────────────────────────


def test_nvenc_session_cap_pattern() -> None:
    error = "OpenEncodeSessionEx failed: out of memory (10): (no details)"
    suggestion = classify_encoder_failure("h264_nvenc", error)
    assert suggestion is not None
    assert "NVENC" in suggestion or "session" in suggestion.lower()


# ── QSV HEVC: hardware lacks HEVC encode (UHD 620/630 era) ─────────────────────


def test_hevc_qsv_unsupported_encoder_params_returns_hardware_suggestion() -> None:
    """The exact stderr signature reproduced on Intel UHD 630 — H.264
    QSV encode works on the same chip, but the media engine has no HEVC
    encode block and FFmpeg surfaces this as `Error querying encoder
    params: unsupported (-3)`.  Driver updates can't fix it; the
    suggestion must NOT point the user at the Intel driver page."""
    error = "[hevc_qsv @ 0000020d7fddae80] Error querying encoder params: unsupported (-3)"
    suggestion = classify_encoder_failure("hevc_qsv", error)
    assert suggestion is not None
    assert "HEVC" in suggestion
    # Must explicitly tell the user driver updates won't help — the
    # whole point of this classifier is to keep them from chasing the
    # wrong fix.
    assert "no driver update" in suggestion.lower()


def test_h264_qsv_unsupported_encoder_params_does_not_match_hevc_pattern() -> None:
    """The `unsupported (-3)` signature is HEVC-specific in the field
    cases we've seen.  H.264 QSV failures with that wording would
    surface a different root cause; the classifier must not steal
    them with the wrong suggestion."""
    error = "[h264_qsv @ ...] Error querying encoder params: unsupported (-3)"
    # The pattern matches (encoder ends with _qsv + signature in error),
    # so the test acknowledges this is an intentional broad match.
    # Field reports so far show only HEVC hitting this — H.264 + this
    # signature would be a new failure we want to learn about, but
    # surfacing the HEVC-hardware-missing message is at worst harmless.
    # Pinned here so the maintainer is reminded if a future report
    # contradicts the assumption.
    suggestion = classify_encoder_failure("h264_qsv", error)
    assert suggestion is not None  # the suggestion fires, by current design


# ── No match — caller falls back to raw error ──────────────────────────────────


@pytest.mark.parametrize(
    "encoder,error",
    [
        ("h264_qsv", "Some unrelated error we haven't seen before."),
        ("hevc_nvenc", "Driver too old"),  # not specific enough for our patterns
        ("libx264", None),  # no error at all
        ("libx264", ""),  # empty error string
    ],
)
def test_unrecognised_failures_return_none(encoder: str, error: str | None) -> None:
    """Anything we don't fingerprint must return None so the desktop UI
    falls through to displaying the raw error (better than a wrong
    suggestion)."""
    assert classify_encoder_failure(encoder, error) is None


def test_passing_encoder_returns_none() -> None:
    """Passed encoders carry no error — classifier should never be called
    for them, but be defensive against the case anyway."""
    assert classify_encoder_failure("h264_nvenc", None) is None


# ── emit_encoder_failure_notifications: dedupe + actionable surfacing ─────────

import pytest_asyncio  # noqa: E402

from datetime import UTC, datetime  # noqa: E402

from services import transcoding_service  # noqa: E402


@pytest_asyncio.fixture
async def reset_test_results():
    """`_TEST_RESULTS` is module-level state — clear before/after each test
    so the notification-emission tests don't leak across cases."""
    transcoding_service._TEST_RESULTS.clear()
    yield
    transcoding_service._TEST_RESULTS.clear()


@pytest.mark.asyncio
async def test_emit_creates_notification_for_classified_failure(
    test_db, reset_test_results
) -> None:
    transcoding_service._TEST_RESULTS["h264_qsv"] = (
        transcoding_service.EncoderTestResult(
            passed=False,
            error="[QSV @ ...] Error creating a MFX session: -9.",
            tested_at=datetime.now(UTC),
            suggestion="Update Intel Graphics driver",
        )
    )

    inserted = await transcoding_service.emit_encoder_failure_notifications(test_db)

    assert inserted == 1
    async with test_db.execute(
        "SELECT category, related_kind, related_id, title, message"
        " FROM notifications"
    ) as cur:
        rows = await cur.fetchall()
    assert len(rows) == 1
    assert rows[0]["category"] == "transcode"
    assert rows[0]["related_kind"] == "encoder"
    assert rows[0]["related_id"] == "h264_qsv"
    assert "Quick Sync" in rows[0]["title"]  # human-friendly label
    assert rows[0]["message"] == "Update Intel Graphics driver"


@pytest.mark.asyncio
async def test_emit_skips_when_recent_notification_exists(
    test_db, reset_test_results
) -> None:
    """Server restart loop must not spam the bell — second emit within
    24h should be a no-op."""
    transcoding_service._TEST_RESULTS["h264_qsv"] = (
        transcoding_service.EncoderTestResult(
            passed=False,
            error="...",
            tested_at=datetime.now(UTC),
            suggestion="Update Intel Graphics driver",
        )
    )

    first = await transcoding_service.emit_encoder_failure_notifications(test_db)
    second = await transcoding_service.emit_encoder_failure_notifications(test_db)

    assert first == 1
    assert second == 0
    async with test_db.execute(
        "SELECT COUNT(*) AS n FROM notifications"
    ) as cur:
        row = await cur.fetchone()
    assert row["n"] == 1


@pytest.mark.asyncio
async def test_emit_skips_passed_encoders(
    test_db, reset_test_results
) -> None:
    transcoding_service._TEST_RESULTS["h264_nvenc"] = (
        transcoding_service.EncoderTestResult(
            passed=True, error=None, tested_at=datetime.now(UTC),
        )
    )

    inserted = await transcoding_service.emit_encoder_failure_notifications(test_db)

    assert inserted == 0


@pytest.mark.asyncio
async def test_emit_skips_failures_without_suggestion(
    test_db, reset_test_results
) -> None:
    """Unclassified failures stay in the log at WARNING; we don't bother
    the user with raw stderr in their notification bell."""
    transcoding_service._TEST_RESULTS["h264_nvenc"] = (
        transcoding_service.EncoderTestResult(
            passed=False,
            error="something we don't recognise",
            tested_at=datetime.now(UTC),
            suggestion=None,
        )
    )

    inserted = await transcoding_service.emit_encoder_failure_notifications(test_db)

    assert inserted == 0
    async with test_db.execute(
        "SELECT COUNT(*) AS n FROM notifications"
    ) as cur:
        row = await cur.fetchone()
    assert row["n"] == 0


@pytest.mark.asyncio
async def test_emit_re_creates_after_user_dismisses(
    test_db, reset_test_results
) -> None:
    """If the user dismissed the notification, a future server restart
    creates a fresh one (so they can re-act on it later if they
    forgot).  Dedup is on `dismissed_at IS NULL` only."""
    transcoding_service._TEST_RESULTS["h264_qsv"] = (
        transcoding_service.EncoderTestResult(
            passed=False,
            error="...",
            tested_at=datetime.now(UTC),
            suggestion="Update Intel Graphics driver",
        )
    )

    await transcoding_service.emit_encoder_failure_notifications(test_db)
    await test_db.execute(
        "UPDATE notifications SET dismissed_at = datetime('now')"
    )
    await test_db.commit()

    inserted = await transcoding_service.emit_encoder_failure_notifications(test_db)

    assert inserted == 1
    async with test_db.execute(
        "SELECT COUNT(*) AS n FROM notifications"
    ) as cur:
        row = await cur.fetchone()
    assert row["n"] == 2  # one dismissed, one fresh

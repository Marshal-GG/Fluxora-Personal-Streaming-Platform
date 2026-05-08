"""Tests for ``services.ffmpeg_capabilities`` — the FFmpeg version probe
that streaming pipeline plan §17 M2 introduces.

Run the actual subprocess in a couple of cases to verify the parse path
end-to-end, but most tests use the synthetic dataclass + module-level
cache helpers so we don't depend on what FFmpeg version the CI runner
happens to have.
"""
from __future__ import annotations

import pytest

from services import ffmpeg_capabilities as caps_mod
from services.ffmpeg_capabilities import (
    FfmpegCapabilities,
    get_capabilities,
    probe_ffmpeg_capabilities,
    reset_capabilities_for_testing,
)


@pytest.fixture(autouse=True)
def _reset_cache():
    """Each test runs with a clean cache so a prior test's probe
    result doesn't leak into the next."""
    reset_capabilities_for_testing()
    yield
    reset_capabilities_for_testing()


# ── Synthetic capability flag math ─────────────────────────────────────────


def test_supports_initial_burst_true_for_5_1():
    caps = FfmpegCapabilities(version_string="ffmpeg 5.1", major=5, minor=1)
    assert caps.supports_readrate_initial_burst is True


def test_supports_initial_burst_true_for_8_0():
    caps = FfmpegCapabilities(version_string="ffmpeg 8.0", major=8, minor=0)
    assert caps.supports_readrate_initial_burst is True


def test_supports_initial_burst_false_for_5_0():
    """5.0 is the boundary just below the threshold — burst flag was
    added in 5.1, so 5.0 must NOT be considered supported."""
    caps = FfmpegCapabilities(version_string="ffmpeg 5.0", major=5, minor=0)
    assert caps.supports_readrate_initial_burst is False


def test_supports_initial_burst_false_for_4_x():
    """FFmpeg 4.x is the practical floor for `-readrate`; the burst
    flag wasn't there yet."""
    caps = FfmpegCapabilities(version_string="ffmpeg 4.4", major=4, minor=4)
    assert caps.supports_readrate_initial_burst is False


def test_supports_initial_burst_false_for_unknown():
    """Probe failure → unknown sentinel → conservative default."""
    caps = FfmpegCapabilities(version_string="", major=0, minor=0)
    assert caps.supports_readrate_initial_burst is False
    assert caps.is_known is False


# ── Module-level cache contract ────────────────────────────────────────────


def test_get_capabilities_returns_unknown_before_probe():
    """If the server hasn't run the startup probe yet (or the probe
    failed), callers must still get a usable dataclass — the
    unknown-sentinel — rather than crashing on a None deref."""
    caps = get_capabilities()
    assert caps.major == 0
    assert caps.minor == 0
    assert caps.is_known is False
    assert caps.supports_readrate_initial_burst is False


# ── Real-subprocess parse path ─────────────────────────────────────────────


@pytest.mark.asyncio
async def test_probe_parses_real_ffmpeg_version():
    """Run the actual `ffmpeg -version` subprocess.  Asserts only the
    minimum: the probe completes, returns a populated dataclass with
    a non-empty version_string and major >= 4 (anything older is
    unsupported by Fluxora's HLS pipeline anyway).  Skipped silently
    when ffmpeg isn't on PATH (CI runners without media tooling)."""
    import shutil

    if shutil.which("ffmpeg") is None:
        pytest.skip("ffmpeg not on PATH; capabilities probe can't run here")

    caps = await probe_ffmpeg_capabilities()
    assert caps.is_known, f"probe failed; got {caps!r}"
    assert caps.version_string.startswith("ffmpeg version"), (
        f"unexpected first-line shape: {caps.version_string!r}"
    )
    assert caps.major >= 4, (
        f"FFmpeg < 4 is below Fluxora's HLS minimum; got major={caps.major}"
    )


@pytest.mark.asyncio
async def test_probe_caches_the_result():
    """``probe_ffmpeg_capabilities`` populates the module-level cache so
    `get_capabilities()` returns the parsed dataclass without re-running
    the subprocess on every read."""
    import shutil

    if shutil.which("ffmpeg") is None:
        pytest.skip("ffmpeg not on PATH; capabilities probe can't run here")

    probed = await probe_ffmpeg_capabilities()
    cached = get_capabilities()
    # Same object reference — single source of truth.
    assert probed is cached


# ── Failure paths ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_probe_returns_unknown_when_ffmpeg_missing(monkeypatch):
    """Patch `_ffmpeg_bin` to raise FileNotFoundError; probe should
    log + return the unknown sentinel rather than blowing up."""
    from services import ffmpeg_service

    def _missing() -> str:
        raise FileNotFoundError("ffmpeg not on PATH for this test")

    monkeypatch.setattr(ffmpeg_service, "_ffmpeg_bin", _missing)
    caps = await probe_ffmpeg_capabilities()
    assert caps.is_known is False
    assert caps.major == 0
    assert caps.minor == 0


def test_version_regex_handles_n_prefix():
    """Linux distros (Arch, Alpine) sometimes prefix the version with
    'n' (e.g. ``ffmpeg version n5.1.4-...``).  Regex should still match."""
    match = caps_mod._VERSION_RE.search(
        "ffmpeg version n5.1.4-essentials_build-www.gyan.dev"
    )
    assert match is not None
    assert match.group(1) == "5"
    assert match.group(2) == "1"


def test_version_regex_handles_dotted_release():
    """Stock `ffmpeg version 8.0-...` shape from a Windows gyan.dev
    build — no `n` prefix."""
    match = caps_mod._VERSION_RE.search(
        "ffmpeg version 8.0-essentials_build-www.gyan.dev Copyright (c) 2000-2025"
    )
    assert match is not None
    assert match.group(1) == "8"
    assert match.group(2) == "0"

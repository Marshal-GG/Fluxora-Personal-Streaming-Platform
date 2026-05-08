"""FFmpeg capabilities probe.

Runs ``ffmpeg -version`` once at server startup, parses the major.minor,
exposes a frozen dataclass with feature flags so callers don't have to
re-run the subprocess or parse the version string themselves.

Streaming pipeline plan §17 — the M2 ``-readrate`` retries that failed
mysteriously with ``<no stderr captured>`` exposed a real gap: we ship
flags that depend on FFmpeg version (e.g. ``-readrate_initial_burst`` —
FFmpeg 5.1+) without any version check.  This module fixes that.

Only the version_string + major.minor + a small set of derived feature
flags are surfaced.  Each flag is a single bool the caller can branch on
without re-deriving "is this version >= X.Y" math at every call site.
"""
from __future__ import annotations

import asyncio
import logging
import re
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class FfmpegCapabilities:
    """What the local FFmpeg binary can do.

    Populated once at server startup by ``probe_ffmpeg_capabilities``;
    cached in module-level state for the lifetime of the process.
    """

    version_string: str
    """Full first-line output from ``ffmpeg -version`` (e.g.
    ``"ffmpeg version 8.0-essentials_build-www.gyan.dev ..."``).
    Logged + included in support bundles.  Empty on probe failure."""

    major: int
    """Major version number parsed from version_string.  0 on probe
    failure / unparseable output."""

    minor: int
    """Minor version number parsed from version_string.  0 on probe
    failure / unparseable output."""

    @property
    def supports_readrate_initial_burst(self) -> bool:
        """``-readrate_initial_burst`` was added in FFmpeg 5.1 (October
        2022).  Earlier builds either ignore it silently or error at
        arg-parse time depending on the build's argument handling.
        Streaming pipeline plan §17 M3 gates the flag on this."""
        return (self.major, self.minor) >= (5, 1)

    @property
    def is_known(self) -> bool:
        """True when the probe successfully parsed a version.  False
        when ``ffmpeg -version`` failed or the output was unparseable —
        callers should treat capability flags as best-effort fallback
        in that case (e.g. assume the most-conservative subset)."""
        return self.major > 0


# Module-level cache — populated by ``probe_ffmpeg_capabilities`` at
# server startup.  Lazy reads (via ``get_capabilities``) return the
# unknown sentinel if the probe hasn't run yet.
_capabilities: FfmpegCapabilities | None = None


_UNKNOWN = FfmpegCapabilities(version_string="", major=0, minor=0)


# Matches "ffmpeg version 8.0-..." or "ffmpeg version n4.4.1-..." or
# "ffmpeg version 5.1.4-essentials_build-www.gyan.dev ..." — captures
# major.minor as the first two integer groups in the version token.
# The leading ``n`` (Linux distros sometimes prefix with 'n') is
# tolerated.
_VERSION_RE = re.compile(r"ffmpeg\s+version\s+n?(\d+)\.(\d+)")


async def probe_ffmpeg_capabilities() -> FfmpegCapabilities:
    """Run ``ffmpeg -version``, parse, cache, log.

    Always returns a ``FfmpegCapabilities``; the unknown-sentinel is
    used on any failure so callers don't have to handle a None result.
    Logs at INFO on success + WARNING on failure so the operator's log
    always contains the version (or its absence).

    Idempotent — re-running just refreshes the cache.  Cheap (~50 ms
    on a warm OS) so re-running across reload/restart is fine.
    """
    global _capabilities

    # Lazy import — keeps the dependency one-directional at call time
    # so test monkeypatches of `services.ffmpeg_service._ffmpeg_bin`
    # propagate, AND avoids the import cycle if ffmpeg_service ever
    # needs to call back into this module.
    from services.ffmpeg_service import _ffmpeg_bin

    try:
        bin_path = _ffmpeg_bin()
    except FileNotFoundError:
        logger.warning(
            "FFmpeg binary not found on PATH or in bundled location; "
            "capabilities probe skipped",
        )
        _capabilities = _UNKNOWN
        return _UNKNOWN

    try:
        proc = await asyncio.create_subprocess_exec(
            bin_path,
            "-hide_banner",
            "-version",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        stdout_bytes, _ = await asyncio.wait_for(
            proc.communicate(), timeout=5.0
        )
    except (OSError, TimeoutError) as exc:
        logger.warning(
            "ffmpeg -version probe failed: %s",
            exc,
            exc_info=True,
        )
        _capabilities = _UNKNOWN
        return _UNKNOWN

    if proc.returncode != 0:
        logger.warning(
            "ffmpeg -version exited %d; capabilities probe inconclusive",
            proc.returncode,
        )
        _capabilities = _UNKNOWN
        return _UNKNOWN

    try:
        text = stdout_bytes.decode("utf-8", errors="replace")
    except (ValueError, UnicodeDecodeError):
        _capabilities = _UNKNOWN
        return _UNKNOWN

    first_line = text.splitlines()[0] if text else ""
    match = _VERSION_RE.search(first_line)
    if not match:
        logger.warning(
            "ffmpeg -version output unparseable: %r",
            first_line,
        )
        _capabilities = FfmpegCapabilities(
            version_string=first_line,
            major=0,
            minor=0,
        )
        return _capabilities

    major = int(match.group(1))
    minor = int(match.group(2))
    caps = FfmpegCapabilities(
        version_string=first_line,
        major=major,
        minor=minor,
    )
    _capabilities = caps
    logger.info(
        "ffmpeg_capabilities version=%r major=%d minor=%d "
        "supports_readrate_initial_burst=%s",
        first_line,
        major,
        minor,
        caps.supports_readrate_initial_burst,
    )
    return caps


def get_capabilities() -> FfmpegCapabilities:
    """Return the cached capabilities.  Returns the unknown-sentinel
    when ``probe_ffmpeg_capabilities`` hasn't run yet — callers should
    treat capability flags as best-effort fallback in that case
    (the conservative subset)."""
    return _capabilities if _capabilities is not None else _UNKNOWN


def reset_capabilities_for_testing() -> None:
    """Test-only helper.  Clears the module-level cache so each test
    can probe afresh without leaking state from a prior test."""
    global _capabilities
    _capabilities = None

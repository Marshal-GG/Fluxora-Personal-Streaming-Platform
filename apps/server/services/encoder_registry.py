"""Encoder registry — single source of truth for every FFmpeg encoder Fluxora supports.

No other module branches on encoder names.  All conditionals are replaced by
``ENCODER_REGISTRY[encoder_name]`` lookups against the metadata here.

Design notes
------------
* ``pre_input_args`` must be inserted *before* ``-i`` in the FFmpeg command.
  This is a strict FFmpeg requirement: ``-hwaccel`` applied after ``-i`` is
  silently ignored.
* ``quality_args(crf)`` maps the operator's CRF setting (0 = lossless,
  51 = worst) to the native quality flags for each vendor.  The mapping is
  linear except for VideoToolbox which uses an inverted 0–100 scale.
* ``preset_map`` translates the software preset names the UI exposes
  (ultrafast → veryslow) to the native preset names expected by each encoder.
  NVENC uses ``p1``–``p7``; QSV/VAAPI accept a subset of x264 names.
* ``segment_fmt`` determines the HLS segment container.  H.264 travels in
  MPEG-TS; HEVC must use fMP4 per Apple's HLS specification, which is also
  required for ``EXT-X-MAP`` (init segment) support.
* ``platforms`` is a set of ``sys.platform`` values where the encoder *could*
  exist.  Detection still requires ``ffmpeg -encoders`` to confirm the build
  actually includes the encoder.
"""

from __future__ import annotations

import sys
from collections.abc import Callable
from dataclasses import dataclass


@dataclass(frozen=True)
class EncoderMeta:
    """Immutable descriptor for one FFmpeg encoder."""

    name: str
    """FFmpeg encoder name, e.g. ``"h264_nvenc"``."""

    codec: str
    """Output codec family: ``"h264"`` or ``"hevc"``."""

    vendor: str
    """One of ``"software" | "nvidia" | "intel" | "amd" | "apple"``."""

    hwaccel: str | None
    """``-hwaccel`` value (``"cuda"``, ``"qsv"``, ``"vaapi"``, ``"videotoolbox"``)
    or ``None`` for software encoders."""

    hwaccel_output_fmt: str | None
    """``-hwaccel_output_format`` value, or ``None`` when not required."""

    preset_map: dict[str, str]
    """Maps software preset name → native preset name for this encoder."""

    quality_args: Callable[[int], list[str]]
    """Return the quality-control flags for a given CRF value (0–51)."""

    vf_chain: str | None
    """Optional ``-vf`` filter chain injected between input and codec flags.
    VAAPI requires ``format=nv12|vaapi,hwupload`` to upload frames to GPU."""

    segment_fmt: str
    """HLS segment container: ``"mpegts"`` or ``"fmp4"``."""

    platforms: frozenset[str]
    """``sys.platform`` values where this encoder can exist."""

    concurrent_session_cap: int | None = None
    """Soft cap on concurrent FFmpeg sessions for this encoder.

    Used by ``services/session_router.py`` (Slice C) to transparently fall
    through to the next encoder in the operator's priority chain when this
    encoder's live-session count is at the cap.

    NVIDIA NVENC consumer cards (GeForce / non-Quadro) cap at **3** concurrent
    sessions in the driver — exceeding it returns ``OpenEncodeSessionEx
    failed: out of memory`` from cuvid.  Newer drivers + RTX 40+ have lifted
    this on some cards, but 3 is the safe default; we treat it as a *soft*
    cap and let the operator force-select via the priority chain anyway.

    ``None`` means no enforced cap — software encoders are bandwidth-bound
    rather than session-bound; QSV / VAAPI / VideoToolbox have no
    documented session cap on consumer hardware.
    """

    def pre_input_args(self, device: str | None = None) -> list[str]:
        """Return FFmpeg args that must appear **before** ``-i``.

        Args:
            device: Optional hardware device path (e.g. ``/dev/dri/renderD128``
                    for VAAPI).  Ignored for non-VAAPI encoders.
        """
        if self.hwaccel is None:
            return []
        args: list[str] = ["-hwaccel", self.hwaccel]
        if self.hwaccel == "vaapi":
            dev = device or "/dev/dri/renderD128"
            args += ["-hwaccel_device", dev, "-hwaccel_output_format", "vaapi"]
        elif self.hwaccel_output_fmt:
            args += ["-hwaccel_output_format", self.hwaccel_output_fmt]
        return args

    def video_codec_args(self, preset: str, crf: int) -> list[str]:
        """Return the ``-c:v`` section (codec, preset, quality)."""
        native_preset = self.preset_map.get(preset, preset)
        args: list[str] = ["-c:v", self.name]
        # VideoToolbox ignores preset entirely — skip it.
        if self.vendor != "apple" and native_preset != "default":
            args += ["-preset", native_preset]
        args += self.quality_args(crf)
        return args

    def filter_args(self) -> list[str]:
        """Return ``-vf`` args if a filter chain is required."""
        if self.vf_chain:
            return ["-vf", self.vf_chain]
        return []

    def is_platform_supported(self) -> bool:
        """Return True if this encoder *could* exist on the current OS."""
        return sys.platform in self.platforms


# ── preset maps ───────────────────────────────────────────────────────────────

_SOFTWARE_PRESETS: dict[str, str] = {
    "ultrafast": "ultrafast",
    "superfast": "superfast",
    "veryfast": "veryfast",
    "faster": "faster",
    "fast": "fast",
    "medium": "medium",
    "slow": "slow",
    "slower": "slower",
    "veryslow": "veryslow",
}

# NVENC: p1 (fastest / lowest quality) … p7 (slowest / highest quality).
_NVENC_PRESETS: dict[str, str] = {
    "ultrafast": "p1",
    "superfast": "p2",
    "veryfast": "p3",
    "faster": "p3",
    "fast": "p4",
    "medium": "p4",
    "slow": "p5",
    "slower": "p6",
    "veryslow": "p7",
}

# QSV and VAAPI accept a subset of x264 preset names; clamp unsupported ones.
_HW_SIMPLE_PRESETS: dict[str, str] = {
    "ultrafast": "veryfast",
    "superfast": "veryfast",
    "veryfast": "veryfast",
    "faster": "faster",
    "fast": "fast",
    "medium": "medium",
    "slow": "slow",
    "slower": "slow",
    "veryslow": "slow",
}

# VideoToolbox ignores preset entirely.
_VTB_PRESETS: dict[str, str] = {k: "default" for k in _SOFTWARE_PRESETS}


# ── quality arg factories ─────────────────────────────────────────────────────

def _sw_quality(crf: int) -> list[str]:
    """Software libx264 / libx265 — direct CRF passthrough."""
    return ["-crf", str(crf)]


def _nvenc_quality(crf: int) -> list[str]:
    """NVENC VBR Constant Quality mode — same CRF direction as x264."""
    return ["-rc", "vbr", "-cq", str(crf)]


def _qsv_quality(crf: int) -> list[str]:
    """Intel QSV global_quality — same numeric direction as CRF."""
    return ["-global_quality", str(crf)]


def _vaapi_quality(crf: int) -> list[str]:
    """VAAPI QP — same direction as CRF (0=best, 51=worst)."""
    return ["-qp", str(crf)]


def _vtb_quality(crf: int) -> list[str]:
    """VideoToolbox q:v — inverted scale (100=best, 0=worst)."""
    q = max(0, min(100, 100 - int(crf * 100 / 51)))
    return ["-q:v", str(q)]


# ── registry ──────────────────────────────────────────────────────────────────

ENCODER_REGISTRY: dict[str, EncoderMeta] = {
    # ── Software ──────────────────────────────────────────────────────────────
    "libx264": EncoderMeta(
        name="libx264",
        codec="h264",
        vendor="software",
        hwaccel=None,
        hwaccel_output_fmt=None,
        preset_map=_SOFTWARE_PRESETS,
        quality_args=_sw_quality,
        vf_chain=None,
        segment_fmt="mpegts",
        platforms=frozenset({"linux", "win32", "darwin"}),
    ),
    "libx265": EncoderMeta(
        name="libx265",
        codec="hevc",
        vendor="software",
        hwaccel=None,
        hwaccel_output_fmt=None,
        preset_map=_SOFTWARE_PRESETS,
        quality_args=_sw_quality,
        vf_chain=None,
        segment_fmt="fmp4",
        platforms=frozenset({"linux", "win32", "darwin"}),
    ),
    # ── NVIDIA NVENC ──────────────────────────────────────────────────────────
    "h264_nvenc": EncoderMeta(
        name="h264_nvenc",
        codec="h264",
        vendor="nvidia",
        hwaccel="cuda",
        hwaccel_output_fmt="cuda",
        preset_map=_NVENC_PRESETS,
        quality_args=_nvenc_quality,
        vf_chain=None,
        segment_fmt="mpegts",
        platforms=frozenset({"linux", "win32"}),
        concurrent_session_cap=3,
    ),
    "hevc_nvenc": EncoderMeta(
        name="hevc_nvenc",
        codec="hevc",
        vendor="nvidia",
        hwaccel="cuda",
        hwaccel_output_fmt="cuda",
        preset_map=_NVENC_PRESETS,
        quality_args=_nvenc_quality,
        vf_chain=None,
        segment_fmt="fmp4",
        platforms=frozenset({"linux", "win32"}),
        concurrent_session_cap=3,
    ),
    # ── Intel Quick Sync ──────────────────────────────────────────────────────
    "h264_qsv": EncoderMeta(
        name="h264_qsv",
        codec="h264",
        vendor="intel",
        hwaccel="qsv",
        hwaccel_output_fmt="qsv",
        preset_map=_HW_SIMPLE_PRESETS,
        quality_args=_qsv_quality,
        vf_chain=None,
        segment_fmt="mpegts",
        platforms=frozenset({"linux", "win32"}),
    ),
    "hevc_qsv": EncoderMeta(
        name="hevc_qsv",
        codec="hevc",
        vendor="intel",
        hwaccel="qsv",
        hwaccel_output_fmt="qsv",
        preset_map=_HW_SIMPLE_PRESETS,
        quality_args=_qsv_quality,
        vf_chain=None,
        segment_fmt="fmp4",
        platforms=frozenset({"linux", "win32"}),
    ),
    # ── AMD / Linux VA-API ────────────────────────────────────────────────────
    # VAAPI requires hwaccel args + a filter chain to upload frames to the GPU.
    # The device path is injected at runtime via pre_input_args(device=...).
    "h264_vaapi": EncoderMeta(
        name="h264_vaapi",
        codec="h264",
        vendor="amd",
        hwaccel="vaapi",
        hwaccel_output_fmt="vaapi",
        preset_map=_HW_SIMPLE_PRESETS,
        quality_args=_vaapi_quality,
        vf_chain="format=nv12|vaapi,hwupload",
        segment_fmt="mpegts",
        platforms=frozenset({"linux"}),
    ),
    "hevc_vaapi": EncoderMeta(
        name="hevc_vaapi",
        codec="hevc",
        vendor="amd",
        hwaccel="vaapi",
        hwaccel_output_fmt="vaapi",
        preset_map=_HW_SIMPLE_PRESETS,
        quality_args=_vaapi_quality,
        vf_chain="format=nv12|vaapi,hwupload",
        segment_fmt="fmp4",
        platforms=frozenset({"linux"}),
    ),
    # ── Apple VideoToolbox (macOS) ────────────────────────────────────────────
    "h264_videotoolbox": EncoderMeta(
        name="h264_videotoolbox",
        codec="h264",
        vendor="apple",
        hwaccel="videotoolbox",
        hwaccel_output_fmt=None,
        preset_map=_VTB_PRESETS,
        quality_args=_vtb_quality,
        vf_chain=None,
        segment_fmt="mpegts",
        platforms=frozenset({"darwin"}),
    ),
    "hevc_videotoolbox": EncoderMeta(
        name="hevc_videotoolbox",
        codec="hevc",
        vendor="apple",
        hwaccel="videotoolbox",
        hwaccel_output_fmt=None,
        preset_map=_VTB_PRESETS,
        quality_args=_vtb_quality,
        vf_chain=None,
        segment_fmt="fmp4",
        platforms=frozenset({"darwin"}),
    ),
}

#: Encoders that are always listed in the auto-detection pass, regardless of
#: platform — the ffmpeg -encoders check gates availability on the actual
#: FFmpeg build, platform filtering is a secondary guard.
ALL_KNOWN_ENCODERS: list[str] = list(ENCODER_REGISTRY.keys())

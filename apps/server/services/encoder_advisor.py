"""Encoder advisor — recommends a better encoder for the active stream profile.

Pure function over the encoder registry + self-test results + currently active
encoder.  No I/O, no state, no DB.  The result drives the desktop's
recommendation banner above the encoder dropdown.

Rule priority (first match wins):

1. **Active encoder failed self-test** — recommend the best tested-passing
   encoder.  Software fallback at minimum.
2. **Active is software, GPU is available and tested** — recommend the GPU
   encoder (typically 10-30x faster).
3. **Active is HEVC** — neutral compatibility note (HEVC playback isn't
   universal; older Roku / Chromecast 1st gen can't play fmp4 segments).
4. **Otherwise** — no recommendation.

The advisor is *suggestive*, not enforcing.  The operator can always pick
whatever encoder they like; the banner exists so they don't pick blindly.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING

from services.encoder_registry import ENCODER_REGISTRY

if TYPE_CHECKING:
    from services.transcoding_service import EncoderTestResult


# Vendor preference order for the "GPU upgrade" recommendation.  NVIDIA NVENC
# is fastest in most consumer setups; QSV is the broadest desktop chip
# coverage; VAAPI is Linux-only AMD; VideoToolbox is macOS-only Apple.  When
# multiple GPU encoders are tested-passing, prefer in this order.
_VENDOR_PRIORITY: dict[str, int] = {
    "nvidia": 0,
    "intel": 1,
    "amd": 2,
    "apple": 3,
    "software": 99,
}


@dataclass(frozen=True)
class Recommendation:
    """One advisor recommendation.

    ``recommended_encoder`` is None when the active encoder is fine.
    ``reason_code`` lets the desktop key off a stable enum without parsing
    free-form text; ``reason_text`` is what the banner actually shows.
    ``severity`` controls the banner colour: 'info' for nudges, 'warning'
    for "you're on a broken encoder, fix this".
    """

    recommended_encoder: str | None
    reason_code: str  # 'cpu_fallback' | 'failed_active' | 'hevc_compat' | 'none'
    reason_text: str
    severity: str  # 'info' | 'warning' | 'none'


_NO_RECOMMENDATION = Recommendation(
    recommended_encoder=None,
    reason_code="none",
    reason_text="",
    severity="none",
)


def _best_passing_encoder(
    available: list[str],
    test_results: dict[str, EncoderTestResult],
    *,
    codec: str | None = None,
    exclude_software: bool = False,
) -> str | None:
    """Return the highest-priority encoder that exists in the registry,
    is in ``available``, and (if previously tested) passed.

    Untested encoders are *not* suggested — recommending an encoder we
    haven't verified would lead the operator into the same "transcode then
    diagnose" loop the advisor exists to prevent.

    ``codec`` filters by output codec ('h264' / 'hevc') when set.
    ``exclude_software`` hides libx264 / libx265 — used by the GPU-upgrade
    rule which only fires when a hardware option is actually available.
    """
    candidates: list[tuple[int, str]] = []
    for enc in available:
        meta = ENCODER_REGISTRY.get(enc)
        if meta is None:
            continue
        if codec is not None and meta.codec != codec:
            continue
        if exclude_software and meta.vendor == "software":
            continue
        result = test_results.get(enc)
        # Untested = exclude.  Failed = exclude.  Only tested-passing encoders
        # are worth recommending.
        if result is None or not result.passed:
            continue
        candidates.append((_VENDOR_PRIORITY.get(meta.vendor, 99), enc))
    if not candidates:
        return None
    candidates.sort()
    return candidates[0][1]


def recommend(
    *,
    active: str,
    available: list[str],
    test_results: dict[str, EncoderTestResult],
) -> Recommendation:
    """Return a recommendation for the operator's current encoder choice.

    Args:
        active: The encoder currently configured in ``user_settings``.
        available: Encoders detected by ``ffmpeg -encoders`` on this build.
        test_results: Results from the most recent self-test pass; key is
            encoder name, value is :class:`EncoderTestResult`.  Keys absent
            from this dict are treated as "not yet tested".

    Returns:
        :class:`Recommendation`.  ``reason_code == 'none'`` and
        ``recommended_encoder is None`` mean "the operator's choice is
        fine; render no banner."
    """
    active_meta = ENCODER_REGISTRY.get(active)
    active_result = test_results.get(active)

    # Rule 1 — active encoder failed self-test.  Recommend any tested-passing
    # alternative.  This is the highest-severity case because the operator's
    # next stream attempt will fail.
    if active_result is not None and not active_result.passed:
        # Prefer same-codec replacement so HLS playback compatibility doesn't
        # change unexpectedly (HEVC → H.264 would force a different segment
        # format).
        codec_match = _best_passing_encoder(
            available, test_results, codec=active_meta.codec if active_meta else None
        )
        fallback = codec_match or _best_passing_encoder(available, test_results)
        if fallback is not None:
            err_snippet = active_result.error or "self-test failed"
            return Recommendation(
                recommended_encoder=fallback,
                reason_code="failed_active",
                reason_text=(
                    f"`{active}` failed its last self-test ({err_snippet}). "
                    f"Switch to `{fallback}` to keep streaming working."
                ),
                severity="warning",
            )
        # No working alternative — surface the failure but don't promise a fix.
        return Recommendation(
            recommended_encoder=None,
            reason_code="failed_active",
            reason_text=(
                f"`{active}` failed its last self-test "
                f"({active_result.error or 'self-test failed'}) and no other "
                "encoder passed.  Streaming will fall back to whatever "
                "FFmpeg can negotiate; install drivers or check the logs."
            ),
            severity="warning",
        )

    # Rule 2 — active is software, a tested-passing GPU encoder exists.
    if active_meta is not None and active_meta.vendor == "software":
        gpu_choice = _best_passing_encoder(
            available,
            test_results,
            codec=active_meta.codec,
            exclude_software=True,
        )
        if gpu_choice is not None:
            gpu_meta = ENCODER_REGISTRY[gpu_choice]
            vendor_label = {
                "nvidia": "NVIDIA NVENC",
                "intel": "Intel Quick Sync",
                "amd": "AMD VAAPI",
                "apple": "Apple VideoToolbox",
            }.get(gpu_meta.vendor, gpu_meta.vendor)
            return Recommendation(
                recommended_encoder=gpu_choice,
                reason_code="cpu_fallback",
                reason_text=(
                    f"You're transcoding on CPU (`{active}`).  "
                    f"{vendor_label} is detected and tested — switch to "
                    f"`{gpu_choice}` for ~10-30× faster transcoding."
                ),
                severity="info",
            )

    # Rule 3 — active is HEVC.  HEVC needs fmp4 segments; older HLS clients
    # (some Rokus, Chromecast 1st gen, certain smart TVs) can't decode them.
    # We don't recommend a switch — just inform — because the operator's
    # devices are unknown to us.
    if active_meta is not None and active_meta.codec == "hevc":
        return Recommendation(
            recommended_encoder=None,
            reason_code="hevc_compat",
            reason_text=(
                f"`{active}` outputs HEVC, which uses fmp4 HLS segments.  "
                "Most modern devices can play these, but older Roku / "
                "Chromecast 1st gen / pre-2017 smart TVs may stutter — "
                "switch to a `_h264` encoder if compatibility is a "
                "priority over file size."
            ),
            severity="info",
        )

    return _NO_RECOMMENDATION

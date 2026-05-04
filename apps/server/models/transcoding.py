from typing import Literal

from pydantic import BaseModel, Field

EncoderName = Literal[
    "libx264", "libx265",
    "h264_nvenc", "hevc_nvenc",
    "h264_qsv", "hevc_qsv",
    "h264_vaapi", "hevc_vaapi",
    "h264_videotoolbox", "hevc_videotoolbox",
]


class EncoderLoad(BaseModel):
    encoder: str
    active_sessions: int
    gpu_utilization_percent: float | None = None
    vram_used_mb: int | None = None
    cpu_utilization_percent: float | None = None
    # Underlying GPU engine name ("cuda", "qsv", "vaapi", "videotoolbox", or None
    # for software encoders).  Displayed in the desktop GPU stats tile header.
    gpu_engine: str | None = None
    # Result of the startup / on-change self-test (None = not yet tested).
    encoder_test_passed: bool | None = None
    # First non-empty stderr line from the failed self-test, if any.  Drives
    # the desktop's failed-encoder modal — without it the operator can't tell
    # a missing-driver from a missing-binary case.
    encoder_test_error: str | None = None
    # ISO-8601 UTC timestamp of the last self-test (None = not yet tested).
    encoder_tested_at: str | None = None


class ActiveTranscodeSession(BaseModel):
    id: str
    client_id: str | None
    client_name: str | None = None
    media_title: str | None = None
    input_codec: str | None = None
    output_codec: str | None = None
    fps: float | None = None
    speed_x: float | None = None
    progress: float | None = Field(default=None, ge=0, le=1)


class TranscodingStatusResponse(BaseModel):
    active_encoder: str
    available_encoders: list[str]
    encoder_loads: list[EncoderLoad]
    active_sessions: list[ActiveTranscodeSession]

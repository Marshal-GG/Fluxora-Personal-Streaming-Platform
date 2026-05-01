from typing import Literal

from pydantic import BaseModel, Field

EncoderName = Literal["libx264", "h264_nvenc", "h264_qsv", "h264_vaapi"]


class EncoderLoad(BaseModel):
    encoder: str
    active_sessions: int
    gpu_utilization_percent: float | None = None
    vram_used_mb: int | None = None
    cpu_utilization_percent: float | None = None


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

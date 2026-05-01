from typing import Literal

from pydantic import BaseModel, Field, field_validator

# FFmpeg encoders we support (software + common hardware accelerators).
TranscodingEncoder = Literal["libx264", "h264_nvenc", "h264_qsv", "h264_vaapi"]

# FFmpeg x264 preset names (also accepted by NVENC/QSV/VAAPI variants).
TranscodingPreset = Literal[
    "ultrafast",
    "superfast",
    "veryfast",
    "faster",
    "fast",
    "medium",
    "slow",
    "slower",
    "veryslow",
]


class ServerInfoResponse(BaseModel):
    server_name: str
    version: str
    tier: str
    # Public URL the server can be reached at off-LAN, when configured.
    # Null when remote routing isn't set up. Clients persist this after
    # pairing and use it from off-LAN networks.
    remote_url: str | None = None


class SystemStatsResponse(BaseModel):
    uptime_seconds: int
    lan_ip: str | None
    public_address: str | None
    internet_connected: bool
    cpu_percent: float
    ram_percent: float
    ram_used_bytes: int
    ram_total_bytes: int
    network_in_mbps: float
    network_out_mbps: float
    active_streams: int


class UserSettingsResponse(BaseModel):
    server_name: str
    subscription_tier: str
    max_concurrent_streams: int
    transcoding_enabled: bool
    license_key: str | None = None
    license_status: str = "none"  # none | valid | expired | invalid | no_secret
    license_tier: str | None = None  # tier encoded in the key (if valid/no_secret)
    # Transcoding
    transcoding_encoder: str
    transcoding_preset: str
    transcoding_crf: int


class UpdateSettingsBody(BaseModel):
    server_name: str | None = None
    tier: str | None = None
    license_key: str | None = None
    transcoding_enabled: bool | None = None
    transcoding_encoder: TranscodingEncoder | None = None
    transcoding_preset: TranscodingPreset | None = None
    # FFmpeg CRF range — 0 (lossless) to 51 (worst quality).
    transcoding_crf: int | None = Field(default=None, ge=0, le=51)

    @field_validator("server_name")
    @classmethod
    def server_name_not_blank(cls, v: str | None) -> str | None:
        if v is not None and not v.strip():
            raise ValueError("server_name must not be blank")
        return v.strip() if v is not None else v

    @field_validator("license_key")
    @classmethod
    def license_key_format(cls, v: str | None) -> str | None:
        """Reject keys that are obviously malformed (wrong prefix / segment count).

        Accepts both legacy 4-part keys (FLUXORA-TIER-EXPIRY-SIG) and modern
        5-part keys with a nonce (FLUXORA-TIER-EXPIRY-NONCE-SIG).
        """
        if v is None:
            return v
        parts = v.strip().upper().split("-")
        if len(parts) != 5 or parts[0] != "FLUXORA":
            raise ValueError(
                "license_key must be in FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG> format"
            )
        return v.strip()

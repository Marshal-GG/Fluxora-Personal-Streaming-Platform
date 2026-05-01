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
    # General
    language: str = "en"
    auto_start_on_boot: bool = False
    auto_restart_on_crash: bool = True
    minimize_to_system_tray: bool = True
    theme_accent: str | None = None
    default_library_view: str = "grid"
    scan_libraries_on_startup: bool = True
    generate_thumbnails: bool = True
    # Network
    preferred_mode: str = "auto"
    enable_mdns: bool = True
    enable_webrtc: bool = True
    relay_server_url: str | None = None
    # Streaming
    default_quality: str = "auto"
    ai_segment_duration_seconds: int = 4
    # Security
    enable_pairing_required: bool = True
    session_timeout_minutes: int = 60
    # Advanced
    enable_log_export: bool = True
    custom_server_url: str | None = None


class UpdateSettingsBody(BaseModel):
    server_name: str | None = None
    tier: str | None = None
    license_key: str | None = None
    transcoding_enabled: bool | None = None
    transcoding_encoder: TranscodingEncoder | None = None
    transcoding_preset: TranscodingPreset | None = None
    # FFmpeg CRF range — 0 (lossless) to 51 (worst quality).
    transcoding_crf: int | None = Field(default=None, ge=0, le=51)
    # General
    language: str | None = None
    auto_start_on_boot: bool | None = None
    auto_restart_on_crash: bool | None = None
    minimize_to_system_tray: bool | None = None
    theme_accent: str | None = None
    default_library_view: Literal["grid", "list"] | None = None
    scan_libraries_on_startup: bool | None = None
    generate_thumbnails: bool | None = None
    # Network
    preferred_mode: Literal["auto", "lan", "webrtc"] | None = None
    enable_mdns: bool | None = None
    enable_webrtc: bool | None = None
    relay_server_url: str | None = None
    # Streaming
    default_quality: Literal["auto", "4k", "1080p", "720p", "480p"] | None = None
    ai_segment_duration_seconds: int | None = Field(default=None, ge=1, le=30)
    # Security
    enable_pairing_required: bool | None = None
    session_timeout_minutes: int | None = Field(default=None, ge=1, le=1440)
    # Advanced
    enable_log_export: bool | None = None
    custom_server_url: str | None = None

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

from typing import Literal

from pydantic import BaseModel, Field, field_validator

# FFmpeg encoders Fluxora supports (software + GPU hardware accelerators).
# Keep in sync with services/encoder_registry.py::ENCODER_REGISTRY.
TranscodingEncoder = Literal[
    # Software
    "libx264",
    "libx265",
    # NVIDIA NVENC
    "h264_nvenc",
    "hevc_nvenc",
    # Intel Quick Sync
    "h264_qsv",
    "hevc_qsv",
    # AMD / Linux VA-API
    "h264_vaapi",
    "hevc_vaapi",
    # Apple VideoToolbox (macOS only)
    "h264_videotoolbox",
    "hevc_videotoolbox",
]

# FFmpeg x264 preset names — the UI always uses these names; the encoder
# registry translates them to native HW preset names at runtime.
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
    # Optional VAAPI device path (Linux only). NULL = auto (/dev/dri/renderD128).
    transcoding_hwaccel_device: str | None = None
    # Operator's encoder priority chain — list of registry encoder names
    # tried in order on every transcode session.  When the first entry is
    # at its concurrent_session_cap (NVENC = 3 on consumer cards) the
    # session_router falls through to the next.  Empty list / None means
    # "use the default chain": [transcoding_encoder, "libx264"].
    transcoding_chain: list[str] | None = None
    # Streaming pipeline mode.  `client-decode` (the Recommended default,
    # plan 19 §M7) stream-copies AV1/VP9/HEVC/H.264 via fmp4 so modern
    # devices hardware-decode them.  `auto` (plan 20) is opt-in: starts
    # in stream-copy and transparently falls back to transcode when the
    # client reports a decode error within 6 s.  `server-transcode` is
    # the legacy plan-18 behaviour: server live-transcodes AV1/VP9 to
    # H.264 before streaming.
    streaming_mode: Literal["auto", "client-decode", "server-transcode"] = (
        "client-decode"
    )
    # Plan 19 §M2 — transcode storage location chooser.  `dedicated`
    # nests sidecars under `transcode_cache_root`; `inline` keeps them
    # next to source under `.fluxora-transcodes/`.  The cache-root
    # value is the operator-set absolute path or NULL when the worker
    # should fall back to a server-data-directory sibling.
    transcode_storage_mode: Literal["dedicated", "inline"] = "dedicated"
    transcode_cache_root: str | None = None
    # General
    language: str = "en"
    auto_start_on_boot: bool = False
    auto_restart_on_crash: bool = True
    minimize_to_system_tray: bool = True
    theme_accent: str | None = None
    default_library_view: str = "grid"
    scan_libraries_on_startup: bool = True
    generate_thumbnails: bool = True
    # Plan 27 — operator-configurable thumbnail width (pixels).
    # Worker reads per claim cycle.  160-640 enforced by router.
    thumbnail_width: int = 320
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
    # VAAPI device path — only meaningful on Linux with h264_vaapi / hevc_vaapi.
    transcoding_hwaccel_device: str | None = None
    # Operator's encoder priority chain (Slice C).  Empty list / None
    # means "use the default chain".  Each entry must be a known encoder
    # in the registry (validated at the service layer, not here, because
    # the registry isn't a Pydantic-friendly Literal).
    transcoding_chain: list[str] | None = None
    # Plan 19 §M7 + plan 20 — streaming pipeline mode.
    streaming_mode: Literal["auto", "client-decode", "server-transcode"] | None = None
    # Plan 19 §M2 — transcode storage location chooser.  Service-layer
    # validation enforces `transcode_cache_root` is absolute, writable,
    # and outside every library root before persisting.
    transcode_storage_mode: Literal["dedicated", "inline"] | None = None
    transcode_cache_root: str | None = None
    # General
    language: str | None = None
    auto_start_on_boot: bool | None = None
    auto_restart_on_crash: bool | None = None
    minimize_to_system_tray: bool | None = None
    theme_accent: str | None = None
    default_library_view: Literal["grid", "list"] | None = None
    scan_libraries_on_startup: bool | None = None
    generate_thumbnails: bool | None = None
    # Plan 27 — 160 ≤ thumbnail_width ≤ 640 (Field-validated below the
    # body's main field block; see _validate_thumbnail_width).
    thumbnail_width: int | None = Field(default=None, ge=160, le=640)
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

        Format: FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG>
        """
        if v is None:
            return v
        parts = v.strip().upper().split("-")
        if len(parts) != 5 or parts[0] != "FLUXORA":
            raise ValueError(
                "license_key must be in FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<SIG> format"
            )
        return v.strip()

import logging
import os
import platform
import stat
import subprocess
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)


def _default_db_path() -> str:
    return str(_data_dir() / "fluxora.db")


def _default_hls_tmp() -> str:
    return str(_data_dir() / "hls")


def _data_dir() -> Path:
    system = platform.system()
    if system == "Windows":
        base = Path(os.environ["APPDATA"]) / "Fluxora"
    elif system == "Darwin":
        base = Path.home() / "Library" / "Application Support" / "Fluxora"
    else:
        base = Path.home() / ".fluxora"
    return base


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(_data_dir() / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Server
    fluxora_host: str = "0.0.0.0"
    fluxora_port: int = 8000
    fluxora_server_name: str = "Fluxora Server"
    fluxora_log_level: str = "INFO"
    fluxora_env: str = "prod"  # "dev" enables plain log output

    # Database
    fluxora_db_path: str = _default_db_path()

    # HLS
    fluxora_hls_tmp: str = _default_hls_tmp()

    # Streaming
    fluxora_max_streams: int = 3

    # Optional integrations
    fluxora_tmdb_key: str = ""
    fluxora_turn_url: str = ""
    fluxora_turn_user: str = ""
    fluxora_turn_pass: str = ""

    # Security — generate once with: secrets.token_hex(32)
    token_hmac_key: str = ""

    # License — generate once with: secrets.token_hex(32)
    # Used to sign/verify FLUXORA-<TIER>-<EXPIRY>-<SIG> keys.
    fluxora_license_secret: str = ""

    # Polar.sh webhook secret — copy from Polar dashboard → Webhooks.
    # Without this, the /api/v1/webhook/polar endpoint returns 501.
    polar_webhook_secret: str = ""

    @property
    def db_path(self) -> Path:
        return Path(self.fluxora_db_path)

    @property
    def hls_tmp_path(self) -> Path:
        return Path(self.fluxora_hls_tmp)

    @property
    def is_dev(self) -> bool:
        return self.fluxora_env.lower() == "dev"


def get_data_dir() -> Path:
    """Return the platform-correct data directory with owner-only permissions."""
    base = _data_dir()
    if not base.exists():
        base.mkdir(parents=True)
        if platform.system() != "Windows":
            os.chmod(base, stat.S_IRWXU)  # 700 — owner only
        else:
            _restrict_windows_path(str(base))
    return base


def secure_db_file(db_path: Path) -> None:
    """Restrict the DB and its WAL/SHM sidecars to owner read/write only."""
    if platform.system() != "Windows":
        for suffix in ["", "-wal", "-shm"]:
            p = Path(str(db_path) + suffix)
            if p.exists():
                os.chmod(p, stat.S_IRUSR | stat.S_IWUSR)  # 600


def _restrict_windows_path(path: str) -> None:
    username = os.environ.get("USERNAME", "")
    if not username:
        return
    grant = f"{username}:(OI)(CI)F"
    subprocess.run(
        ["icacls", path, "/inheritance:r", "/grant:r", grant],
        capture_output=True,
        check=False,
    )


settings = Settings()

from pydantic import BaseModel, field_validator


class ServerInfoResponse(BaseModel):
    server_name: str
    version: str
    tier: str


class UserSettingsResponse(BaseModel):
    server_name: str
    subscription_tier: str
    max_concurrent_streams: int
    transcoding_enabled: bool
    license_key: str | None = None


class UpdateSettingsBody(BaseModel):
    server_name: str | None = None
    tier: str | None = None
    license_key: str | None = None
    transcoding_enabled: bool | None = None

    @field_validator("server_name")
    @classmethod
    def server_name_not_blank(cls, v: str | None) -> str | None:
        if v is not None and not v.strip():
            raise ValueError("server_name must not be blank")
        return v.strip() if v is not None else v

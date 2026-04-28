from typing import Literal

from pydantic import BaseModel


class PairRequestBody(BaseModel):
    client_id: str
    device_name: str
    platform: Literal["android", "ios", "windows", "macos", "linux"]
    app_version: str = "0.1.0"


class PairResponse(BaseModel):
    client_id: str
    status: str


class AuthStatusResponse(BaseModel):
    status: Literal["pending_approval", "approved", "rejected"]
    auth_token: str | None = None


class ClientListItem(BaseModel):
    id: str
    name: str
    platform: str
    status: str
    last_seen: str
    is_trusted: bool


class ClientListResponse(BaseModel):
    clients: list[ClientListItem]
    total: int

from pydantic import BaseModel


class ServerInfoResponse(BaseModel):
    server_name: str
    version: str
    tier: str

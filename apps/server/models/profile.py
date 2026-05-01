from pydantic import BaseModel, Field


class ProfileResponse(BaseModel):
    """Operator profile metadata for the desktop Profile screen.

    `avatar_letter` is computed server-side from `display_name` (first non-
    whitespace character, uppercased) or `email` (first character of the
    local part), defaulting to `'F'` when neither is set.
    `last_login_at` is reserved for v2; always null in v1.
    """

    display_name: str | None = None
    email: str | None = None
    avatar_letter: str
    avatar_path: str | None = None
    created_at: str | None = None
    last_login_at: str | None = None


class ProfileUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=120)
    email: str | None = Field(default=None, max_length=254)

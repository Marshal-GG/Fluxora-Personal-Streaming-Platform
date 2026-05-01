"""Operator profile read/write.

Profile fields live on the `user_settings` singleton (id=1). All five
fields (display_name, email, avatar_path, profile_created_at,
last_login_at) are nullable; the GET response computes `avatar_letter`
from whichever identity field is populated.

The plan's POST /password and POST /avatar endpoints are intentionally
out of scope for v1:
- Password: Fluxora's single-owner localhost model has no operator
  password concept (clients pair via PIN/approval, server is reached
  via 127.0.0.1 only on the admin paths).
- Avatar upload: deferred until the desktop UI needs it.
"""

from __future__ import annotations

import logging
from typing import Any

import aiosqlite

logger = logging.getLogger(__name__)


def _avatar_letter(display_name: str | None, email: str | None) -> str:
    if display_name:
        for ch in display_name:
            if not ch.isspace():
                return ch.upper()
    if email:
        local = email.split("@", 1)[0]
        if local:
            return local[0].upper()
    return "F"


async def get_profile(db: aiosqlite.Connection) -> dict[str, Any]:
    async with db.execute(
        """
        SELECT display_name, email, avatar_path,
               profile_created_at, last_login_at
          FROM user_settings
         WHERE id = 1
        """
    ) as cur:
        row = await cur.fetchone()
    if row is None:
        return {
            "display_name": None,
            "email": None,
            "avatar_letter": "F",
            "avatar_path": None,
            "created_at": None,
            "last_login_at": None,
        }
    return {
        "display_name": row["display_name"],
        "email": row["email"],
        "avatar_letter": _avatar_letter(row["display_name"], row["email"]),
        "avatar_path": row["avatar_path"],
        "created_at": row["profile_created_at"],
        "last_login_at": row["last_login_at"],
    }


async def update_profile(
    db: aiosqlite.Connection,
    *,
    display_name: str | None = None,
    email: str | None = None,
) -> dict[str, Any]:
    """Update only the fields explicitly passed.

    Pass an empty string to clear a field (the user removes their email
    from the desktop UI, for example). Pass `None` to leave it unchanged.
    """
    fields: list[str] = []
    values: list[Any] = []
    if display_name is not None:
        fields.append("display_name = ?")
        values.append(display_name or None)
    if email is not None:
        fields.append("email = ?")
        values.append(email or None)

    if fields:
        values.append(1)
        await db.execute(
            f"UPDATE user_settings SET {', '.join(fields)} WHERE id = ?",
            tuple(values),
        )
        await db.commit()
        logger.info("Profile updated: fields=%s", [f.split(" ")[0] for f in fields])

    return await get_profile(db)

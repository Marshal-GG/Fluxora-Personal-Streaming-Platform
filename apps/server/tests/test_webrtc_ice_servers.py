"""Regression tests for ``webrtc_service._ice_servers``.

The function used to read TURN credentials via ``getattr(settings,
"webrtc_turn_url", None)`` and friends — names that never bound to any
declared field on ``Settings``, where the canonical names are
``fluxora_turn_url`` / ``fluxora_turn_user`` / ``fluxora_turn_pass``.
The result was that TURN was silently inert no matter what env vars
the operator exported, and Internet streaming over restrictive NATs
would fail to negotiate a media path.

These tests pin the post-fix behaviour: when all three TURN settings
are non-empty the function must include a TURN entry; when any one is
empty it must fall back to STUN-only.
"""

from services.webrtc_service import _ice_servers


def test_ice_servers_stun_only_when_no_turn_configured(monkeypatch):
    """Default config (empty TURN strings) returns a single STUN entry."""
    monkeypatch.setattr("services.webrtc_service.settings.fluxora_turn_url", "")
    monkeypatch.setattr("services.webrtc_service.settings.fluxora_turn_user", "")
    monkeypatch.setattr("services.webrtc_service.settings.fluxora_turn_pass", "")

    servers = _ice_servers()

    assert len(servers) == 1
    assert "stun:" in servers[0].urls[0]


def test_ice_servers_includes_turn_when_all_three_set(monkeypatch):
    """All three of url/user/pass set => TURN entry appears alongside STUN."""
    monkeypatch.setattr(
        "services.webrtc_service.settings.fluxora_turn_url",
        "turn:turn.example.com:3478",
    )
    monkeypatch.setattr(
        "services.webrtc_service.settings.fluxora_turn_user", "fluxora-user"
    )
    monkeypatch.setattr(
        "services.webrtc_service.settings.fluxora_turn_pass", "secret-pass"
    )

    servers = _ice_servers()

    assert len(servers) == 2
    turn = servers[1]
    assert turn.urls == ["turn:turn.example.com:3478"]
    assert turn.username == "fluxora-user"
    assert turn.credential == "secret-pass"


def test_ice_servers_drops_turn_when_any_field_empty(monkeypatch):
    """Missing url, user, OR pass => STUN-only.  Belt-and-braces."""
    cases = [
        ("", "user", "pass"),
        ("turn:t.example.com", "", "pass"),
        ("turn:t.example.com", "user", ""),
    ]
    for url, user, password in cases:
        monkeypatch.setattr(
            "services.webrtc_service.settings.fluxora_turn_url", url
        )
        monkeypatch.setattr(
            "services.webrtc_service.settings.fluxora_turn_user", user
        )
        monkeypatch.setattr(
            "services.webrtc_service.settings.fluxora_turn_pass", password
        )
        servers = _ice_servers()
        assert len(servers) == 1, (
            f"Expected STUN-only when one of TURN fields is empty, got "
            f"{len(servers)} entries for ({url!r}, {user!r}, {password!r})"
        )
